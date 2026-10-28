import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/catalogue_repository.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/repositories/recitation_download_repository.dart';
import 'package:holyquran/data/repositories/recitation_repository.dart';
import 'package:holyquran/domain/models/catalogue_entry.dart';
import 'package:holyquran/domain/models/install_job.dart';
import 'package:holyquran/domain/models/recitation_download.dart';
import 'package:holyquran/domain/models/resource_state.dart';

/// A recitation as the picker lists it (`AU-01`): its download state is
/// null when the catalogue or the installer cannot say.
typedef RecitationListing = ({
  CatalogueRecitation recitation,
  ResourceState? state,
});

/// The recitations that may be chosen, with their download state (`AU-01`,
/// `AU-13`), over whichever repositories the app provides; with no
/// recitation repository nothing is listed.
///
/// With the audio downloads, a recitation is downloaded once some of its
/// audio is on the device, and downloading while a job for it runs; without
/// them, the state is that of its pack.
final class RecitationPickerViewModel extends ChangeNotifier {
  RecitationPickerViewModel({
    this._recitations,
    this._catalogue,
    this._installs,
    this._downloads,
  }) {
    _changes.addListener(_onChange);
    unawaited(_readAudio());
  }

  final RecitationRepository? _recitations;
  final CatalogueRepository? _catalogue;
  final PackInstallRepository? _installs;
  final RecitationDownloadRepository? _downloads;
  late final Listenable _changes = Listenable.merge([
    _recitations,
    _catalogue,
    _installs,
    _downloads,
  ]);

  /// The pack ids whose audio is on the device, as last read.
  Set<String> _withAudio = const {};
  int _revisionSeen = 0;
  Set<String> _jobKeys = const {};
  bool _disposed = false;

  /// In the catalogue's order. A recitation without a complete rights
  /// record is never listed, whatever the repository hands over.
  List<RecitationListing> get listings => [
    for (final listed
        in _recitations?.recitations ?? const <CatalogueRecitation>[])
      if (listed.recitation.rightsComplete)
        (recitation: listed, state: _stateOf(listed)),
  ];

  ResourceState? _stateOf(CatalogueRecitation listed) {
    final entry = _catalogue?.catalogue?.pack(listed.packId);
    final installs = _installs;
    if (entry == null || installs == null) return null;
    final installed = installs.installed
        .where((p) => p.id == listed.packId)
        .firstOrNull;
    final pack = resourceOf(
      entry,
      installed: installed,
      job: installs.jobs
          .where((j) => j.request.packId == listed.packId)
          .firstOrNull,
    ).state;
    final downloads = _downloads;
    if (downloads == null) return pack;
    final job = downloads.jobs
        .where((j) => j.target.contents.recitationId == listed.id)
        .firstOrNull;
    return switch (job?.state) {
      RecitationDownloading(:final progress) => ResourceDownloading(
        InstallDownloading(progress),
      ),
      RecitationWaitingForNetwork(:final wifiOnly) => ResourceDownloading(
        InstallWaitingForNetwork(wifiOnly: wifiOnly),
      ),
      RecitationQueued() => const ResourceDownloading(InstallQueued()),
      _ when pack is ResourceDownloading => pack,
      _ when installed != null && _withAudio.contains(listed.packId) =>
        ResourceDownloaded(installed.version),
      _ => const ResourceAvailable(),
    };
  }

  void _onChange() {
    final downloads = _downloads;
    if (downloads != null) {
      final keys = {for (final job in downloads.jobs) job.key};
      if (downloads.revision != _revisionSeen || !setEquals(keys, _jobKeys)) {
        _revisionSeen = downloads.revision;
        _jobKeys = keys;
        unawaited(_readAudio());
      }
    }
    notifyListeners();
  }

  Future<void> _readAudio() async {
    final downloads = _downloads;
    if (downloads == null) return;
    final found = <String>{};
    for (final listed
        in _recitations?.recitations ?? const <CatalogueRecitation>[]) {
      if (await downloads.hasAudio(listed.packId)) found.add(listed.packId);
    }
    if (_disposed || setEquals(found, _withAudio)) return;
    _withAudio = found;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _changes.removeListener(_onChange);
    super.dispose();
  }
}
