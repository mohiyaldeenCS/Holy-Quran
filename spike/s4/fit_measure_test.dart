import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../s1/render/spike_surah_text.dart';
import '../s1/render/synthetic_surah_pack.dart';
import 'ayah_widget_face.dart';
import 'fit_measure.dart';
import 'widget_fit.dart';
import 'widget_publisher.dart' show faceSizeOf;
import 'widget_slots.dart';

// S4's fit counts over the synthetic pack's nonsense: both surahs, every
// ayah at the 4x2 and the 2x2 face. Results hold numbers and addresses only.

Map<String, Object?> _map(Object? value) => value! as Map<String, Object?>;

/// Whether [text] holds a code point of the Arabic blocks.
bool _hasArabic(String text) => text.runes.any(
  (c) =>
      (c >= 0x0600 && c <= 0x06FF) ||
      (c >= 0x0750 && c <= 0x077F) ||
      (c >= 0x08A0 && c <= 0x08FF) ||
      (c >= 0xFB50 && c <= 0xFDFF) ||
      (c >= 0xFE70 && c <= 0xFEFF),
);

const _sizes = ['28', '27', '26', '25', '24', '23', '22', 'none'];

void main() {
  late Directory root;
  late List<SpikeSurahText> surahs;
  late FitMeasurement measurement;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('s4_fit_measure');
    final read = await readSyntheticSurahs(root, withMarks: true);
    surahs = [read.long, read.short];
    read.pack.close();
    measurement = FitMeasurement()..run(surahs);
  });
  tearDownAll(() => root.delete(recursive: true));

  test('the counts account for every ayah at both faces, per surah and in '
      'all', () {
    final results = measurement.results;
    final total = _map(results['total']);
    final ayat = surahs.fold(0, (n, s) => n + s.ayat.length);
    expect(total['ayat'], ayat);
    final perSurah = results['surahs']! as List<Object?>;
    expect(perSurah, hasLength(2));
    for (final counts in [total, ...perSurah.map(_map)]) {
      final n = counts['ayat']! as int;
      for (final face in ['medium', 'small']) {
        final bySize = _map(counts[face]);
        expect(bySize.keys, _sizes);
        expect(bySize.values.fold(0, (s, v) => s + (v! as int)), n);
      }
      expect(
        [
          'both',
          'mediumOnly',
          'smallOnly',
          'neither',
        ].fold(0, (s, k) => s + (counts[k]! as int)),
        n,
      );
    }
    for (final kind in FitProblem.values) {
      expect(measurement.problems[kind], isEmpty, reason: '$kind');
    }
    // Each face fits some nonsense and skips some.
    for (final face in ['medium', 'small']) {
      expect(
        _map(total[face])['none'],
        inExclusiveRange(0, ayat),
        reason: face,
      );
    }
  });

  test('each size is fitQuranSize called directly', () {
    final medium = AyahWidgetFace.ayahBoxOf(faceSizeOf(WidgetFaceSize.medium));
    final small = AyahWidgetFace.ayahBoxOf(faceSizeOf(WidgetFaceSize.small));
    final perSurah = measurement.results['surahs']! as List<Object?>;
    for (final (s, surah) in surahs.indexed) {
      final fits = _map(perSurah[s])['fits']! as List<Object?>;
      expect(fits, hasLength(surah.ayat.length));
      for (final (i, ayah) in surah.ayat.indexed) {
        expect(fits[i], [
          fitQuranSize(ayah, medium),
          fitQuranSize(ayah, small),
        ], reason: '${surah.firstAyah.surah}:${i + 1}');
      }
    }
  });

  test('the results and the summary hold numbers only', () {
    final json = jsonEncode(measurement.results);
    final summary = fitSummaryLines(measurement.results);
    expect(_hasArabic(json), isFalse);
    expect(summary.where(_hasArabic), isEmpty);
    expect(fitProblems(jsonDecode(json) as Map<String, Object?>), {
      FitProblem.counts: isEmpty,
      FitProblem.monotone: isEmpty,
    });
    for (final line in summary) {
      // ignore: avoid_print
      print('s4 synthetic: $line');
    }
  });

  test('counts and monotone problems fire on fabricated results', () {
    final results =
        jsonDecode(jsonEncode(measurement.results)) as Map<String, Object?>;
    final short = _map((results['surahs']! as List<Object?>)[1]);
    final fits = short['fits']! as List<Object?>;
    fits[0] = [null, 22];
    fits[1] = [24, 26];
    _map(short['small'])['28'] = (_map(short['small'])['28']! as int) + 1;
    _map(results['total'])['neither'] =
        (_map(results['total'])['neither']! as int) - 1;
    final problems = fitProblems(results);
    expect(problems[FitProblem.monotone], [
      'surah 2:1 4x2 null, 2x2 22',
      'surah 2:2 4x2 24, 2x2 26',
    ]);
    final ayat = _map(results['total'])['ayat']! as int;
    expect(problems[FitProblem.counts], [
      'total pairs: ${ayat - 1} of $ayat',
      'surah 2 small: 7 of 6',
    ]);
  });
}
