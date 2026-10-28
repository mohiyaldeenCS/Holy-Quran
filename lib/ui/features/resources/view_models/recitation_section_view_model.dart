import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/catalogue_repository.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/recitation_download_repository.dart';
import 'package:holyquran/data/repositories/recitation_repository.dart';
import 'package:holyquran/domain/models/catalogue_entry.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_range.dart';
import 'package:holyquran/domain/models/recitation_download.dart';
import 'package:holyquran/domain/models/recitation_file.dart';
import 'package:holyquran/domain/models/recitation_target.dart';
import 'package:holyquran/domain/models/resource_state.dart';
import 'package:holyquran/ui/core/metrics/resources_metrics.dart';
import 'package:holyquran/ui/features/resources/view_models/pack_row_state.dart';
import 'package:holyquran/ui/features/resources/view_models/recitation_block_state.dart';
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
  final QuranIndexRepository? _index;
  final Duration _refreshEvery;

  late final List<Listenable> _sources = [
    _recitations,
    _catalogue,
    _installs,
    _integrity,
    _downloads,
  ];

  bool _wifiOnly = true;
  bool _disposed = false;
  Timer? _refresh;
  int _revisionSeen = 0;
  Set<String> _jobKeys = const {};

  final _packs = <String, _Pack>{};
  final _loading = <String>{};
  final _unreadable = <String, int>{};
  final _reads = <(String, int), int>{};
  final _qualityOf = <String, int>{};
  final _tabOf = <String, ScopeTab>{};
  final _present = <(String, int), Set<String>>{};
  final _tallies = <(String, int), Map<String, _Count>>{};
  final _refused = <String, RecitationDownloadFailure>{};
  late final List<_Scope> _scopes = _scopesOf(_index);

  /// Whether downloads wait for Wi-Fi. On until the user turns it off.
  bool get wifiOnly => _wifiOnly;

  set wifiOnly(bool value) {
    if (value == _wifiOnly) return;
    _wifiOnly = value;
    notifyListeners();
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
    if (_qualityOf[recitationId] == kbps) return;
    _qualityOf[recitationId] = kbps;
    unawaited(_readPresent(recitationId));
    notifyListeners();
  }

  void selectTab(String recitationId, ScopeTab tab) {
    _tabOf[recitationId] = tab;
    notifyListeners();
  }

  /// Installs the recitation's pack, which lists its files and their sizes.
  void downloadPack(String recitationId) {
    if (_entryOf(recitationId) case final entry?) {
      unawaited(_installs.install(entry.installRequest(wifiOnly: _wifiOnly)));
    }
  }

  /// Deletes the recitation's audio at every quality and then its pack.
  Future<void> deleteRecitation(String recitationId) async {
    final entry = _entryOf(recitationId);
    if (entry == null) return;
    if (_packs[recitationId] case _Pack(:final contents)) {
      for (final quality in _qualitiesOf(contents)) {
        final target = RecitationTarget(
          contents,
          quality,
          const WholeRecitation(),
        );
        if (await _downloads.delete(target) case Failure()) return;
      }
    }
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
      _downloads.download(target, wifiOnly: _wifiOnly).then((result) {
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
    await _downloads.delete(
      RecitationTarget(pack.contents, quality, row.selection),
    );
    await _readPresent(recitationId);
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
    final quality = _chosenQuality(id);
    final tally = quality == null ? null : _tallies[(id, quality)];
    if (quality == null || tally == null) {
      return RecitationBlockState(recitation: listed, pack: pack);
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
      qualities: listed.qualities,
      quality: quality,
      tab: _tabOf[id] ?? ScopeTab.surahs,
      whole: rows[ScopeKind.whole]?.single,
      surahs: rows[ScopeKind.surah] ?? const [],
      juz: rows[ScopeKind.juz] ?? const [],
    );
  }

  ScopeRowState _row(
    _Scope scope,
    String key,
    _Count count,
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
      RecitationQueued() => row(ScopeStatus.downloading),
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
    final chosen = _qualityOf[recitationId];
    return chosen != null && listed.qualities.contains(chosen)
        ? chosen
        : listed.qualities.first;
  }

  static Set<int> _qualitiesOf(RecitationContents contents) => {
    for (final file in contents.files) file.qualityKbps,
  };

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
        _packs[id] = _Pack(value, installed.version);
        await _readPresent(id);
      case Failure():
        // Left alone until another version is installed: a pack that does
        // not verify serves nothing, and its row says so.
        _forget(id);
        _unreadable[id] = installed.version;
    }
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
    _tallies[(id, quality)] = _tally(pack, quality, present);
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
      _refresh?.cancel();
      _refresh = null;
      _readAllPresent();
    } else {
      _refresh ??= Timer(_refreshEvery, () {
        _refresh = null;
        _readAllPresent();
      });
    }
  }

  void _readAllPresent() {
    for (final id in _packs.keys.toList()) {
      unawaited(_readPresent(id));
    }
  }

  Map<String, _Count> _tally(_Pack pack, int quality, Set<String> present) {
    final files = pack.byQuality[quality] ?? const _Files();
    return {
      for (final scope in _scopes)
        scope.selection.key: _count(files, scope.selection, present),
    };
  }

  static _Count _count(
    _Files files,
    RecitationSelection selection,
    Set<String> present,
  ) {
    var total = 0;
    var missing = 0;
    void add(RecitationFile file) {
      total += file.bytes;
      if (!present.contains(file.path)) missing += file.bytes;
    }

    files.common.forEach(add);
    final (first, last) = switch (selection) {
      WholeRecitation() => (1, files.bySurah.keys.fold(1, _larger)),
      RecitationSurah(:final surah) => (surah, surah),
      RecitationSpan(:final range) => (range.start.surah, range.end.surah),
    };
    for (var surah = first; surah <= last; surah++) {
      for (final file in files.bySurah[surah] ?? const <RecitationFile>[]) {
        if (selection.includes(file)) add(file);
      }
    }
    return _Count(total, missing);
  }

  static int _larger(int a, int b) => a > b ? a : b;

  static List<_Scope> _scopesOf(QuranIndexRepository? index) => [
    const _Scope(ScopeKind.whole, 0, WholeRecitation()),
    if (index != null) ...[
      for (var surah = 1; surah <= index.surahCount; surah++)
        _Scope(ScopeKind.surah, surah, RecitationSurah(surah)),
      for (var juz = 1; juz <= index.count(Division.juz); juz++)
        _Scope(ScopeKind.juz, juz, RecitationSpan(_juzRange(index, juz))),
    ],
  ];

  /// From the first ayah of the juz to the ayah before the next juz starts.
  static QuranRange _juzRange(QuranIndexRepository index, int juz) {
    final start = index.firstAyah(Division.juz, juz);
    final QuranAddress end;
    if (juz < index.count(Division.juz)) {
      final next = index.firstAyah(Division.juz, juz + 1);
      end = next.ayah > 1
          ? QuranAddress(next.riwaya, next.surah, next.ayah - 1)
          : QuranAddress(
              next.riwaya,
              next.surah - 1,
              index.ayahCount(next.surah - 1),
            );
    } else {
      final last = index.surahCount;
      end = QuranAddress(index.riwaya, last, index.ayahCount(last));
    }
    return QuranRange(start, end);
  }

  @override
  void dispose() {
    _disposed = true;
    _refresh?.cancel();
    for (final source in _sources) {
      source.removeListener(_onChange);
    }
    super.dispose();
  }
}

