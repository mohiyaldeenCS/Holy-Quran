import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';

import '../s1/render/render_checks.dart';
import '../s1/render/spike_surah_text.dart';
import '../s1/render/synthetic_surah_pack.dart';
import 'gesture_target.dart';
import 'tap_resolver.dart';
import 'target_geometry.dart';

// Hand-built geometry first, then the marked synthetic surah (D-083),
// Arabic-script nonsense read through the app's text repository.

final _ayah = QuranAddress('hafs', 1, 1);
QuranAddress _w(int n) => QuranAddress('hafs', 1, 1, n);

WordTarget _word(int n) => WordTarget(_w(n));
final _mark = WaqfMarkTarget(_ayah, 1);
final _lowMark = WaqfMarkTarget(_ayah, 2);
final _marker = MarkerTarget(_ayah);
const _margin = MarginTarget();

/// Band 0 is 60 tall, band 1 only 40. Right to left on band 0: word 1, a
/// 6 px mark between gaps of 6 and 8, word 2, the 24 px marker, word 3.
/// Band 1 holds word 4 and a second 6 px mark.
final _g = TargetGeometry(
  lineBands: const [
    Rect.fromLTRB(0, 0, 300, 60),
    Rect.fromLTRB(0, 60, 300, 100),
  ],
  words: {
    _w(1): const [Rect.fromLTRB(200, 10, 280, 55)],
    _w(2): const [Rect.fromLTRB(100, 10, 180, 55)],
    _w(3): const [Rect.fromLTRB(10, 10, 50, 55)],
    _w(4): const [Rect.fromLTRB(150, 62, 250, 98)],
  },
  marks: {
    (_ayah, 1): const Rect.fromLTRB(186, 10, 192, 55),
    (_ayah, 2): const Rect.fromLTRB(100, 62, 106, 98),
  },
  markers: {_ayah: const Rect.fromLTRB(60, 20, 84, 44)},
);

GestureTarget _at(
  double x,
  double y,
  TapRule rule, {
  double minTarget = 48,
  TargetGeometry? g,
}) => resolveTap(Offset(x, y), g ?? _g, rule, minTarget: minTarget);

SpikeSurahText _first(SpikeSurahText surah, int ayat) => SpikeSurahText(
  firstAyah: surah.firstAyah,
  ayat: surah.ayat.sublist(0, ayat),
  words: surah.words.sublist(0, ayat),
  marks: surah.marks.sublist(0, ayat),
  basmala: surah.basmala,
  pageStarts: {
    for (final MapEntry(:key, :value) in surah.pageStarts.entries)
      if (key.ayah <= ayat) key: value,
  },
);

