import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/catalogue_repository.dart';
import 'package:holyquran/data/repositories/download_settings_repository.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/recitation_download_repository.dart';
import 'package:holyquran/data/repositories/recitation_repository.dart';
import 'package:holyquran/domain/models/catalogue_entry.dart';
import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/recitation_download.dart';
import 'package:holyquran/domain/models/recitation_target.dart';
import 'package:holyquran/domain/models/resource_state.dart';
import 'package:holyquran/ui/core/metrics/resources_metrics.dart';
import 'package:holyquran/ui/core/throttle.dart';
import 'package:holyquran/ui/features/resources/view_models/pack_row_state.dart';
import 'package:holyquran/ui/features/resources/view_models/recitation_block_state.dart';
import 'package:holyquran/ui/features/resources/view_models/recitation_tally.dart';
import 'package:holyquran/utils/result.dart';

/// The recitations section of the resource manager (`AU-13`, `AU-14`,
/// `OF-04`): each listed recitation's pack, and once the pack is installed
/// the whole, each surah and each juz, with the size still to download,
/// the quality to choose, progress, stop, delete and Wi-Fi only.
final class RecitationSectionViewModel extends ChangeNotifier {
  /// [index] gives the surahs and juz; without it only the whole is offered.
  /// [refreshEvery] is how often the files on the device are counted again
  /// while a download adds to them.
  RecitationSectionViewModel({
    required this._recitations,
    required this._catalogue,
    required this._installs,
    required this._integrity,
    required this._downloads,
    required this._settings,
    this._index,
    this._refreshEvery = recitationCountEvery,
  }) {
    for (final source in _sources) {
      source.addListener(_onChange);
    }
    _syncPacks();
  }

  final RecitationRepository _recitations;
  final CatalogueRepository _catalogue;
  final PackInstallRepository _installs;
  final PackIntegrityRepository _integrity;
  final RecitationDownloadRepository _downloads;
  final DownloadSettingsRepository _settings;
  final QuranIndexRepository? _index;
  final Duration _refreshEvery;

  late final List<Listenable> _sources = [
    _recitations,
    _catalogue,
    _installs,
    _integrity,
    _downloads,
    _settings,
  ];

  bool _disposed = false;
  bool _settingNotSaved = false;
  late final _counts = Throttle(_refreshEvery, _readAllPresent);
  int _revisionSeen = 0;
  Set<String> _jobKeys = const {};

  final _packs = <String, RecitationPackFiles>{};
  final _loading = <String>{};
  final _unreadable = <String, int>{};
  final _reads = <(String, int), int>{};
  final _qualityOf = <String, int>{};
  final _tabOf = <String, ScopeTab>{};
  final _present = <(String, int), Set<String>>{};
  final _tallies = <(String, int), Map<String, RecitationCount>>{};
  final _audioBytes = <String, int>{};
  final _refused = <String, RecitationDownloadFailure>{};
  late final List<RecitationScope> _scopes = scopesOf(_index);

  /// Whether downloads wait for Wi-Fi: on until the user turns it off, and
  /// kept across launches. The downloads follow the setting themselves.
  bool get wifiOnly => _settings.wifiOnly;

  set wifiOnly(bool value) =>
      unawaited(_saved(() => _settings.setWifiOnly(value)));

  /// The last change of Wi-Fi only or of a quality could not be stored; what
  /// is shown is the value that is stored.
  bool get settingNotSaved => _settingNotSaved;

  /// What the listed recitations use on the device: their installed packs
  /// and their audio at every quality (`OF-03`).
  int get usedBytes {
    var bytes = 0;
    for (final listed in _recitations.recitations) {
      final installed = _installs.installed
          .where((pack) => pack.id == listed.packId)
          .firstOrNull;
      if (installed == null) continue;
      bytes += _packBytes(installed);
      bytes += _audioBytes[listed.packId] ?? 0;
    }
    return bytes;
  }

  /// The surah [number]'s name from the base pack; null without an index.
  PackText? surahName(int number) =>
      _index?.surahs.where((surah) => surah.number == number).firstOrNull?.name;

