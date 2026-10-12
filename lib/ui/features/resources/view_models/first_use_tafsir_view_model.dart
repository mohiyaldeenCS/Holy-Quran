import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/catalogue_repository.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/domain/models/resource_state.dart';
import 'package:holyquran/ui/features/resources/view_models/pack_row_state.dart';
import 'package:holyquran/utils/result.dart';

/// The offer of the catalogue's one short tafsir at the first use of tafsir
/// (`TF-06`), which the tafsir feature pushes while no tafsir is installed.
final class FirstUseTafsirViewModel extends ChangeNotifier {
  FirstUseTafsirViewModel({required this._catalogue, required this._installs}) {
    _catalogue.addListener(notifyListeners);
    _installs.addListener(notifyListeners);
    if (_catalogue.catalogue == null) unawaited(_refresh());
  }

  final CatalogueRepository _catalogue;
  final PackInstallRepository _installs;

  bool _unreachable = false;
  bool _requesting = false;
  bool _disposed = false;

  /// True when no catalogue could be fetched and none is kept.
  bool get unreachable => _unreachable && _catalogue.catalogue == null;

  /// The pack offered; null while the catalogue offers none.
  PackRowState? get row {
    final entry = _catalogue.catalogue?.firstUseTafsir;
    if (entry == null) return null;
    final resource = resourceOf(
      entry,
      installed: _installs.installed
          .where((pack) => pack.id == entry.id)
          .firstOrNull,
      job: _installs.jobs
          .where((job) => job.request.packId == entry.id)
          .firstOrNull,
    );
    return PackRowState(resource, integrityFailed: false);
  }

  /// Requests the pack once: further calls do nothing until that request
  /// has ended.
  Future<void> download() async {
    final entry = _catalogue.catalogue?.firstUseTafsir;
    if (entry == null || _requesting) return;
    _requesting = true;
    try {
      await _installs.install(entry.installRequest(wifiOnly: false));
    } finally {
      _requesting = false;
    }
  }

  void delete() {
    if (_catalogue.catalogue?.firstUseTafsir case final entry?) {
      unawaited(_installs.delete(entry.id));
    }
  }

  Future<void> _refresh() async {
    final result = await _catalogue.refresh();
    if (_disposed) return;
    _unreachable = result is Failure;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _catalogue.removeListener(notifyListeners);
    _installs.removeListener(notifyListeners);
    super.dispose();
  }
}