void main() {
  test('exact: the rect holding the point, else the margin', () {
    const rule = TapRule.exact;
    expect(_at(240, 30, rule), _word(1));
    expect(_at(189, 30, rule), _mark);
    expect(_at(183, 30, rule), _margin, reason: 'a gap');
    expect(_at(195, 30, rule), _margin, reason: 'a gap');
    expect(_at(72, 30, rule), _marker);
    expect(_at(5, 30, rule), _margin);
    expect(_at(240, 57, rule), _margin, reason: 'below the word, on its band');
    expect(_at(240, 105, rule), _margin, reason: 'off the bands');
    expect(_at(103, 80, rule), _lowMark);
  });

  test('exact ranks marker, mark, word where rects overlap', () {
    final g = TargetGeometry(
      lineBands: const [Rect.fromLTRB(0, 0, 300, 60)],
      words: {
        _w(1): const [Rect.fromLTRB(0, 0, 300, 60)],
      },
      marks: {(_ayah, 1): const Rect.fromLTRB(100, 0, 200, 60)},
      markers: {_ayah: const Rect.fromLTRB(140, 0, 160, 60)},
    );
    expect(_at(150, 30, TapRule.exact, g: g), _marker);
    expect(_at(120, 30, TapRule.exact, g: g), _mark);
    expect(_at(50, 30, TapRule.exact, g: g), _word(1));
  });

  test('nearestOnLine: the horizontally nearest target on the point\'s '
      'band, the margin off the bands or on an empty one', () {
    const rule = TapRule.nearestOnLine;
    expect(_at(182, 30, rule), _word(2), reason: '2 from word 2, 4 from mark');
    expect(_at(195, 30, rule), _mark, reason: '3 from the mark, 5 from word 1');
    expect(_at(183, 30, rule), _mark, reason: 'a tie goes to the mark');
    expect(_at(5, 30, rule), _word(3));
    expect(_at(290, 30, rule), _word(1));
    expect(_at(92, 30, rule), _marker);
    expect(_at(240, 59.99, rule), _word(1), reason: 'band 0 ends at 60');
    expect(_at(240, 60, rule), _word(4), reason: 'band 1 starts at 60');
    expect(_at(295, 80, rule), _word(4));
    expect(_at(120, 80, rule), _lowMark);
    expect(_at(240, 100, rule), _margin, reason: 'bands end at 100');
    expect(_at(240, -1, rule), _margin);
    final empty = TargetGeometry(
      lineBands: const [Rect.fromLTRB(0, 0, 300, 60)],
    );
    expect(_at(100, 30, rule, g: empty), _margin);
  });

  test('priorityZones: marker and mark zones first, grown to the minimum '
      'target about their centres, then nearestOnLine', () {
    const rule = TapRule.priorityZones;
    expect(_at(170, 30, rule), _mark, reason: 'inside word 2, in the zone');
    expect(_at(164, 30, rule), _word(2), reason: 'the zone ends at 165');
    expect(_at(49, 30, rule), _marker, reason: 'inside word 3, in the zone');
    expect(_at(240, 30, rule), _word(1));
    expect(_at(175, 9, rule), _mark, reason: '48 tall: 8.5 to 56.5');
    expect(_at(175, 8, rule), _word(2), reason: 'above the zone');
    expect(
      _at(103, 58, rule),
      _lowMark,
      reason:
          'a band under 48: the zone '
          'reaches into band 0',
    );
    expect(_at(103, 103, rule), _lowMark, reason: 'and off the bands');
    expect(_at(103, 105, rule), _margin);
  });

  test('priorityZones: of overlapping zones the nearest centre wins, a tie '
      'going to the marker', () {
    final g = TargetGeometry(
      lineBands: const [Rect.fromLTRB(0, 0, 300, 60)],
      marks: {(_ayah, 1): const Rect.fromLTRB(127, 10, 133, 50)},
      markers: {_ayah: const Rect.fromLTRB(88, 18, 112, 42)},
    );
    const rule = TapRule.priorityZones;
    expect(_at(114, 30, rule, g: g), _marker);
    expect(_at(116, 30, rule, g: g), _mark);
    expect(_at(115, 30, rule, g: g), _marker);
  });

  test('priorityZones follows minTarget', () {
    const rule = TapRule.priorityZones;
    expect(_at(167, 30, rule, minTarget: 40), _word(2), reason: '169 to 209');
    expect(_at(167, 30, rule), _mark, reason: '165 to 213');
    expect(_at(163, 30, rule, minTarget: 56), _mark, reason: '161 to 217');
    expect(_at(160, 30, rule, minTarget: 56), _word(2));
  });

  test('priorityZonesWithSlop: a point more than minTarget / 4 inside both '
      'side edges of a word is that word', () {
    const rule = TapRule.priorityZonesWithSlop;
    expect(_at(167, 30, rule), _word(2), reason: '13 inside the right edge');
    expect(_at(169, 30, rule), _mark, reason: '11 inside: the zone');
    expect(_at(168, 30, rule), _mark, reason: '12 is not more than 12');
    expect(_at(167, 30, TapRule.priorityZones), _mark);
    expect(_at(49, 30, rule), _marker, reason: 'word 3 is 1 from its edge');
    expect(
      _at(171, 30, rule, minTarget: 40),
      _mark,
      reason: '9 inside, not more than 10',
    );
    expect(_at(169, 30, rule, minTarget: 40), _word(2), reason: '11 > 10');
    expect(_at(103, 58, rule), _lowMark, reason: 'word 2 ends above');
    expect(_at(240, 100, rule), _margin);
  });

  group('the marked surah', () {
    late Directory root;
    late SpikeSurahText long;

    setUpAll(() async {
      root = await Directory.systemTemp.createTemp('s7_resolver');
      final read = await readSyntheticSurahs(root, withMarks: true);
      long = _first(read.long, 80);
      read.pack.close();
    });
    tearDownAll(() => root.delete(recursive: true));

    for (final scale in [1.0, 2.0]) {
      test('every target\'s centre resolves to it at 360, ${scale}x, and '
          'nearestOnLine finds a target all along every band', () {
        final paragraph = surahParagraph(
          long,
          width: 360,
          textScaler: TextScaler.linear(scale),
          pageMarkSize: const Size(30, 20),
        );
        addTearDown(paragraph.dispose);
        final g = TargetGeometry.of(paragraph);
        var words = 0;
        final noWidth = <String>[];
        for (final MapEntry(key: word, value: rects) in g.words.entries) {
          for (final rect in rects) {
            if (rect.width <= 0) {
              noWidth.add('$word');
              continue;
            }
            words++;
            for (final rule in [TapRule.exact, TapRule.nearestOnLine]) {
              expect(
                resolveTap(rect.center, g, rule),
                WordTarget(word),
                reason: '$word, ${rule.name}',
              );
            }
          }
        }
        final marks = <(Offset, GestureTarget)>[
          for (final MapEntry(key: (ayah, mark), value: rect)
              in g.marks.entries)
            (rect.center, WaqfMarkTarget(ayah, mark)),
          for (final MapEntry(key: ayah, value: rect) in g.markers.entries)
            (rect.center, MarkerTarget(ayah)),
        ];
        for (final (centre, target) in marks) {
          for (final rule in TapRule.values) {
            expect(resolveTap(centre, g, rule), target, reason: rule.name);
          }
        }
        var probes = 0;
        for (final band in g.lineBands) {
          for (var x = 0.0; x <= 360; x += 6) {
            for (final y in [band.top, band.center.dy, band.bottom - 0.01]) {
              probes++;
              expect(
                resolveTap(Offset(x, y), g, TapRule.nearestOnLine),
                isNot(const MarginTarget()),
              );
            }
          }
        }

        final times = <int>[];
        final clock = Stopwatch();
        final rules = <TapRule, List<int>>{};
        for (final band in g.lineBands) {
          for (final x in [30.0, 180.0, 330.0]) {
            final p = Offset(x, band.center.dy);
            for (final rule in TapRule.values) {
              clock
                ..reset()
                ..start();
              final within = TargetGeometry.of(
                paragraph,
                within: Rect.fromLTRB(0, p.dy - 48, 360, p.dy + 48),
              );
              resolveTap(p, within, rule);
              clock.stop();
              times.add(clock.elapsedMicroseconds);
              (rules[rule] ??= []).add(clock.elapsedMicroseconds);
            }
          }
        }
        int median(List<int> values) => (values..sort())[values.length ~/ 2];
        // ignore: avoid_print
        print(
          'resolver at 360, ${scale}x: $words word rects, '
          '${noWidth.length} of no width $noWidth (boxes outside the block, '
          'clamped to nothing), ${g.marks.length} marks, '
          '${g.markers.length} markers, '
          '$probes band probes; median resolution (geometry within 48 px '
          'and rule) ${median(times)} us, by rule '
          '${{for (final e in rules.entries) e.key.name: median(e.value)}}',
        );
        expect(words, greaterThan(500));
      });
    }
  });
}
