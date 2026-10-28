import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/repositories/tafsir_repository.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/tafsir_book.dart';
import 'package:holyquran/domain/models/tafsir_passage.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/features/tafsir/tafsir_source.dart';
import 'package:holyquran/utils/result.dart';

/// The text a tafsir passage is copied as (`TF-10`): the passage with its
/// attribution, read from the packs by address at the moment of copying,
/// never from what a widget shows.
///
/// A pack-text sink of D-114: the passage, the book's title and author and
/// the surah's name enter the ARB format whole and unchanged.
final class TafsirCopyText {
  const TafsirCopyText({
    required this.tafsirs,
    required this.quran,
    required this.l10n,
  });

  final TafsirRepository tafsirs;
  final QuranTextRepository quran;
  final AppLocalizations l10n;

  /// The passage of book [packId] over [ayah], with the book's attribution.
  /// Fails with [NoPassageToCopy] when the book has none for the ayah.
  Future<Result<String>> compose(String packId, QuranAddress ayah) async {
    final TafsirPassage passage;
    switch (await tafsirs.positionAt(packId, ayah.ayahAddress)) {
      case Ok(value: final position):
        final found = position.passage;
        if (found == null) return Failure(NoPassageToCopy(ayah.ayahAddress));
        passage = found;
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
    final PackText surahName;
    switch (await _surahName(passage.range.start.surah)) {
      case Ok(:final value):
        surahName = value;
      case Failure(:final error):
        return Failure(error);
    }
    final pack = tafsirs.installed
        .where((pack) => pack.id == packId)
        .firstOrNull;
    if (pack == null) return Failure(TafsirNotInstalled(packId));
    final first = passage.range.start.ayah;
    final last = passage.range.end.ayah;
    return Ok(
      l10n.tafsirCopyFormat(
        passage.text.verbatim,
        book.title.verbatim,
        book.author.verbatim,
        surahName.verbatim,
        first == last
            ? arabicDigits(first)
            : l10n.ayahsRangeShort(arabicDigits(first), arabicDigits(last)),
        digitisationSourceOf(pack)?.name ?? '',
        arabicDigits(pack.version),
      ),
    );
  }

  Future<Result<PackText>> _surahName(int surah) async {
    switch (await quran.surahs()) {
      case Ok(value: final surahs):
        for (final info in surahs) {
          if (info.number == surah) return Ok(info.name);
        }
        return Failure(
          AddressNotInPack(quran.riwaya, QuranAddress(quran.riwaya, surah, 1)),
        );
      case Failure(:final error):
        return Failure(error);
    }
  }
}

/// The book has no passage for the ayah, so there is nothing to copy.
final class NoPassageToCopy implements Exception {
  const NoPassageToCopy(this.ayah);

  final QuranAddress ayah;

  @override
  String toString() => 'NoPassageToCopy($ayah)';
}
