import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/catalogue_repository.dart';
import 'package:holyquran/data/repositories/download_settings_repository.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/repositories/recitation_download_repository.dart';
import 'package:holyquran/data/repositories/recitation_repository.dart';
import 'package:holyquran/domain/models/catalogue_entry.dart';
import 'package:holyquran/domain/models/install_job.dart';
import 'package:holyquran/domain/models/recitation_download.dart';
import 'package:holyquran/domain/models/recitation_target.dart';
import 'package:holyquran/domain/models/resource_state.dart';
import 'package:holyquran/utils/result.dart';

/// A recitation as the picker lists it (`AU-01`): its download state is
/// null when the catalogue or the installer cannot say.
typedef RecitationListing = ({
  CatalogueRecitation recitation,
  ResourceState? state,

  /// Some of the audio is on the device, but not all of it.
  bool partial,
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
    this._settings,
  }) {
    _changes.addListener(_onChange);
    unawaited(_readAudio());
  }

  final RecitationRepository? _recitations;
  final CatalogueRepository? _catalogue;
  final PackInstallRepository? _installs;
  final RecitationDownloadRepository? _downloads;
  final DownloadSettingsRepository? _settings;
  late final Listenable _changes = Listenable.merge([
    _recitations,
    _catalogue,
    _installs,
    _downloads,
    _settings,
  ]);

  /// How much of each installed recitation is on the device, by pack id, at
  /// the quality chosen, as last read.
  Map<String, AudioCoverage> _coverage = const {};
  int _revisionSeen = 0;
  Object? _installedSeen;
  Set<String> _jobKeys = const {};
  int _reads = 0;
  bool _disposed = false;

  /// In the catalogue's order. A recitation without a complete rights
  /// record is never listed, whatever the repository hands over.
  List<RecitationListing> get listings => [
    for (final listed
        in _recitations?.recitations ?? const <CatalogueRecitation>[])
      if (listed.recitation.rightsComplete) _listing(listed),
  ];

  RecitationListing _listing(CatalogueRecitation listed) {
    final state = _stateOf(listed);
    return (
      recitation: listed,
      state: state,
      partial:
          state is ResourceAvailable &&
          _coverage[listed.packId] == AudioCoverage.partial,
    );
  }

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
      _ when pack is ResourceDownloading || pack is ResourceUpdateAvailable =>
        pack,
      _
          when installed != null &&
              _coverage[listed.packId] == AudioCoverage.whole =>
        ResourceDownloaded(installed.version),
      _ => const ResourceAvailable(),
    };
  }

  /// The quality chosen for [listed], else the highest it offers.
  int _qualityOf(CatalogueRecitation listed) {
    final chosen = _settings?.qualityOf(listed.id);
    return chosen != null && listed.qualities.contains(chosen)
        ? chosen
        : listed.qualities.last;
  }

  void _onChange() {
    final downloads = _downloads;
    if (downloads != null) {
      final keys = {for (final job in downloads.jobs) job.key};
      final installed = _installs?.installed;
      if (downloads.revision != _revisionSeen ||
          !setEquals(keys, _jobKeys) ||
          !identical(installed, _installedSeen)) {
        _installedSeen = installed;
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
    final read = ++_reads;
    final found = <String, AudioCoverage>{};
    for (final listed
        in _recitations?.recitations ?? const <CatalogueRecitation>[]) {
      if (_installs?.installed.any((p) => p.id == listed.packId) != true) {
        continue;
      }
      if (await downloads.contents(listed.id) case Ok(:final value)) {
        final quality = _qualityOf(listed);
        found[listed.packId] = value.coverageAt(
          quality,
          await downloads.present(value, quality),
        );
      }
    }
    if (_disposed || read != _reads || mapEquals(found, _coverage)) return;
    _coverage = found;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _changes.removeListener(_onChange);
    super.dispose();
  }
}
