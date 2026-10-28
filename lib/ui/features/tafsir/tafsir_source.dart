import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';

/// The source a tafsir pack was digitised from (`TF-05`): the manifest's
/// `tafsir` source, which a tafsir manifest must list first.
PackSource? digitisationSourceOf(InstalledPack pack) {
  for (final source in pack.manifest.sources) {
    if (source.role == SourceRole.tafsir) return source;
  }
  return null;
}
