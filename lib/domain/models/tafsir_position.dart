import 'quran_address.dart';
import 'tafsir_passage.dart';
import 'tafsir_surah_passage.dart';

/// An ayah as a tafsir book explains it (`TF-03`, `TF-04`): its passage, or
/// null when the book has none for it, and the ayat a step back and a step
/// forward lead to. A step passes over the rest of a passage's range, so that
/// a passage over several ayat is shown once, and lands on the first ayah of
/// the passage it reaches. Steps cross into the next or the previous surah
/// and are null at either end of the Quran.
///
/// Where a surah's tafsir begins, at the passage, or the ayah without one,
/// that starts at its first ayah, the position also carries the book's
/// passage on the surah as a whole, if it has one (D-184).
final class TafsirPosition {
  TafsirPosition({
    required this.ayah,
    required this.passage,
    required this.previous,
    required this.next,
    this.surahPassage,
  }) {
    if (ayah.isWord) {
      throw ArgumentError.value(ayah, 'ayah', 'is a word address');
    }
    if (passage case final passage? when !passage.range.contains(ayah)) {
      throw ArgumentError.value(passage.range, 'passage', 'misses $ayah');
    }
    if (previous case final previous? when previous.compareTo(ayah) >= 0) {
      throw ArgumentError.value(previous, 'previous', 'is not before $ayah');
    }
    if (next case final next? when next.compareTo(ayah) <= 0) {
      throw ArgumentError.value(next, 'next', 'is not after $ayah');
    }
    final after = passage?.number;
    if (surahPassage case final surahPassage?
        when surahPassage.surah != ayah.surah ||
            (passage?.range.start.ayah ?? ayah.ayah) != 1 ||
            (after != null && surahPassage.number >= after)) {
      throw ArgumentError.value(
        surahPassage.number,
        'surahPassage',
        'is not where the tafsir of surah ${ayah.surah} begins',
      );
    }
  }

  final QuranAddress ayah;
  final TafsirPassage? passage;
  final QuranAddress? previous;
  final QuranAddress? next;

  /// The passage on the surah of [ayah] as a whole; null away from where its
  /// tafsir begins, or when the book has none for it.
  final TafsirSurahPassage? surahPassage;
}
