import 'pack_text.dart';
import 'quran_range.dart';

/// A passage of a tafsir book and the ayat it explains, shown once for its
/// whole range (`TF-04`). The range lies within one surah.
final class TafsirPassage {
  TafsirPassage({
    required this.number,
    required this.range,
    required this.text,
  }) {
    if (number < 1) {
      throw ArgumentError.value(number, 'number', 'is not positive');
    }
    if (range.start.isWord || range.start.surah != range.end.surah) {
      throw ArgumentError.value(range, 'range', 'is not ayat of one surah');
    }
  }

  /// Its place in the book, from 1, in mushaf order.
  final int number;
  final QuranRange range;
  final PackText text;
}