final class _Scope {
  const _Scope(this.kind, this.number, this.selection);

  final ScopeKind kind;
  final int number;
  final RecitationSelection selection;
}

final class _Count {
  const _Count(this.total, this.missing);

  final int total;
  final int missing;
}

/// The files of one quality: those of no surah, which every selection
/// takes, and the others by surah.
final class _Files {
  const _Files({this.common = const [], this.bySurah = const {}});

  final List<RecitationFile> common;
  final Map<int, List<RecitationFile>> bySurah;
}

final class _Pack {
  _Pack(this.contents, this.version) {
    final common = <int, List<RecitationFile>>{};
    final bySurah = <int, Map<int, List<RecitationFile>>>{};
    for (final file in contents.files) {
      final surah = file.surah;
      if (surah == null) {
        common.putIfAbsent(file.qualityKbps, () => []).add(file);
      } else {
        bySurah
            .putIfAbsent(file.qualityKbps, () => {})
            .putIfAbsent(surah, () => [])
            .add(file);
      }
    }
    byQuality = {
      for (final quality in {...common.keys, ...bySurah.keys})
        quality: _Files(
          common: common[quality] ?? const [],
          bySurah: bySurah[quality] ?? const {},
        ),
    };
  }

  final RecitationContents contents;
  final int version;
  late final Map<int, _Files> byQuality;
}
