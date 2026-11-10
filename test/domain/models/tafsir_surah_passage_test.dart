import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/tafsir_surah_passage.dart';

void main() {
  const text = PackText.fromPack('Synthetic surah-level passage');

  test('holds its number, surah and text', () {
    final passage = TafsirSurahPassage(number: 3, surah: 2, text: text);
    expect(passage.number, 3);
    expect(passage.surah, 2);
    expect(passage.text, same(text));
  });

  test('refuses a number or a surah below 1', () {
    expect(
      () => TafsirSurahPassage(number: 0, surah: 1, text: text),
      throwsArgumentError,
    );
    expect(
      () => TafsirSurahPassage(number: 1, surah: 0, text: text),
      throwsArgumentError,
    );
  });
}
