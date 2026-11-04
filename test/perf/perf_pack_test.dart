import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/perf/perf_pack.dart';

void main() {
  final surahs = perfSurahs(PerfPackSize.full);

  test('the full pack has the real edition counts of surahs and divisions', () {
    expect(surahs, hasLength(114));
    final divisions = perfDivisions(surahs);
    int count(String kind) => divisions.where((d) => d.kind == kind).length;
    expect(count('juz'), 30);
    expect(count('hizb'), 60);
    expect(count('rub'), 240);
    expect(count('page'), 604);
  });

  test('the longest surah has about the real number of words', () {
    final words = surahs[perfLongSurah - 1].ayat.fold<int>(
      0,
      (sum, a) => sum + a.spans.length,
    );

    expect(words, inInclusiveRange(5500, 6700));
  });

  test('the full pack is of the real size, in ayat and in words', () {
    final ayat = surahs.fold<int>(0, (sum, s) => sum + s.ayat.length);
    final words = surahs.fold<int>(
      0,
      (sum, s) => sum + s.ayat.fold<int>(0, (n, a) => n + a.spans.length),
    );

    expect(ayat, inInclusiveRange(6000, 6500));
    expect(words, inInclusiveRange(65000, 90000));
  });

  test(
    'the longest surah is the one the harness scrolls, and has 286 ayat',
    () {
      final longest = surahs.reduce(
        (a, b) => a.ayat.length >= b.ayat.length ? a : b,
      );

      expect(surahs.indexOf(longest) + 1, perfLongSurah);
      expect(longest.ayat, hasLength(286));
    },
  );

  test('every division starts at an ayah of the pack, in mushaf order', () {
    for (final size in PerfPackSize.values) {
      final pack = perfSurahs(size);
      final divisions = perfDivisions(pack);
      for (final kind in ['juz', 'hizb', 'rub', 'page']) {
        final starts = [
          for (final d in divisions)
            if (d.kind == kind) d,
        ];
        for (final d in starts) {
          expect(d.ayah, inInclusiveRange(1, pack[d.surah - 1].ayat.length));
        }
        for (var i = 1; i < starts.length; i++) {
          final before = starts[i - 1];
          final after = starts[i];
          // No surah has a thousand ayat.
          expect(
            after.surah * 1000 + after.ayah,
            greaterThan(before.surah * 1000 + before.ayah),
            reason: '$kind ${after.number}',
          );
        }
      }
    }
  });

  test('the text is made of the six synthetic words, the three pause marks '
      'and nothing else, in every ayah and basmala of the full pack', () {
    const synthetic = {
      '\u{646}\u{635}',
      '\u{62A}\u{62C}\u{631}\u{64A}\u{628}\u{64A}',
      '\u{643}\u{644}\u{645}',
      '\u{633}\u{637}\u{631}',
      '\u{645}\u{62B}\u{627}\u{644}',
      '\u{639}\u{64A}\u{646}\u{629}',
      '\u{6D6}',
      '\u{6D7}',
      '\u{6DA}',
      // The basmala field's own word.
      '\u{627}\u{641}\u{62A}\u{62A}\u{627}\u{62D}',
    };
    final seen = <String>{};
    void check(String text) {
      for (final token in text.split(' ')) {
        expect(synthetic, contains(token));
        seen.add(token);
      }
    }

    for (final surah in surahs) {
      for (final ayah in surah.ayat) {
        check(ayah.text);
      }
      if (surah.basmala case final basmala?) check(basmala);
      expect(surah.name, startsWith('Synthetic '));
    }

    expect(seen, synthetic, reason: 'every token of the set is used');
  });
}
