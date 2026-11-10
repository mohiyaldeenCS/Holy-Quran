import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_range.dart';
import 'package:holyquran/domain/models/tafsir_passage.dart';
import 'package:holyquran/domain/models/tafsir_position.dart';
import 'package:holyquran/domain/models/tafsir_surah_passage.dart';

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

  group('the passage on the whole surah', () {
    TafsirSurahPassage whole(int number, int surah) => TafsirSurahPassage(
      number: number,
      surah: surah,
      text: const PackText.fromPack('Synthetic surah-level passage'),
    );
    final first = TafsirPassage(
      number: 4,
      range: QuranRange(_at(2, 1), _at(2, 2)),
      text: const PackText.fromPack('Synthetic passage'),
    );
    TafsirPosition at(
      QuranAddress ayah,
      TafsirSurahPassage surahPassage, {
      TafsirPassage? passage,
    }) => TafsirPosition(
      ayah: ayah,
      passage: passage,
      previous: null,
      next: null,
      surahPassage: surahPassage,
    );

    test('is none unless given', () {
      expect(
        TafsirPosition(
          ayah: _at(2, 1),
          passage: first,
          previous: null,
          next: null,
        ).surahPassage,
        isNull,
      );
    });

    test('is kept where the tafsir of its surah begins', () {
      final surahPassage = whole(3, 2);
      expect(
        at(_at(2, 2), surahPassage, passage: first).surahPassage,
        same(surahPassage),
      );
      expect(at(_at(2, 1), surahPassage).surahPassage, same(surahPassage));
    });

    test('is refused elsewhere, on another surah or numbered after', () {
      expect(
        () => at(_at(2, 4), whole(1, 2), passage: _passage),
        throwsArgumentError,
      );
      expect(() => at(_at(2, 2), whole(1, 2)), throwsArgumentError);
      expect(() => at(_at(2, 1), whole(1, 1)), throwsArgumentError);
      expect(
        () => at(_at(2, 1), whole(4, 2), passage: first),
        throwsArgumentError,
      );
    });
  });
}