  /// The listed recitations in the catalogue's order, each with its pack.
  List<RecitationBlockState> get blocks {
    final catalogue = _catalogue.catalogue;
    if (catalogue == null) return const [];
    final jobs = {for (final job in _downloads.jobs) job.key: job};
    return [
      for (final listed in _recitations.recitations)
        if (listed.recitation.rightsComplete)
          ?_block(listed, catalogue.pack(listed.packId), jobs),
    ];
  }

  void selectQuality(String recitationId, int kbps) {
    final listed = _recitations.recitations
        .where((r) => r.id == recitationId)
        .firstOrNull;
    if (listed == null || !listed.qualities.contains(kbps)) return;
    if (_chosenQuality(recitationId) == kbps) return;
    _qualityOf[recitationId] = kbps;
    unawaited(_saveQuality(recitationId, kbps));
    unawaited(_readPresent(recitationId));
    notifyListeners();
  }

  /// The choice shows at once; once the write ends, the stored value is the
  /// one that shows, which differs from it only when the write failed.
  Future<void> _saveQuality(String recitationId, int kbps) async {
    final saved = await _saved(() => _settings.setQuality(recitationId, kbps));
    if (_disposed) return;
    if (_qualityOf[recitationId] == kbps) _qualityOf.remove(recitationId);
    if (!saved) {
      unawaited(_readPresent(recitationId));
      notifyListeners();
    }
  }

  Future<bool> _saved(Future<Result<void>> Function() write) async {
    final result = await write();
    final saved = result is Ok<void>;
    if (!_disposed && _settingNotSaved == saved) {
      _settingNotSaved = !saved;
      notifyListeners();
    }
    return saved;
  }

  void selectTab(String recitationId, ScopeTab tab) {
    _tabOf[recitationId] = tab;
    notifyListeners();
  }

  /// Installs the recitation's pack, which lists its files and their sizes.
  void downloadPack(String recitationId) {
    if (_entryOf(recitationId) case final entry?) {
      unawaited(_installs.install(entry.installRequest(wifiOnly: wifiOnly)));
    }
  }

  /// What deleting the recitation frees: its audio at every quality and
  /// its pack as installed on the device.
  Future<int> sizeToDelete(String recitationId) async {
    final entry = _entryOf(recitationId);
    if (entry == null) return 0;
    final installed = _installs.installed
        .where((pack) => pack.id == entry.id)
        .firstOrNull;
    return await _downloads.audioBytes(entry.id) +
        (installed == null ? 0 : _packBytes(installed));
  }

  static int _packBytes(InstalledPack installed) =>
      installed.manifest.files.fold(0, (sum, f) => sum + f.bytes);

  /// Deletes all the recitation's audio, at every quality, and then its
  /// pack. A recitation with a job running is not deleted; its row offers no
  /// delete.
  Future<void> deleteRecitation(String recitationId) async {
    final entry = _entryOf(recitationId);
    if (entry == null) return;
    if (await _downloads.deleteAudio(entry.id) case Failure()) return;
    _tallies.removeWhere((key, _) => key.$1 == recitationId);
    _audioBytes.remove(entry.id);
    await _installs.delete(entry.id);
  }

  /// Installs the pack afresh, after it failed its check.
  Future<void> redownloadPack(String recitationId) async {
    if (_entryOf(recitationId) case final entry?) {
      if (await _installs.delete(entry.id) case Failure()) return;
      downloadPack(recitationId);
    }
  }

  void download(String recitationId, ScopeRowState row) {
    final pack = _packs[recitationId];
    final quality = _chosenQuality(recitationId);
    if (pack == null || quality == null) return;
    final target = RecitationTarget(pack.contents, quality, row.selection);
    _refused.remove(row.key);
    unawaited(
      _downloads.download(target, wifiOnly: wifiOnly).then((result) {
        if (result case Failure(error: final RecitationDownloadFailure failure)
            when failure is! RecitationDownloadCancelled &&
                _downloads.jobs.every((job) => job.key != row.key)) {
          _refused[row.key] = failure;
          if (!_disposed) notifyListeners();
        }
      }),
    );
  }

