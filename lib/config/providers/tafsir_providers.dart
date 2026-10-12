import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/tafsir_repository.dart';
import 'package:holyquran/data/services/daos/settings_dao.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';
import 'package:holyquran/domain/models/quran_structure.dart';
import 'package:holyquran/utils/result.dart';

// The installer and the settings are not provided by their areas yet, so
// there is nothing to build the repository on.
Future<void> tafsirProviders(Dependencies dependencies) async {}

/// Provides the [TafsirRepository] over the [PackInstallRepository], the
/// [PackIntegrityRepository] and the [QuranStructure] earlier areas
/// provided, keeping its settings in [settings] and checking packs with
/// [signatures]. When the settings cannot be read, nothing is provided.
Future<void> provideTafsir(
  Dependencies dependencies, {
  required SettingsDao settings,
  required ManifestSignatureVerifier signatures,
}) async {
  final loaded = await LocalTafsirRepository.load(
    installs: dependencies.read<PackInstallRepository>(),
    integrity: dependencies.read<PackIntegrityRepository>(),
    verifier: LocalPackRepository(
      files: const PackFileService(),
      signatures: signatures,
    ),
    structure: dependencies.read<QuranStructure>(),
    settings: settings,
  );
  if (loaded case Ok(:final value)) {
    dependencies.provideListenable<TafsirRepository>(value);
  }
}
