import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/base_pack_guard.dart';
import 'package:holyquran/data/repositories/search_repository.dart';
import 'package:holyquran/data/repositories/tafsir_search_repository.dart';
import 'package:holyquran/data/services/search_index_service.dart';
import 'package:holyquran/domain/models/quran_structure.dart';
import 'package:holyquran/domain/models/verified_pack.dart';

/// Provides the [SearchRepository] of the verified base pack, which fails
/// once the pack stops serving and disables the pack when its index cannot
/// be built, through the [BasePackGuard] the Quran area provides with the
/// [VerifiedPack]. Without a base pack that verified and whose text and index
/// opened, there is nothing to search.
///
/// The search of tafsir books is not provided: it needs the verified packs of
/// the installed books, which only the tafsir repository holds, privately.
Future<void> searchProviders(Dependencies dependencies) async {
  final pack = dependencies.tryRead<VerifiedPack>();
  if (pack == null || dependencies.tryRead<QuranStructure>() == null) return;
  final guard = dependencies.read<BasePackGuard>();
  provideSearch(
    dependencies,
    pack: pack,
    serving: guard.serving,
    failed: guard.failed,
  );
}

/// Provides the [SearchRepository] of the verified base pack [pack], over
/// the [QuranStructure] an earlier area provided. It fails while [serving]
/// is false; a failed index build is passed to [failed].
void provideSearch(
  Dependencies dependencies, {
  required VerifiedPack pack,
  required bool Function() serving,
  required void Function(Exception error) failed,
}) => dependencies.provide<SearchRepository>(
  PackSearchRepository(
    pack: pack.manifest.id,
    build: SearchIndexService(pack).build,
    structure: dependencies.read<QuranStructure>(),
    serving: serving,
    onFailed: failed,
  ),
);

/// Provides the [TafsirSearchRepository] over the tafsir books [installed]
/// lists, every surah of the [QuranStructure] an earlier area provided. A
/// book that fails to read is passed to [failed].
void provideTafsirSearch(
  Dependencies dependencies, {
  required Future<List<VerifiedPack>> Function() installed,
  required void Function(Exception error) failed,
}) => dependencies.provide<TafsirSearchRepository>(
  PackTafsirSearchRepository(
    installed: installed,
    surahCount: dependencies.read<QuranStructure>().surahCount,
    onFailed: failed,
  ),
);
