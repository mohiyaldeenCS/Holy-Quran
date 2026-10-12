import 'quran_address.dart';
import 'tafsir_passage.dart';

/// An ayah as a tafsir book explains it (`TF-03`, `TF-04`): its passage, or
/// null when the book has none for it, and the ayat a step back and a step
/// forward lead to. A step passes over the rest of a passage's range, so that
/// a passage over several ayat is shown once, and lands on the first ayah of
/// the passage it reaches. Steps cross into the next or the previous surah
/// and are null at either end of the Quran.
final class TafsirPosition {
  TafsirPosition({
    required this.ayah,
    required this.passage,
    required this.previous,
    required this.next,
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
  }

  final QuranAddress ayah;
  final TafsirPassage? passage;
  final QuranAddress? previous;
  final QuranAddress? next;
}
