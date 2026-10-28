import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/catalogue_repository.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/domain/models/resource_state.dart';
import 'package:holyquran/ui/features/resources/view_models/pack_row_state.dart';
import 'package:holyquran/utils/result.dart';

/// The packs of one category of the resource manager and the space its
/// installed packs use (`OF-01`, `OF-03`).
final class PackSection {
  const PackSection({
    required this.kind,
    required this.rows,
    required this.usedBytes,
  });

  final PackKind kind;
  final List<PackRowState> rows;
  final int usedBytes;
}

/// The resource manager (`OF-01` to `OF-03`, `OF-06`, `TF-06`): the packs
/// the catalogue offers, joined with the installer and the integrity of
/// each, by category, with the space they use and the space left.
final class ResourcesViewModel extends ChangeNotifier {
  /// [freeBytes] answers the free space of the device, null when unknown.
  ResourcesViewModel({
    required this._catalogue,
    required this._installs,
    required this._integrity,
    required this._freeBytes,
  }) {
    _catalogue.addListener(notifyListeners);
    _integrity.addListener(notifyListeners);
    _installs.addListener(_onInstalls);
    unawaited(_refresh());
    unawaited(_readFreeSpace());
  }

  /// Recitation packs have their own section (P1-33).
  static const _kinds = [PackKind.tafsir, PackKind.text];

  final CatalogueRepository _catalogue;
  final PackInstallRepository _installs;
  final PackIntegrityRepository _integrity;
  final Future<int?> Function() _freeBytes;

  bool _unreachable = false;
  int? _free;
  int _freeReads = 0;
  Object? _installedSeen;
  bool _disposed = false;

  /// The failure each pack was downloaded again over, by id. The integrity
  /// repository keeps it until the pack is read again, so the new copy is
  /// not blamed for it; a later failure is a new object and shows.
  final _redownloadedOver = <String, PackIntegrity>{};

  /// True when no catalogue could be fetched and none is kept.
  bool get unreachable => _unreachable && _catalogue.catalogue == null;

  /// The categories whose packs the catalogue offers, in the order of
  /// `OF-01`.
  List<PackSection> get sections {
    final catalogue = _catalogue.catalogue;
    if (catalogue == null) return const [];
    final resources = resourcesOf(
      catalogue,
      installed: _installs.installed,
      jobs: _installs.jobs,
    );
    return [
      for (final kind in _kinds)
        if (_rowsOf(kind, resources) case final rows when rows.isNotEmpty)
          PackSection(kind: kind, rows: rows, usedBytes: _usedBytes(kind)),
    ];
  }

  /// What the installed packs use plus the free space: the whole every
  /// category's share is measured against.
  int get storageBytes =>
      _installs.installed.fold(0, (sum, pack) => sum + _bytesOf(pack)) +
      (_free ?? 0);

  void download(String packId) {
    if (_catalogue.catalogue?.pack(packId) case final entry?) {
      unawaited(_installs.install(entry.installRequest(wifiOnly: false)));
    }
  }

  void delete(String packId) => unawaited(_installs.delete(packId));

  /// Installs the catalogue's version afresh. An installed copy is deleted
  /// first only when it failed its run-time check: a copy that works stays
  /// when it was an install job that failed.
  Future<void> redownload(String packId) async {
    final failure = _integrity.stateOf(packId);
    if (_installedFailed(packId)) {
      if (await _installs.delete(packId) case Failure()) return;
      _redownloadedOver[packId] = failure;
    }
    download(packId);
  }

  List<PackRowState> _rowsOf(PackKind kind, List<Resource> resources) => [
    for (final resource in resources)
      if (resource.entry.kind == kind)
        PackRowState(
          resource,
          integrityFailed: _installedFailed(resource.entry.id),
        ),
  ];

  bool _installedFailed(String packId) {
    final state = _integrity.stateOf(packId);
    return state is IntegrityFailed &&
        !identical(state, _redownloadedOver[packId]) &&
        _installs.installed.any((pack) => pack.id == packId);
  }

  int _usedBytes(PackKind kind) => _installs.installed
      .where((pack) => pack.manifest.kind == kind)
      .fold(0, (sum, pack) => sum + _bytesOf(pack));

  static int _bytesOf(InstalledPack pack) =>
      pack.manifest.files.fold(0, (sum, file) => sum + file.bytes);

  Future<void> _refresh() async {
    final result = await _catalogue.refresh();
    if (_disposed) return;
    _unreachable = result is Failure;
    notifyListeners();
  }

  /// Reads the free space; an answer that a later read overtook is dropped.
  Future<void> _readFreeSpace() async {
    _installedSeen = _installs.installed;
    final read = ++_freeReads;
    final free = await _freeBytes();
    if (_disposed || read != _freeReads || free == _free) return;
    _free = free;
    notifyListeners();
  }

  /// The installer notifies on every download tick; the free space changes
  /// with the installed packs.
  void _onInstalls() {
    notifyListeners();
    if (!identical(_installs.installed, _installedSeen)) {
      unawaited(_readFreeSpace());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _catalogue.removeListener(notifyListeners);
    _integrity.removeListener(notifyListeners);
    _installs.removeListener(_onInstalls);
    super.dispose();
  }
}
