import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/reader/block_layout.dart';
import 'package:holyquran/ui/core/reader/gesture_target.dart';
import 'package:holyquran/ui/core/reader/reader_style.dart';
import 'package:holyquran/ui/core/reader/reader_text_scale.dart';
import 'package:holyquran/ui/core/reader/surah_layout.dart';
import 'package:holyquran/ui/core/reader/surah_text.dart';
import 'package:holyquran/ui/core/reader/tap_resolver.dart';
import 'package:holyquran/ui/core/reader/target_geometry.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

import 'reader_fixture.dart';

// Hand-built geometry first, then the synthetic surahs (Arabic-script
// nonsense with pause marks) at the sizes the engine is tested at.

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
    _w(1): const Rect.fromLTRB(200, 10, 280, 55),
    _w(2): const Rect.fromLTRB(100, 10, 180, 55),
    _w(3): const Rect.fromLTRB(10, 10, 50, 55),
    _w(4): const Rect.fromLTRB(150, 62, 250, 98),
  },
  marks: {
    (_ayah, 1): const Rect.fromLTRB(186, 10, 192, 55),
    (_ayah, 2): const Rect.fromLTRB(100, 62, 106, 98),
  },
  markers: {_ayah: const Rect.fromLTRB(60, 20, 84, 44)},
);

GestureTarget _at(double x, double y, [TargetGeometry? g]) =>
    resolveTap(Offset(x, y), g ?? _g);

const _sizes = [
  (width: 360.0, system: 1.0, step: 1.0),
  (width: 360.0, system: 2.0, step: 1.0),
  (width: 320.0, system: 2.0, step: 2.0),
];

// The words of the synthetic pack are short; the real text keeps 90% of
// words at 18 px and above 91% of marks and markers (`docs/spikes/
// S7-gestures.md`, D-097). These are the shares the synthetic pack gives at
// 1.0x, held with a margin.
const _shareAt1x = {
  6: (word: 0.95, mark: 0.99, marker: 0.99),
  12: (word: 0.85, mark: 0.99, marker: 0.99),
  18: (word: 0.8, mark: 0.85, marker: 0.99),
};

SurahLayout _plan(
  ReaderFixture fixture,
  int surah, {
  double width = 360,
  double system = 1,
  double step = 1,
}) => SurahLayout.plan(
  fixture.surahs[surah]!,
  ReaderStyle(ReaderTextScaler(TextScaler.linear(system), step)),
  width,
);

List<BlockLayout> _blocks(SurahLayout plan) => [
  for (var b = 0; b < plan.blocks.length; b++)
    BlockLayout(plan, b, ink: AppColors.paper.quranInk),
];

Iterable<Offset> _around(Offset centre, double distance) sync* {
  for (var k = 0; k < 8; k++) {
    final angle = k * math.pi / 4;
    yield centre + Offset(math.cos(angle), math.sin(angle)) * distance;
  }
}

