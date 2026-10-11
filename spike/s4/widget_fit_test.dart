import 'dart:io';

import 'package:flutter/material.dart' show Theme;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/utils/result.dart';

import '../../test/integrity/pack_integrity_suite.dart';
import '../../testing/packs/synthetic_pack.dart';
import 'ayah_widget_face.dart';
import 'widget_fit.dart';

// The fit of the widget's ayah (WG-03): the largest whole size from 28 down
// to 22 at which the ayah fills the face's ayah box, or none. Every string is
// synthetic, written as escapes: repeats of a synthetic phrase, never Quran
// text.

/// A synthetic phrase, «نص تجريبي».
const _phrase = '\u{646}\u{635} \u{62A}\u{62C}\u{631}\u{64A}\u{628}\u{64A}';

/// [_phrase] [n] times, one space apart.
String _repeat(int n) => List.filled(n, _phrase).join(' ');

/// «اسم تجريبي».
const _name =
    '\u{627}\u{633}\u{645} \u{62A}\u{62C}\u{631}\u{64A}\u{628}\u{64A}';

/// How many phrases each ayah holds, by surah, in the surah shapes the
/// default divisions and sajdas need.
const _phrases = [
  [1, 4, 7, 8],
  [2, 3, 5],
  [1],
];

final _surahs = [
  for (final counts in _phrases)
    SyntheticSurah(
      name: _name,
      ayat: [for (final n in counts) SyntheticAyah(_repeat(n))],
    ),
];

const _wide = Size(364, 170);
const _square = Size(170, 170);
const _sizes = [_wide, _square];

/// The fit of the ayah of each phrase count in the 4x2 and the 2x2 face,
/// with the pinned fonts.
const _expected = <int, (double?, double?)>{
  1: (28, 28),
  2: (28, 26),
  3: (28, 22),
  4: (26, null),
  5: (26, null),
  7: (23, null),
  8: (null, null),
};

void main() {
  late Directory root;
  PackUnderTest? loaded;
  final ayat = <int, PackText>{};
  late PackText surahName;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('s4_fit');
    final built = await buildSyntheticPack(root, surahs: _surahs);
    final pack = loaded = await PackUnderTest.load(built.directory.path);
    final repository = pack.openRepository();
    surahName = switch (await repository.surahs()) {
      Ok(:final value) => value.first.name,
      Failure(:final error) => fail('surah list: $error'),
    };
    for (final (surah, counts) in _phrases.indexed) {
      for (final (index, n) in counts.indexed) {
        final address = QuranAddress(repository.riwaya, surah + 1, index + 1);
        ayat[n] = switch (await repository.ayahText(address)) {
          Ok(:final value) => value,
          Failure(:final error) => fail('$address: $error'),
        };
      }
    }
  });
  tearDownAll(() async {
    loaded?.close();
    await root.delete(recursive: true);
  });

  PackText ayahOf(int phrases) => ayat[phrases] ?? fail('no ayah of $phrases');

  test('each ayah fits at the size expected, in both faces', () {
    for (final MapEntry(key: n, value: (wide, square)) in _expected.entries) {
      expect(
        fitQuranSize(ayahOf(n), AyahWidgetFace.ayahBoxOf(_wide)),
        wide,
        reason: '$n phrases, 4x2',
      );
      expect(
        fitQuranSize(ayahOf(n), AyahWidgetFace.ayahBoxOf(_square)),
        square,
        reason: '$n phrases, 2x2',
      );
    }
  });

  test('a short ayah fits at 28', () {
    for (final size in _sizes) {
      expect(fitQuranSize(ayahOf(1), AyahWidgetFace.ayahBoxOf(size)), 28);
    }
  });

  test('an ayah too long for 22 gives none', () {
    for (final size in _sizes) {
      expect(fitQuranSize(ayahOf(8), AyahWidgetFace.ayahBoxOf(size)), isNull);
    }
  });

  test('one size above the fit never fits', () {
    var below = 0;
    for (final n in _expected.keys) {
      for (final size in _sizes) {
        final box = AyahWidgetFace.ayahBoxOf(size);
        final fit = fitQuranSize(ayahOf(n), box);
        if (fit == null || fit == 28) continue;
        below++;
        expect(
          fitQuranSize(ayahOf(n), box, from: fit + 1, to: fit + 1),
          isNull,
          reason: '$n phrases at $size',
        );
        final above = widgetAyahSize(ayahOf(n), fit + 1, box.width);
        expect(above.height, greaterThan(box.height));
      }
    }
    expect(below, greaterThan(0));
  });

  test('from and to are honoured', () {
    final wide = AyahWidgetFace.ayahBoxOf(_wide);
    expect(fitQuranSize(ayahOf(1), wide, from: 25), 25);
    expect(fitQuranSize(ayahOf(1), wide, from: 22), 22);
    expect(fitQuranSize(ayahOf(7), wide, to: 24), isNull);
    expect(fitQuranSize(ayahOf(7), wide, from: 27, to: 23), 23);
    expect(fitQuranSize(ayahOf(8), wide, from: 30), isNull);
    expect(() => fitQuranSize(ayahOf(1), wide, to: 21), throwsAssertionError);
    expect(
      () => fitQuranSize(ayahOf(1), wide, from: 23, to: 24),
      throwsAssertionError,
    );
    expect(
      () => fitQuranSize(ayahOf(1), wide, from: 25.5),
      throwsAssertionError,
    );
    expect(() => fitQuranSize(ayahOf(1), wide, to: 22.5), throwsAssertionError);
  });

  for (final (n, size) in [
    for (final MapEntry(key: n, value: (wide, square))
        in _expected.entries) ...[
      if (wide != null && wide < 28) (n, _wide),
      if (square != null && square < 28) (n, _square),
    ],
  ]) {
    testWidgets('the face at the fit of $n phrases at $size lays out without '
        'overflow, the ayah inside its box', (tester) async {
      final box = AyahWidgetFace.ayahBoxOf(size);
      await tester.pumpWidget(
        Center(
          child: AyahWidgetFace(
            ayah: ayahOf(n),
            surahName: surahName,
            ayahNumber: 1,
            quranSize: fitQuranSize(ayahOf(n), box)!,
            look: WidgetLook.paper,
            size: size,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final face = tester.getRect(find.byType(AyahWidgetFace));
      final ayah = tester.getRect(
        find.descendant(
          of: find.byType(QuranText),
          matching: find.byType(RichText),
        ),
      );
      expect(ayah.width, lessThanOrEqualTo(box.width));
      expect(ayah.height, lessThanOrEqualTo(box.height));
      // The inside of the inner frame: padding 10, frames 1.5 and 1,
      // frame padding 3 (Share.dc.html lines 89-90).
      final inside = face.deflate(15.5);
      expect(inside.intersect(ayah), ayah);
    });
  }

  testWidgets('the measure equals the size QuranText.card lays out', (
    tester,
  ) async {
    for (final n in _expected.keys) {
      for (final fontSize in [22.0, 25.0, 28.0]) {
        for (final width in [139.0, 333.0]) {
          await tester.pumpWidget(
            Theme(
              data: buildAppTheme(ReadingTheme.paper),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: width),
                  child: QuranText.card(ayahOf(n), fontSize: fontSize),
                ),
              ),
            ),
          );
          final paragraph = tester.renderObject<RenderParagraph>(
            find.byType(RichText),
          );
          expect(
            widgetAyahSize(ayahOf(n), fontSize, width),
            paragraph.size,
            reason: '$n phrases at $fontSize, $width wide',
          );
        }
      }
    }
  });
}
