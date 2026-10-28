import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/ui/core/reader/block_layout.dart';
import 'package:holyquran/ui/core/reader/pinch_step.dart';
import 'package:holyquran/ui/core/reader/reader_style.dart';
import 'package:holyquran/ui/core/reader/reader_text_scale.dart';
import 'package:holyquran/ui/core/reader/surah_layout.dart';
import 'package:holyquran/ui/core/reader/target_geometry.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

import 'reader_fixture.dart';

SurahLayout _plan(ReaderFixture fixture, double step, [double width = 360]) =>
    SurahLayout.plan(
      fixture.surahs[longSurah]!,
      ReaderStyle(ReaderTextScaler(const TextScaler.linear(1), step)),
      width,
    );

void main() {
  late Directory root;
  late ReaderFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('pinch_step');
    fixture = await ReaderFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  group('a pinch steps through the ladder', () {
    final at100 = defaultReaderTextStep;

    test('to the step nearest the size times the scale', () {
      expect(readerTextSteps[stepAfterPinch(at100, 1.5)], 1.5);
      expect(readerTextSteps[stepAfterPinch(at100, 0.8)], 0.8);
      expect(readerTextSteps[stepAfterPinch(at100, 1.14)], 1.15);
      expect(stepAfterPinch(at100, 1), at100);
    });

    test('judged on a log scale, as S7 did', () {
      // The midpoint of two steps is their geometric mean: between 1.75 and
      // 2.0 it is sqrt(3.5), 1.8708, below the arithmetic 1.875.
      final at175 = readerTextSteps.indexOf(1.75);
      expect(readerTextSteps[stepAfterPinch(at175, 1.07)], 2.0);
      expect(readerTextSteps[stepAfterPinch(at175, 1.06)], 1.75);
      // Between 0.8 and 0.9: sqrt(0.72), 0.8485, below the arithmetic 0.85.
      expect(readerTextSteps[stepAfterPinch(at100, 0.8495)], 0.9);
      expect(readerTextSteps[stepAfterPinch(at100, 0.8475)], 0.8);
    });

    test('and stops at both ends', () {
      expect(stepAfterPinch(at100, 9), readerTextSteps.length - 1);
      expect(stepAfterPinch(at100, 0.1), 0);
      expect(
        stepAfterPinch(readerTextSteps.length - 1, 2),
        readerTextSteps.length - 1,
      );
      expect(stepAfterPinch(0, 0.5), 0);
    });

    test('from any step, a scale of one stays', () {
      for (var k = 0; k < readerTextSteps.length; k++) {
        expect(stepAfterPinch(k, 1), k);
      }
    });
  });

  group('the focal ayah stays in place', () {
    test('an ayah and the fraction of its lines under the point', () {
      final plan = _plan(fixture, 1);
      final top =
          plan.basmalaExtent + plan.lineOfAyahText(20) * plan.lineHeight;
      final bottom =
          plan.basmalaExtent + (plan.lineOfAyahEnd(20) + 1) * plan.lineHeight;
      final focal = focalAyahOfLine(plan, (top + bottom) / 2);
      expect(focal.ayah, 20);
      expect(focal.fraction, closeTo(0.5, 1e-9));
      expect(yOfFocalAyah(plan, focal), closeTo((top + bottom) / 2, 1e-9));
    });

    test('at another step the same point of the same ayah', () {
      final small = _plan(fixture, 1);
      final large = _plan(fixture, 2);
      expect(large.lineHeight, greaterThan(small.lineHeight));
      for (final ayah in [3, 12, 20, longSurahAyat]) {
        final top =
            small.basmalaExtent + small.lineOfAyahText(ayah) * small.lineHeight;
        final focal = focalAyahOfLine(small, top + small.lineHeight / 2);
        final y = yOfFocalAyah(large, focal);
        final back = focalAyahOfLine(large, y);
        expect(back.ayah, focal.ayah, reason: 'ayah $ayah');
        expect(back.fraction, closeTo(focal.fraction, 1e-9));
        final largeTop =
            large.basmalaExtent +
            large.lineOfAyahText(focal.ayah) * large.lineHeight;
        expect(y, greaterThanOrEqualTo(largeTop));
      }
    });

    test('a finger on a later ayah of a shared line takes that ayah, not the '
        'one the line starts in', () {
      var checked = 0;
      for (final width in [240.0, 300.0, 360.0]) {
        final plan = _plan(fixture, 1, width);
        for (var b = 0; b < plan.blocks.length; b++) {
          final block = BlockLayout(plan, b, ink: AppColors.paper.quranInk);
          final g = TargetGeometry.of(block);
          for (final (k, band) in g.lineBands.indexed) {
            final lineAyah =
                plan.lines[plan.blocks[b].firstLine + k].start.ayah + 1;
            bool onLine(Rect r) =>
                r.center.dy >= band.top && r.center.dy < band.bottom;
            final later = [
              for (final MapEntry(:key, :value) in g.words.entries)
                if (onLine(value) && key.ayah != lineAyah) (key.ayah, value),
              for (final MapEntry(:key, :value) in g.markers.entries)
                if (onLine(value) && key.ayah != lineAyah) (key.ayah, value),
            ];
            for (final (ayah, rect) in later) {
              checked++;
              final focal = focalAyahAt(block, rect.center);
              expect(focal.ayah, ayah, reason: 'line starts in ayah $lineAyah');
              final under = focalAyahUnder(
                plan,
                Offset(rect.center.dx, plan.blockTop(b) + rect.center.dy),
                ink: AppColors.paper.quranInk,
              );
              expect(under, focal);
            }
          }
          block.dispose();
        }
      }
      expect(checked, greaterThan(0), reason: 'the surah shares lines');
    });

    test('above the text the first ayah at its top, past it the last at its '
        'bottom', () {
      final plan = _plan(fixture, 1);
      final first = focalAyahOfLine(plan, 0);
      expect(first.ayah, 1);
      expect(first.fraction, 0);
      final last = focalAyahOfLine(plan, plan.height + 100);
      expect(last.ayah, longSurahAyat);
      expect(last.fraction, 1);
    });
  });
}
