import 'package:holyquran/data/repositories/tafsir_repository.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/tafsir_book.dart';
import 'package:holyquran/domain/models/tafsir_position.dart';
import 'package:holyquran/ui/core/tafsir/tafsir_page.dart';
import 'package:holyquran/ui/core/tafsir/tafsir_source.dart';
import 'package:holyquran/utils/result.dart';

/// The id of the book shown: the default tafsir, or the first installed one
/// while none is chosen (`TF-01`); null when none is installed.
String? shownTafsirPack(TafsirRepository tafsirs) =>
    tafsirs.defaultTafsir ?? tafsirs.installed.firstOrNull?.id;

/// Ayah [ayah] as book [packId] explains it, with the facts of its source
/// badge (`TF-05`). A pack that fails its checks, or is no longer installed,
/// fails.
Future<Result<TafsirPage>> readTafsirPage(
  TafsirRepository tafsirs,
  String packId,
  QuranAddress ayah,
) async {
  final TafsirPosition position;
  switch (await tafsirs.positionAt(packId, ayah)) {
    case Ok(:final value):
      position = value;
    case Failure(:final error):
      return Failure(error);
  }
  final TafsirBook book;
  switch (await tafsirs.book(packId)) {
    case Ok(:final value):
      book = value;
    case Failure(:final error):
      return Failure(error);
  }
  final pack = installedTafsirOf(tafsirs, packId);
  if (pack == null) return Failure(TafsirNotInstalled(packId));
  return Ok(
    TafsirPage(
      packId: packId,
      position: position,
      book: book,
      source: digitisationSourceOf(pack).name,
      version: pack.version,
    ),
  );
}