  void stop(ScopeRowState row) => unawaited(_downloads.cancel(row.key));

  Future<void> delete(String recitationId, ScopeRowState row) async {
    final pack = _packs[recitationId];
    final quality = _chosenQuality(recitationId);
    if (pack == null || quality == null) return;
    final result = await _downloads.delete(
      RecitationTarget(pack.contents, quality, row.selection),
    );
    if (result case Failure(error: final RecitationDownloadFailure failure)) {
      _refused[row.key] = failure;
    }
    await _readPresent(recitationId);
    await _readAudioBytes();
    if (!_disposed) notifyListeners();
  }

  RecitationBlockState? _block(
    CatalogueRecitation listed,
    CatalogueEntry? entry,
    Map<String, RecitationDownloadJob> jobs,
  ) {
    if (entry == null) return null;
    final id = listed.id;
    final installed = _installs.installed
        .where((pack) => pack.id == entry.id)
        .firstOrNull;
    final resource = resourceOf(
      entry,
      installed: installed,
      job: _installs.jobs
          .where((j) => j.request.packId == entry.id)
          .firstOrNull,
    );
    final pack = PackRowState(
      resource,
      integrityFailed:
          installed != null && _integrity.stateOf(entry.id) is IntegrityFailed,
    );
    final hasJob = jobs.values.any(
      (job) =>
          job.target.contents.packId == entry.id &&
          job.state is! RecitationDownloadFailed,
    );
    final quality = _chosenQuality(id);
    final tally = quality == null ? null : _tallies[(id, quality)];
    if (quality == null || tally == null) {
      return RecitationBlockState(
        recitation: listed,
        pack: pack,
        hasJob: hasJob,
      );
    }
    final rows = <ScopeKind, List<ScopeRowState>>{};
    for (final scope in _scopes) {
      final key = RecitationTarget.keyOf(id, quality, scope.selection);
      final count = tally[scope.selection.key];
      if (count == null || count.total == 0) continue;
      // A surah the base pack names no way is left out, not shown unnamed.
      if (scope.kind == ScopeKind.surah && surahName(scope.number) == null) {
        continue;
      }
      rows
          .putIfAbsent(scope.kind, () => [])
          .add(_row(scope, key, count, jobs[key]));
    }
    return RecitationBlockState(
      recitation: listed,
      pack: pack,
      hasJob: hasJob,
      qualities: listed.qualities,
      quality: quality,
      tab: _tabOf[id] ?? ScopeTab.surahs,
      whole: rows[ScopeKind.whole]?.single,
      surahs: rows[ScopeKind.surah] ?? const [],
      juz: rows[ScopeKind.juz] ?? const [],
    );
  }

  ScopeRowState _row(
    RecitationScope scope,
    String key,
    RecitationCount count,
    RecitationDownloadJob? job,
  ) {
    ScopeRowState row(
      ScopeStatus status, {
      double progress = 0,
      bool waitingForWifi = false,
      RecitationDownloadFailure? failure,
    }) => ScopeRowState(
      kind: scope.kind,
      number: scope.number,
      selection: scope.selection,
      key: key,
      totalBytes: count.total,
      missingBytes: count.missing,
      status: status,
      progress: progress,
      waitingForWifi: waitingForWifi,
      failure: failure,
    );
    return switch (job?.state) {
      RecitationDownloading(:final progress) => row(
        ScopeStatus.downloading,
        progress: progress.fraction ?? 0,
      ),
      RecitationQueued() => row(ScopeStatus.queued),
      RecitationWaitingForNetwork(:final wifiOnly) => row(
        ScopeStatus.waiting,
        waitingForWifi: wifiOnly,
      ),
      RecitationDownloadFailed(:final failure) => row(
        count.missing == 0 ? ScopeStatus.downloaded : ScopeStatus.available,
        failure: failure,
      ),
      null => row(
        count.missing == 0 ? ScopeStatus.downloaded : ScopeStatus.available,
        failure: _refused[key],
      ),
    };
  }

