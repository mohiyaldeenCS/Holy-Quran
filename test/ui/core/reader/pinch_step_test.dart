import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/ui/core/reader/pinch_step.dart';
import 'package:holyquran/ui/core/reader/reader_style.dart';
import 'package:holyquran/ui/core/reader/reader_text_scale.dart';
import 'package:holyquran/ui/core/reader/surah_layout.dart';

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

    test('and stops at both ends', () {
      expect(stepAfterPinch(at100, 9), readerTextSteps.length - 1);
      expect(stepAfterPinch(at100, 0.1), 0);
      expect(stepAfterPinch(readerTextSteps.length - 1, 2), 7);
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
      final focal = focalAyahAt(plan, (top + bottom) / 2);
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
        final focal = focalAyahAt(small, top + small.lineHeight / 2);
        final y = yOfFocalAyah(large, focal);
        final back = focalAyahAt(large, y);
        expect(back.ayah, focal.ayah, reason: 'ayah $ayah');
        expect(back.fraction, closeTo(focal.fraction, 1e-9));
        final largeTop =
            large.basmalaExtent +
            large.lineOfAyahText(focal.ayah) * large.lineHeight;
        expect(y, greaterThanOrEqualTo(largeTop));
      }
    });

    test('above the text the first ayah at its top, past it the last at its '
        'bottom', () {
      final plan = _plan(fixture, 1);
      final first = focalAyahAt(plan, 0);
      expect(first.ayah, 1);
      expect(first.fraction, 0);
      final last = focalAyahAt(plan, plan.height + 100);
      expect(last.ayah, longSurahAyat);
      expect(last.fraction, 1);
    });
  });
}
