import 'package:holyquran/data/repositories/tafsir_repository.dart';
import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';

/// The installed tafsir pack [packId], or null when it is not installed.
InstalledPack? installedTafsirOf(TafsirRepository tafsirs, String packId) {
  for (final pack in tafsirs.installed) {
    if (pack.id == packId) return pack;
  }
  return null;
}

/// The source a tafsir pack was digitised from (`TF-05`): its manifest's
/// `tafsir` source. The manifest parser refuses a tafsir manifest without one
/// and any source of another role, so the first source is it.
PackSource digitisationSourceOf(InstalledPack pack) =>
    pack.manifest.sources.first;
