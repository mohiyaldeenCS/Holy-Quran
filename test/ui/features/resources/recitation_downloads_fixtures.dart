import 'package:flutter/foundation.dart';
import 'package:holyquran/data/repositories/recitation_download_repository.dart';
import 'package:holyquran/domain/models/download_progress.dart';
import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/domain/models/recitation_download.dart';
import 'package:holyquran/domain/models/recitation_file.dart';
import 'package:holyquran/domain/models/recitation_target.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../testing/fakes/fake_catalogue_repository.dart';

/// The synthetic catalogue's listed recitation, whose pack is
/// [recitationPackId], and its qualities.
const recitationId = 'synthetic-listed';
const recitationPackId = 'synthetic-recitation';
const qualities = [64, 128];

/// Every synthetic ayah file takes this many bytes: 0.5 MB.
const fileBytes = 500000;

/// The ayat of the synthetic index: surah 1 has 4, surah 2 has 3 and surah
/// 3 has 1. Its first juz ends with surah 1 and its second starts at 2:1.
const ayatOfSurah = {1: 4, 2: 3, 3: 1};

/// The files of the synthetic recitation, at each quality: one per ayah and
/// the reciter's own basmala. All of it is invented.
RecitationContents syntheticContents({
  int? onlySurah,
  bool withBasmala = false,
}) => RecitationContents(
  recitationId: recitationId,
  packId: recitationPackId,
  baseUrl: Uri.parse('https://example.invalid/synthetic/audio/'),
  unit: RecitationUnit.ayah,
  files: [
    if (withBasmala)
      for (final quality in qualities)
        RecitationFile(
          qualityKbps: quality,
          part: RecitationFilePart.basmala,
          surah: null,
          ayah: null,
          path: basmalaPath(quality),
          bytes: fileBytes,
          sha256: syntheticHash(),
          duration: null,
        ),
    for (final quality in qualities)
      for (final MapEntry(key: surah, value: ayat) in ayatOfSurah.entries)
        if (onlySurah == null || onlySurah == surah)
          for (var ayah = 1; ayah <= ayat; ayah++)
            RecitationFile(
              qualityKbps: quality,
              part: RecitationFilePart.ayah,
              surah: surah,
              ayah: ayah,
              path: 'q$quality/${surah}_$ayah.mp3',
              bytes: fileBytes,
              sha256: syntheticHash(),
              duration: null,
            ),
  ],
);

/// The path in the pack of the reciter's basmala at a quality.
String basmalaPath(int quality) => 'q$quality/basmala.mp3';

/// The path in the pack of an ayah file at a quality.
String ayahPath(int quality, int surah, int ayah) =>
    'q$quality/${surah}_$ayah.mp3';

/// The recitation pack installed, at the catalogue's version.
InstalledPack installedRecitationPack({int version = 1}) => InstalledPack(
  manifest: PackManifest(
    formatVersion: 2,
    id: recitationPackId,
    kind: PackKind.recitation,
    version: version,
    changelog: const [],
    riwaya: 'hafs',
    sources: const [],
    files: const [],
    counts: const RecitationCounts(files: 1),
    reviews: const [],
  ),
  directory: '/synthetic/$recitationPackId/$version',
  previousVersion: null,
);

/// A [RecitationDownloadRepository] in memory, for view-model tests. A test
/// sets [jobs], which notifies listeners, and [onDevice], the paths whose
/// file is whole; [download] answers with [downloads], by default at once;
/// every call is logged in [calls].
final class FakeRecitationDownloadRepository extends ChangeNotifier
    implements RecitationDownloadRepository {
  FakeRecitationDownloadRepository({RecitationContents? contents})
    : stored = contents ?? syntheticContents();

  RecitationContents stored;
  Set<String> onDevice = {};
  List<RecitationDownloadJob> _jobs = const [];
  int _revision = 0;
  Result<RecitationContents>? contentsAnswer;
  Result<void> Function(RecitationTarget target, bool wifiOnly) downloads =
      (_, _) => const Ok(null);
  Result<void> Function(RecitationTarget target) deletes = (_) =>
      const Ok(null);
  final List<(String, String)> calls = [];
  final List<bool> wifiOnlyOf = [];

  @override
  List<RecitationDownloadJob> get jobs => _jobs;

  set jobs(List<RecitationDownloadJob> value) {
    _jobs = value;
    notifyListeners();
  }

  @override
  int get revision => _revision;

  /// Puts [paths] on the device, as a finished file would.
  void arrive(Set<String> paths) {
    onDevice = {...onDevice, ...paths};
    _revision++;
    notifyListeners();
  }

  @override
  Future<Result<RecitationContents>> contents(String id) async {
    calls.add(('contents', id));
    return contentsAnswer ?? Ok(stored);
  }

  @override
  Future<Set<String>> present(RecitationContents contents, int quality) async {
    calls.add(('present', '$quality'));
    return {
      for (final file in contents.files)
        if (file.qualityKbps == quality && onDevice.contains(file.path))
          file.path,
    };
  }

  @override
  Future<bool> hasAudio(String packId) async => onDevice.isNotEmpty;

  /// What is on the device at every quality, [fileBytes] a file.
  @override
  Future<int> audioBytes(String packId) async => bytesOnDevice;

  int get bytesOnDevice => onDevice.length * fileBytes;

  @override
  Future<Result<void>> deleteAudio(String packId) async {
    calls.add(('deleteAudio', packId));
    onDevice = {};
    _revision++;
    notifyListeners();
    return const Ok(null);
  }

  @override
  Future<Result<void>> download(
    RecitationTarget target, {
    required bool wifiOnly,
  }) async {
    calls.add(('download', target.key));
    wifiOnlyOf.add(wifiOnly);
    return downloads(target, wifiOnly);
  }

  @override
  void setWifiOnly(bool wifiOnly) => calls.add(('setWifiOnly', '$wifiOnly'));

  @override
  Future<void> cancel(String key) async => calls.add(('cancel', key));

  @override
  Future<Result<void>> delete(RecitationTarget target) async {
    calls.add(('delete', target.key));
    if (deletes(target) case Failure(:final error)) return Failure(error);
    onDevice = onDevice.difference({
      for (final file in target.files) file.path,
    });
    _revision++;
    notifyListeners();
    return const Ok(null);
  }
}

/// A job for [target] in [state].
RecitationDownloadJob jobFor(
  RecitationTarget target,
  RecitationDownloadState state,
) => RecitationDownloadJob(target, state);

/// Downloading, with [received] of [total] bytes arrived.
RecitationDownloading downloadingBytes(int received, int total) =>
    RecitationDownloading(
      DownloadProgress(receivedBytes: received, totalBytes: total),
    );
