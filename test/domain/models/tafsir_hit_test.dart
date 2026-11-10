import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_range.dart';
import 'package:holyquran/domain/models/search_hit.dart';
import 'package:holyquran/domain/models/search_match.dart';
import 'package:holyquran/domain/models/tafsir_passage.dart';
import 'package:holyquran/domain/models/tafsir_surah_passage.dart';

// Every text is synthetic.

void main() {
  const text = PackText.fromPack('Synthetic passage');
  const matches = [SearchMatch(start: 0, end: 9)];

  test('a hit in an ayah passage opens at the passage\'s first ayah', () {
    final passage = TafsirPassage(
      number: 4,
      range: QuranRange(QuranAddress('hafs', 2, 2), QuranAddress('hafs', 2, 3)),
      text: text,
    );
    final hit = TafsirHit(book: 'b', passage: passage, matches: matches);
    expect(hit.passage, same(passage));
    expect(hit.surahPassage, isNull);
    expect(hit.ayah, QuranAddress('hafs', 2, 2));
  });

  test('a hit in a passage on a surah as a whole opens at the surah\'s '
      'first ayah, with no ayah passage', () {
    final whole = TafsirSurahPassage(number: 3, surah: 2, text: text);
    final hit = TafsirHit.surahLevel(
      book: 'b',
      surahPassage: whole,
      riwaya: 'hafs',
      matches: matches,
    );
    expect(hit.surahPassage, same(whole));
    expect(hit.passage, isNull);
    expect(hit.ayah, QuranAddress('hafs', 2, 1));
    expect(hit.matches, matches);
  });

  test('either needs a match', () {
    final whole = TafsirSurahPassage(number: 1, surah: 1, text: text);
    expect(
      () => TafsirHit.surahLevel(
        book: 'b',
        surahPassage: whole,
        riwaya: 'hafs',
        matches: const [],
      ),
      throwsArgumentError,
    );
  });
}
