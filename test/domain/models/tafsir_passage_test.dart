import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_range.dart';
import 'package:holyquran/domain/models/tafsir_passage.dart';

void main() {
  const text = PackText.fromPack('Synthetic passage');
  QuranRange range(int s1, int a1, int s2, int a2, [int? word]) => QuranRange(
    QuranAddress('hafs', s1, a1, word),
    QuranAddress('hafs', s2, a2, word),
  );

  test('holds its number, range and text', () {
    final passage = TafsirPassage(
      number: 2,
      range: range(1, 2, 1, 5),
      text: text,
    );
    expect(passage.number, 2);
    expect(passage.range, range(1, 2, 1, 5));
    expect(passage.text, same(text));
  });

  test('refuses a number below 1', () {
    expect(
      () => TafsirPassage(number: 0, range: range(1, 1, 1, 1), text: text),
      throwsArgumentError,
    );
  });

  test('refuses a range across surahs or of words', () {
    for (final given in [range(1, 7, 2, 1), range(1, 1, 1, 1, 1)]) {
      expect(
        () => TafsirPassage(number: 1, range: given, text: text),
        throwsArgumentError,
        reason: '$given',
      );
    }
  });
}
