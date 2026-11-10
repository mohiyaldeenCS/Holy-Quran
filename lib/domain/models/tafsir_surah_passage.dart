import 'pack_text.dart';

/// A tafsir book's commentary on surah [surah] as a whole, linked to none of
/// its ayat (D-184). A surah has at most one, shown where its tafsir begins,
/// before its first ayah passage. It has no ayah range: no address of it is
/// ever made.
final class TafsirSurahPassage {
  TafsirSurahPassage({
    required this.number,
    required this.surah,
    required this.text,
  }) {
    if (number < 1) {
      throw ArgumentError.value(number, 'number', 'is not positive');
    }
    if (surah < 1) {
      throw ArgumentError.value(surah, 'surah', 'is not positive');
    }
  }

  /// Its place in the book, from 1, in mushaf order: one below that of its
  /// surah's first ayah passage.
  final int number;
  final int surah;
  final PackText text;
}
