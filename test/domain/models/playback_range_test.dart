import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_range.dart';

void main() {
  test('ayah ranges take ayah addresses only', () {
    final word = QuranAddress.parse('x:1:1:2');
    expect(() => SingleAyah(word), throwsArgumentError);
    expect(() => AyahSpan(QuranRange(word, word)), throwsArgumentError);
    expect(() => ToEndOfMushaf(word), throwsArgumentError);
    expect(() => FromAyahTool(word, AyahToolEnd.page), throwsArgumentError);
  });

  test('numbers start at 1 and pages run forward', () {
    expect(() => PageSpan(0), throwsRangeError);
    expect(() => PageSpan(3, 2), throwsArgumentError);
    expect(() => WholeSurah(0), throwsRangeError);
    expect(() => WholeJuz(0), throwsRangeError);
    expect(() => WholeHizb(0), throwsRangeError);
    expect(() => SurahSet(const [2, 0]), throwsRangeError);
  });

  test('one page is the current page', () {
    final page = PageSpan(7);
    expect((page.first, page.last), (7, 7));
  });

  test('a set of surahs is ordered and has no repeats', () {
    expect(SurahSet(const [5, 2, 5]).surahs, [2, 5]);
    expect(() => SurahSet(const []), throwsArgumentError);
  });
}
