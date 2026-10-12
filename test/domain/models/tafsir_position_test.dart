import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_range.dart';
import 'package:holyquran/domain/models/tafsir_passage.dart';
import 'package:holyquran/domain/models/tafsir_position.dart';

QuranAddress _at(int surah, int ayah, [int? word]) =>
    QuranAddress('hafs', surah, ayah, word);

final _passage = TafsirPassage(
  number: 2,
  range: QuranRange(_at(2, 3), _at(2, 5)),
  text: const PackText.fromPack('Synthetic passage'),
);

void main() {
  test('keeps the ayah, its passage and its steps', () {
    final position = TafsirPosition(
      ayah: _at(2, 4),
      passage: _passage,
      previous: _at(2, 1),
      next: _at(2, 6),
    );

    expect(position.ayah, _at(2, 4));
    expect(position.passage, same(_passage));
    expect(position.previous, _at(2, 1));
    expect(position.next, _at(2, 6));
  });

  test('an ayah may have no passage and no steps', () {
    final position = TafsirPosition(
      ayah: _at(1, 1),
      passage: null,
      previous: null,
      next: null,
    );

    expect(position.passage, isNull);
    expect(position.previous, isNull);
    expect(position.next, isNull);
  });

  test('refuses a word, a passage elsewhere and steps the wrong way', () {
    TafsirPosition at(
      QuranAddress ayah, {
      TafsirPassage? passage,
      QuranAddress? previous,
      QuranAddress? next,
    }) => TafsirPosition(
      ayah: ayah,
      passage: passage,
      previous: previous,
      next: next,
    );

    expect(() => at(_at(2, 4, 1)), throwsArgumentError);
    expect(() => at(_at(2, 6), passage: _passage), throwsArgumentError);
    expect(() => at(_at(2, 4), previous: _at(2, 4)), throwsArgumentError);
    expect(() => at(_at(2, 4), previous: _at(3, 1)), throwsArgumentError);
    expect(() => at(_at(2, 4), next: _at(2, 4)), throwsArgumentError);
    expect(() => at(_at(2, 4), next: _at(1, 7)), throwsArgumentError);
  });
}
