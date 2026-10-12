import 'dart:async';

import 'package:holyquran/config/base_pack.dart';
import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/signing_keys.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/services/base_pack_service.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/quran_structure.dart';
import 'package:holyquran/utils/result.dart';

Future<void> quranProviders(Dependencies dependencies) async {
  // Before B0.2 the app bundles no base pack, and there is nothing to read.
  if (bundledBasePack case final pack?) {
    await provideQuran(
      dependencies,
      basePack: BasePackService(id: pack.id, version: pack.version),
      signatures: Ed25519ManifestVerifier(manifestPublicKeys),
    );
  }
}

/// Provides the [PackIntegrityRepository], then checks the base pack and,
/// once it is verified, provides its [QuranTextRepository] and its
/// [QuranIndexRepository], also as the [QuranStructure]. A base pack that is
/// missing or failed provides only its integrity.
Future<void> provideQuran(
  Dependencies dependencies, {
  required BasePackService basePack,
  required ManifestSignatureVerifier signatures,
}) async {
  final packs = LocalPackRepository(
    files: const PackFileService(),
    signatures: signatures,
  );
  final integrity = LocalPackIntegrityRepository(
    basePack: basePack,
    verify: packs.verify,
    verifySizes: packs.verifySizes,
  );
  dependencies.provideListenable<PackIntegrityRepository>(integrity);

  final verified = await integrity.verifyBasePack();
  if (verified == null) return;
  bool serving() => integrity.stateOf(basePack.id) is IntegrityOk;
  void failed(Exception error) {
    if (!serving()) return;
    integrity.report(
      basePack.id,
      IntegrityFailed(
        error is PackFailure
            ? error
            : ManifestUnreadable(basePack.id, '$error'),
      ),
      version: basePack.version,
    );
    unawaited(integrity.forgetBasePackCheck());
  }

  final PackQuranTextRepository text;
  switch (PackQuranTextRepository.open(verified, onDisabled: failed)) {
    case Ok(:final value):
      text = value;
    case Failure(:final error):
      failed(error);
      return;
  }
  final index = switch ((await text.surahs(), await text.editionMap())) {
    (Ok(value: final surahs), Ok(value: final map)) =>
      PackQuranIndexRepository.build(
        riwaya: text.riwaya,
        surahs: surahs,
        map: map,
        serving: serving,
      ),
    (Failure(:final error), _) ||
    (_, Failure(:final error)) => Failure<PackQuranIndexRepository>(error),
  };
  switch (index) {
    case Ok(:final value):
      dependencies
        ..provide<QuranTextRepository>(text)
        ..provide<QuranIndexRepository>(value)
        ..provide<QuranStructure>(value);
    case Failure(:final error):
      failed(error);
      text.close();
  }
}
