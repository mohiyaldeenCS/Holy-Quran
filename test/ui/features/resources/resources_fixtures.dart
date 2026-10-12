import 'package:holyquran/data/models/catalogue_json.dart';
import 'package:holyquran/domain/models/catalogue.dart';
import 'package:holyquran/domain/models/download_progress.dart';
import 'package:holyquran/domain/models/install_job.dart';
import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../testing/fakes/fake_catalogue_repository.dart';

/// The synthetic catalogue's first-use tafsir, at version 2.
const firstUseId = 'synthetic-tafsir';
const textId = 'synthetic-text';

/// Tafsir packs added to the synthetic catalogue, one per state a test
/// puts it in; every one at version 2.
const downloadingId = 'synthetic-tafsir-downloading';
const downloadedId = 'synthetic-tafsir-downloaded';
const updateId = 'synthetic-tafsir-update';
const failedId = 'synthetic-tafsir-failed';
const offlineId = 'synthetic-tafsir-offline';

const extraTafsirs = [
  downloadingId,
  downloadedId,
  updateId,
  failedId,
  offlineId,
];

String titleOf(String id) => 'Synthetic title of $id';

/// The synthetic catalogue with [extra] tafsir packs after its own, each
/// titled [titleOf] its id, with the change summary «Synthetic change
/// summary».
Catalogue catalogueWith([List<String> extra = extraTafsirs]) {
  final json = syntheticCatalogueJson();
  final packs = [...json['packs']! as List<Object?>];
  final tafsir = packs[1]! as Map<String, Object?>;
  packs.insertAll(2, [
    for (final id in extra)
      {...tafsir, 'id': id, 'title': titleOf(id), 'role': null},
  ]);
  return switch (parseCatalogue(catalogueBytes({...json, 'packs': packs}))) {
    Ok(:final value) => value,
    Failure(:final error) => throw StateError('$error'),
  };
}

/// An installed tafsir pack [id] at [version] whose files take [bytes].
InstalledPack installedTafsir(String id, {int version = 2, int bytes = 1000}) =>
    InstalledPack(
      manifest: PackManifest(
        formatVersion: 2,
        id: id,
        kind: PackKind.tafsir,
        version: version,
        changelog: const [],
        riwaya: 'hafs',
        sources: const [],
        files: [
          PackFile(
            name: 'tafsir.sqlite',
            sha256: syntheticHash(),
            bytes: bytes,
          ),
        ],
        counts: const TafsirCounts(passages: 0),
        reviews: const [],
      ),
      directory: '/synthetic/packs/$id/$version',
      previousVersion: null,
    );

InstallJob jobOf(Catalogue catalogue, String id, InstallState state) =>
    InstallJob(catalogue.pack(id)!.installRequest(wifiOnly: false), state);

/// 600 of 1000 bytes arrived.
const sixtyPercent = InstallDownloading(
  DownloadProgress(receivedBytes: 600, totalBytes: 1000),
);

InstallFailed verificationFailed(String id) => InstallFailed(
  VerificationFailed(id, FileHashMismatch(id, 'tafsir.sqlite')),
);

InstallFailed downloadFailed(String id) =>
    InstallFailed(DownloadFailed(id, 'tafsir.sqlite'));
