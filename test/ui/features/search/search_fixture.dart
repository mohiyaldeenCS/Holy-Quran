import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_range.dart';
import 'package:holyquran/domain/models/search_hit.dart';
import 'package:holyquran/domain/use_cases/parse_direct_jump.dart';

import '../index/index_fixture.dart';

/// The words a direct jump recognises, in plain ASCII: the tests spell the
/// interface's words with these, so no Arabic is typed here.
const jumpWords = DirectJumpWords(
  surah: 'surah',
  page: 'page',
  juz: 'juz',
  hizb: 'hizb',
  rub: 'rub',
);

/// The query the fakes answer.
const query = 'alpha';

/// A hit on [ranges], pairs of first and last word, of ayah [ayah] of surah
/// [surah] in the fixture's pack; words [first] to [last] when none are given.
SearchHit hit(
  IndexFixture fixture,
  int surah,
  int ayah, {
  int first = 2,
  int last = 3,
  bool exact = true,
  int gaps = 0,
  List<(int, int)>? ranges,
}) {
  QuranRange range(int from, int to) => QuranRange(
    QuranAddress(fixture.index.riwaya, surah, ayah, from),
    QuranAddress(fixture.index.riwaya, surah, ayah, to),
  );
  return SearchHit(
    ayah: QuranAddress(fixture.index.riwaya, surah, ayah),
    matches: [
      for (final (from, to) in ranges ?? [(first, last)]) range(from, to),
    ],
    exact: exact,
    gaps: gaps,
  );
}