  CatalogueEntry? _entryOf(String recitationId) {
    final listed = _recitations.recitations
        .where((r) => r.id == recitationId)
        .firstOrNull;
    return listed == null ? null : _catalogue.catalogue?.pack(listed.packId);
  }

  int? _chosenQuality(String recitationId) {
    final listed = _recitations.recitations
        .where((r) => r.id == recitationId)
        .firstOrNull;
    if (listed == null) return null;
    final chosen =
        _qualityOf[recitationId] ?? _settings.qualityOf(recitationId);
    // Without a choice, the best the recitation offers (owner, 2026-10-29).
    return chosen != null && listed.qualities.contains(chosen)
        ? chosen
        : listed.qualities.last;
  }

  void _onChange() {
    _syncPacks();
    _watchJobs();
    notifyListeners();
  }

  /// Reads the files of each installed recitation pack, and forgets those
  /// of a pack that went or changed version.
  void _syncPacks() {
    for (final listed in _recitations.recitations) {
      final installed = _installs.installed
          .where((pack) => pack.id == listed.packId)
          .firstOrNull;
      final id = listed.id;
      if (installed == null) {
        _forget(id);
        _unreadable.remove(id);
      } else if (_packs[id]?.version != installed.version &&
          _unreadable[id] != installed.version &&
          _loading.add(id)) {
        unawaited(_load(id, installed));
      }
    }
  }

  Future<void> _load(String id, InstalledPack installed) async {
    final result = await _downloads.contents(id);
    _loading.remove(id);
    if (_disposed) return;
    switch (result) {
      case Ok(:final value):
        _forget(id);
        _packs[id] = RecitationPackFiles(value, installed.version);
        await _readPresent(id);
      case Failure():
        // Left alone until another version is installed: a pack that does
        // not verify serves nothing, and its row says so.
        _forget(id);
        _unreadable[id] = installed.version;
    }
    await _readAudioBytes();
    if (!_disposed) notifyListeners();
  }

  void _forget(String id) {
    _packs.remove(id);
    _present.removeWhere((key, _) => key.$1 == id);
    _tallies.removeWhere((key, _) => key.$1 == id);
  }

  /// Counts the recitation's files on the device at the chosen quality.
  Future<void> _readPresent(String id) async {
    final pack = _packs[id];
    final quality = _chosenQuality(id);
    if (pack == null || quality == null) return;
    final read = _reads[(id, quality)] = (_reads[(id, quality)] ?? 0) + 1;
    final present = await _downloads.present(pack.contents, quality);
    // A count that a later one overtook is dropped.
    if (_disposed || !identical(_packs[id], pack)) return;
    if (read != _reads[(id, quality)]) return;
    _present[(id, quality)] = present;
    _tallies[(id, quality)] = pack.tally(_scopes, quality, present);
    notifyListeners();
  }

  /// The files on the device change as a download goes on, and a count of
  /// them costs a look at every file: it is taken again when a job starts
  /// or ends, and otherwise at most once in [_refreshEvery].
  void _watchJobs() {
    final keys = {for (final job in _downloads.jobs) job.key};
    final changed = !setEquals(keys, _jobKeys);
    _jobKeys = keys;
    final revision = _downloads.revision;
    if (!changed && revision == _revisionSeen) return;
    _revisionSeen = revision;
    if (changed) {
      _counts.now();
    } else {
      _counts.soon();
    }
  }

  void _readAllPresent() {
    for (final id in _packs.keys.toList()) {
      unawaited(_readPresent(id));
    }
    unawaited(_readAudioBytes());
  }

  /// What the audio of each installed recitation uses on the device, at
  /// every quality.
  Future<void> _readAudioBytes() async {
    for (final listed in _recitations.recitations) {
      if (!_installs.installed.any((pack) => pack.id == listed.packId)) {
        _audioBytes.remove(listed.packId);
        continue;
      }
      final bytes = await _downloads.audioBytes(listed.packId);
      if (_disposed) return;
      _audioBytes[listed.packId] = bytes;
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _counts.cancel();
    for (final source in _sources) {
      source.removeListener(_onChange);
    }
    super.dispose();
  }
}