void main() {
  test('a rect is grown to the minimum target about its centre', () {
    expect(AppSizes.targetMin, 48);
    expect(
      tapZone(const Rect.fromLTRB(60, 20, 84, 44)),
      Rect.fromCenter(center: const Offset(72, 32), width: 48, height: 48),
    );
    const wide = Rect.fromLTRB(0, 0, 80, 60);
    expect(tapZone(wide), wide, reason: 'already larger');
  });

  test('a word, a mark and a marker resolve from their middles', () {
    expect(_at(240, 30), _word(1));
    expect(_at(189, 30), _mark);
    expect(_at(72, 32), _marker);
    expect(_at(103, 80), _lowMark);
  });

  test('the zones of marks and markers win past the slop of a word', () {
    expect(_at(166, 30), _word(2), reason: 'inside the slop of word 2');
    expect(_at(169, 30), _mark, reason: 'in the zone of the mark');
    expect(_at(164, 30), _word(2));
    expect(_at(49, 30), _marker, reason: 'in the zone of the marker');
    expect(_at(47, 30), _word(3), reason: 'out of the zone');
    expect(_at(125, 80), _lowMark, reason: 'in the zone of a 6 px mark');
  });

  test('past the zones the horizontally nearest target on the band', () {
    expect(_at(130, 80), _word(4), reason: '20 from word 4, 24 from the mark');
    expect(_at(5, 30), _word(3));
    expect(_at(295, 30), _word(1));
    expect(_at(240, 59.99), _word(1), reason: 'band 0 ends at 60');
    expect(_at(240, 60), _word(4), reason: 'band 1 starts at 60');
  });

  test('off the bands, or on a band with no target, the margin', () {
    expect(_at(240, 100), _margin, reason: 'bands end at 100');
    expect(_at(240, -1), _margin);
    final empty = TargetGeometry(
      lineBands: const [Rect.fromLTRB(0, 0, 300, 60)],
    );
    expect(_at(100, 30, empty), _margin);
  });

  test('a mark that starts its line resolves, with hand-built geometry', () {
    final g = TargetGeometry(
      lineBands: const [Rect.fromLTRB(0, 0, 300, 60)],
      words: {_w(1): const Rect.fromLTRB(100, 10, 280, 55)},
      marks: {(_ayah, 1): const Rect.fromLTRB(290, 10, 296, 55)},
    );
    expect(_at(293, 30, g), _mark);
    expect(_at(270, 30, g), _mark, reason: 'in the zone, inside the slop');
    expect(_at(250, 30, g), _word(1));
  });

  test('a marker ranks before a mark on a tie', () {
    final g = TargetGeometry(
      lineBands: const [Rect.fromLTRB(0, 0, 300, 60)],
      marks: {(_ayah, 1): const Rect.fromLTRB(140, 10, 160, 50)},
      markers: {_ayah: const Rect.fromLTRB(138, 10, 162, 50)},
    );
    expect(_at(150, 30, g), _marker);
  });

  group('on the synthetic surahs', () {
    late Directory root;
    late ReaderFixture fixture;

    setUpAll(() async {
      root = await Directory.systemTemp.createTemp('tap_resolver');
      fixture = await ReaderFixture.load(root);
    });
    tearDownAll(() async {
      fixture.close();
      await root.delete(recursive: true);
    });

    for (final size in _sizes) {
      final name = '${size.width}/${size.system}x/${size.step}';

      test('every word, mark and marker centre resolves to itself, $name', () {
        var marks = 0;
        for (final number in fixture.surahs.keys) {
          final plan = _plan(
            fixture,
            number,
            width: size.width,
            system: size.system,
            step: size.step,
          );
          for (final block in _blocks(plan)) {
            final g = TargetGeometry.of(block);
            final text = fixture.surahs[number]!;
            expect(g.markers, hasLength(block.ayat.length));
            expect(g.marks, hasLength(_markCount(text, block)));
            for (final MapEntry(:key, :value) in g.words.entries) {
              expect(resolveTap(value.center, g), WordTarget(key));
            }
            for (final MapEntry(key: (ayah, mark), :value) in g.marks.entries) {
              marks++;
              expect(resolveTap(value.center, g), WaqfMarkTarget(ayah, mark));
            }
            for (final MapEntry(:key, :value) in g.markers.entries) {
              expect(resolveTap(value.center, g), MarkerTarget(key));
            }
            block.dispose();
          }
        }
        expect(marks, greaterThan(0));
      });

      test('a mark or marker is tapped within 23 px of its centre, $name', () {
        final plan = _plan(
          fixture,
          longSurah,
          width: size.width,
          system: size.system,
          step: size.step,
        );
        var marksTried = 0;
        var markersTried = 0;
        for (final block in _blocks(plan)) {
          final g = TargetGeometry.of(block);
          for (final (rect, isMark) in [
            for (final rect in g.marks.values) (rect, true),
            for (final rect in g.markers.values) (rect, false),
          ]) {
            final zone = tapZone(rect);
            expect(zone.width, greaterThanOrEqualTo(48));
            expect(zone.height, greaterThanOrEqualTo(48));
            for (final side in [-23.0, 23.0]) {
              final p = rect.center + Offset(side, 0);
              if (g.words.values.any((w) => w.deflate(12).contains(p))) {
                continue;
              }
              isMark ? marksTried++ : markersTried++;
              expect(
                resolveTap(p, g),
                anyOf(isA<MarkerTarget>(), isA<WaqfMarkTarget>()),
                reason: '23 px from the centre, in the zone',
              );
            }
          }
          block.dispose();
        }
        expect(marksTried, greaterThan(0), reason: 'no mark was tapped');
        expect(markersTried, greaterThan(0), reason: 'no marker was tapped');
      });

      test('a mark next to the start of its line still resolves, $name', () {
        var tried = 0;
        for (final block in _blocks(
          _plan(
            fixture,
            longSurah,
            width: size.width,
            system: size.system,
            step: size.step,
          ),
        )) {
          final g = TargetGeometry.of(block);
          for (final MapEntry(key: (ayah, mark), :value) in g.marks.entries) {
            if (_targetsBefore(g, value).length > 1) continue;
            tried++;
            expect(resolveTap(value.center, g), WaqfMarkTarget(ayah, mark));
          }
          block.dispose();
        }
        expect(tried, greaterThan(0), reason: 'no mark is near a line start');
      });

      // No case for a mark that starts its line: the line breaker hangs a
      // mark on the word before it, so AyahUnits.of never yields one
      // (surah_layout_test); 'a mark that starts its line resolves, with
      // hand-built geometry' covers the rule.
    }

    test('taps 6, 12 and 18 px away keep their shares at 1.0x', () {
      final hits = <String, List<int>>{};
      void tally(String kind, int distance, bool hit) {
        final counts = hits.putIfAbsent('$kind$distance', () => [0, 0]);
        counts[1]++;
        if (hit) counts[0]++;
      }

      for (final block in _blocks(_plan(fixture, longSurah))) {
        final g = TargetGeometry.of(block);
        for (final distance in _shareAt1x.keys) {
          final d = distance.toDouble();
          for (final MapEntry(:key, :value) in g.words.entries) {
            for (final p in _around(value.center, d)) {
              tally('word', distance, resolveTap(p, g) == WordTarget(key));
            }
          }
          for (final MapEntry(key: (ayah, mark), :value) in g.marks.entries) {
            for (final p in _around(value.center, d)) {
              final hit = resolveTap(p, g) == WaqfMarkTarget(ayah, mark);
              tally('mark', distance, hit);
            }
          }
          for (final MapEntry(:key, :value) in g.markers.entries) {
            for (final p in _around(value.center, d)) {
              tally('marker', distance, resolveTap(p, g) == MarkerTarget(key));
            }
          }
        }
        block.dispose();
      }
      for (final MapEntry(key: distance, value: floors) in _shareAt1x.entries) {
        for (final (kind, floor) in [
          ('word', floors.word),
          ('mark', floors.mark),
          ('marker', floors.marker),
        ]) {
          final counts = hits['$kind$distance']!;
          expect(counts[1], greaterThan(0));
          expect(
            counts[0] / counts[1],
            greaterThanOrEqualTo(floor),
            reason: '$kind at $distance px',
          );
        }
      }
    });

    test('geometry within a point takes only the lines near it', () {
      final plan = _plan(fixture, longSurah);
      final block = _blocks(plan).first;
      final all = TargetGeometry.of(block);
      final y = plan.lineHeight * 3.5;
      final near = TargetGeometry.of(
        block,
        within: Rect.fromLTRB(0, y - 48, block.width, y + 48),
      );
      expect(near.lineBands.length, lessThan(all.lineBands.length));
      expect(near.words.length, lessThan(all.words.length));
      for (final MapEntry(:key, :value) in near.words.entries) {
        expect(all.words[key], value);
      }
      for (final rect in near.words.values) {
        expect(
          rect.center.dy,
          inInclusiveRange(
            near.lineBands.first.top,
            near.lineBands.last.bottom,
          ),
        );
      }
      block.dispose();
    });
  });
}

/// The rects on [rect]'s band that stand before it, towards the start of the
/// line (the right edge).
List<Rect> _targetsBefore(TargetGeometry g, Rect rect) {
  final band = g.lineBands[g.bandAt(rect.center.dy)!];
  return [
    for (final other in [
      ...g.words.values,
      ...g.markers.values,
      ...g.marks.values,
    ])
      if (other != rect &&
          other.center.dy >= band.top &&
          other.center.dy < band.bottom &&
          other.center.dx > rect.center.dx)
        other,
  ];
}

int _markCount(SurahText text, BlockLayout block) =>
    [for (final a in block.ayat) ...text.ayat[a - 1].marks].length;
