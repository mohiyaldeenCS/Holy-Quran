import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';
import 'package:holyquran/utils/result.dart';

import '../../test/integrity/pack_integrity_suite.dart';
import '../../testing/golden.dart';
import '../../testing/packs/synthetic_pack.dart';
import 'ayah_widget_face.dart';
import 'widget_fit.dart';

// The S4 ayah widget face (D-094): what it draws, in which colours and at
// which size, with no app above it. Every string is synthetic, written as
// escapes: repeats of a synthetic phrase, never Quran text.

/// A synthetic phrase, «نص تجريبي».
const _phrase = '\u{646}\u{635} \u{62A}\u{62C}\u{631}\u{64A}\u{628}\u{64A}';

/// [_phrase] [n] times, one space apart.
String _repeat(int n) => List.filled(n, _phrase).join(' ');

/// Synthetic names: «اسم تجريبي», «سورة تجريبية» and «اسم».
const _names = [
  '\u{627}\u{633}\u{645} \u{62A}\u{62C}\u{631}\u{64A}\u{628}\u{64A}',
  _surahName,
  '\u{627}\u{633}\u{645}',
];

const _surahName =
    '\u{633}\u{648}\u{631}\u{629} '
    '\u{62A}\u{62C}\u{631}\u{64A}\u{628}\u{64A}\u{629}';

/// Ayat from one phrase to more than either face holds, in the surah shapes
/// the default divisions and sajdas need.
final _surahs = [
  SyntheticSurah(
    name: _names[0],
    ayat: [
      for (final n in [1, 4, 7, 8]) SyntheticAyah(_repeat(n)),
    ],
  ),
  SyntheticSurah(
    name: _names[1],
    ayat: [
      for (final n in [2, 3, 5]) SyntheticAyah(_repeat(n)),
    ],
  ),
  SyntheticSurah(name: _names[2], ayat: [SyntheticAyah(_repeat(1))]),
];

const _wide = Size(364, 170);
const _square = Size(170, 170);
const _sizes = [_wide, _square];

/// Share.dc.html line 89: the widget's `padding:10px`.
const double _padding = 10;

/// Share.dc.html line 90: the frame's `border:1.5px` and `padding:3px`.
const double _outerToInner = 1.5 + 3;

/// Share.dc.html lines 89-90: padding 10, frame 1.5, frame padding 3.
const double _innerFrameInset = 14.5;

/// Share.dc.html line 90: the inner frame's `border:1px`.
const double _innerBorder = 1;

/// Share.dc.html line 90: the column's `gap:2px`.
const double _gap = 2;

/// The colours each look takes, pinned: paper is the board's widget, night its
/// dark-mode mapping (Share.dc.html lines 89-92; D-093, reading 1).
AppColors _colorsOf(WidgetLook look) => switch (look) {
  WidgetLook.paper => AppColors.paper,
  WidgetLook.night => AppColors.night,
};

/// The highest ayah number of the Quran, for a reference as long as any.
const int _longestAyahNumber = 286;

final _templates =
    jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync())
        as Map<String, Object?>;

typedef _Ayah = ({
  QuranAddress address,
  PackText text,
  Uint8List stored,
  PackText surahName,
  Uint8List storedName,
});

void main() {
  late Directory root;
  PackUnderTest? loaded;
  var ayat = <_Ayah>[];

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('s4_face');
    final built = await buildSyntheticPack(root, surahs: _surahs);
    final pack = loaded = await PackUnderTest.load(built.directory.path);
    ayat = await _ayatOf(pack);
  });
  tearDownAll(() async {
    loaded?.close();
    await root.delete(recursive: true);
  });

  AyahWidgetFace face(
    _Ayah ayah, {
    WidgetLook look = WidgetLook.paper,
    Size size = _wide,
    double? quranSize,
  }) => AyahWidgetFace(
    ayah: ayah.text,
    surahName: ayah.surahName,
    ayahNumber: ayah.address.ayah,
    quranSize:
        quranSize ??
        fitQuranSize(ayah.text, AyahWidgetFace.ayahBoxOf(size)) ??
        fail('${ayah.address} does not fit $size'),
    look: look,
    size: size,
  );

  test('every ayah the pack counts is under test', () {
    final counts = (loaded ?? fail('The pack was not loaded.')).manifest.counts;
    expect(ayat, hasLength(counts.ayat));
  });

  group('bytes', () {
    for (final look in WidgetLook.values) {
      for (final size in _sizes) {
        testWidgets('${look.name} $size draws the stored bytes of every '
            'ayah that fits and of its surah name', (tester) async {
          final problems = <String>[];
          var drawn = 0;
          for (final ayah in ayat) {
            final box = AyahWidgetFace.ayahBoxOf(size);
            final quranSize = fitQuranSize(ayah.text, box);
            if (quranSize == null) continue;
            drawn++;
            await tester.pumpWidget(
              Center(
                child: face(ayah, look: look, size: size, quranSize: quranSize),
              ),
            );
            final where = '${ayah.address} ${look.name} $size';
            problems
              ..addAll(
                drawnTextProblems(
                  where,
                  tester.widget<RichText>(_quranRichText).text,
                  tester.renderObject<RenderParagraph>(_quranRichText).text,
                  ayah.stored,
                ),
              )
              ..addAll(
                drawnTextProblems(
                  '$where reference',
                  tester.widget<RichText>(_referenceRichText).text,
                  tester.renderObject<RenderParagraph>(_referenceRichText).text,
                  _reference(ayah.storedName, ayah.address.ayah),
                ),
              );
          }
          expectNoProblems(problems);
          expect(drawn, greaterThan(0));
        });
      }
    }
  });

  group('colours', () {
    test('paper is the paper theme and night the night theme', () {
      expect(WidgetLook.paper.theme, ReadingTheme.paper);
      expect(WidgetLook.night.theme, ReadingTheme.night);
    });

    final ambients = <String, Widget Function(Widget)>{
      'alone': (child) => Center(child: child),
      'in a sepia app': (child) => goldenApp(ReadingTheme.sepia, child),
      'in a contrast app': (child) => goldenApp(ReadingTheme.contrast, child),
    };
    for (final look in WidgetLook.values) {
      for (final MapEntry(key: ambient, value: wrap) in ambients.entries) {
        testWidgets('${look.name} takes its own theme\'s colours, $ambient', (
          tester,
        ) async {
          final colors = _colorsOf(look);
          await tester.pumpWidget(wrap(face(ayat.first, look: look)));
          final inFace = find.descendant(
            of: find.byType(AyahWidgetFace),
            matching: find.byType(ColoredBox),
          );
          expect(tester.widget<ColoredBox>(inFace).color, colors.ground);
          final frames = _frames(tester);
          expect(frames, hasLength(2));
          expect(frames[0].border.top.color, colors.ornament);
          expect(frames[0].border.top.width, 1.5);
          expect(frames[0].radius, AppRadius.radiusButton);
          expect(frames[1].border.top.color, colors.ornamentSoft);
          expect(frames[1].border.top.width, 1);
          expect(frames[1].radius, 13);
          for (final frame in frames) {
            expect(frame.border.isUniform, isTrue);
          }
          expect(
            tester.widget<RichText>(_quranRichText).text.style?.color,
            colors.quranInk,
          );
          expect(
            tester.widget<RichText>(_referenceRichText).text.style?.color,
            colors.accent,
          );
        });
      }
    }

    test(
      'the face and the fit hold no literal colour, ramp or font family',
      () {
        final families = RegExp(r"static const String \w+ = '([^']+)';")
            .allMatches(
              File('lib/ui/core/theme/tokens.g.dart').readAsStringSync(),
            );
        expect(families, isNotEmpty);
        for (final path in [
          'spike/s4/ayah_widget_face.dart',
          'spike/s4/widget_fit.dart',
        ]) {
          final source = File(path).readAsStringSync();
          expect(source, isNot(contains('Color(')), reason: path);
          expect(source, isNot(contains('Ramps')), reason: path);
          expect(source, isNot(contains('ramps.g.dart')), reason: path);
          for (final family in families) {
            for (final quote in ["'", '"']) {
              expect(
                source,
                isNot(contains('$quote${family[1]}$quote')),
                reason: '$path names ${family[1]}',
              );
            }
          }
        }
      },
    );
  });

  group('metrics', () {
    for (final size in _sizes) {
      testWidgets('the face is exactly $size, its inner frame inset '
          '$_innerFrameInset', (tester) async {
        await tester.pumpWidget(Center(child: face(ayat.first, size: size)));
        final faceRect = tester.getRect(find.byType(AyahWidgetFace));
        expect(faceRect.size, size);
        final outer = tester.getRect(_frameFinder.at(0));
        final inner = tester.getRect(_frameFinder.at(1));
        expect(outer, faceRect.deflate(_padding));
        expect(inner, outer.deflate(_outerToInner));
        expect(inner, faceRect.deflate(_innerFrameInset));
      });

      testWidgets('at $size the ayah and the reference sit centred in the '
          'inner frame, $_gap apart', (tester) async {
        for (final ayah in ayat) {
          final quranSize = fitQuranSize(
            ayah.text,
            AyahWidgetFace.ayahBoxOf(size),
          );
          if (quranSize == null) continue;
          await tester.pumpWidget(
            Center(
              child: face(ayah, size: size, quranSize: quranSize),
            ),
          );
          final content = tester
              .getRect(_frameFinder.at(1))
              .deflate(_innerBorder);
          final text = tester.getRect(_quranRichText);
          final reference = tester.getRect(_referenceRichText);
          final where = '${ayah.address} at $size';
          expect(
            reference.top - text.bottom,
            moreOrLessEquals(_gap),
            reason: where,
          );
          expect(
            text.top - content.top,
            moreOrLessEquals(content.bottom - reference.bottom),
            reason: where,
          );
          expect(
            text.center.dx,
            moreOrLessEquals(content.center.dx),
            reason: where,
          );
          expect(
            reference.center.dx,
            moreOrLessEquals(content.center.dx),
            reason: where,
          );
        }
      });
    }

    for (final look in WidgetLook.values) {
      testWidgets('${look.name}: the reference is the sans at 13, weight 600, '
          'in the accent', (tester) async {
        await tester.pumpWidget(Center(child: face(ayat.first, look: look)));
        final style = tester.widget<RichText>(_referenceRichText).text.style;
        expect(style?.fontFamily, AppFonts.sans);
        expect(style?.fontSize, 13);
        expect(style?.fontWeight, FontWeight.w600);
        expect(style?.color, _colorsOf(look).accent);
      });
    }

    test('the ayah box of the 4x2 face is 333 wide', () {
      expect(AyahWidgetFace.ayahBoxOf(_wide).width, 333);
      expect(AyahWidgetFace.ayahBoxOf(_square).width, 139);
    });

    testWidgets('the ayah box leaves the gap and one reference line', (
      tester,
    ) async {
      for (final size in _sizes) {
        await tester.pumpWidget(Center(child: face(ayat.first, size: size)));
        final reference = tester.getSize(_referenceRichText).height;
        expect(
          AyahWidgetFace.ayahBoxOf(size).height,
          size.height -
              2 * (_innerFrameInset + _innerBorder) -
              _gap -
              reference,
        );
      }
    });
  });

  group('no app ancestors', () {
    for (final look in WidgetLook.values) {
      for (final size in _sizes) {
        testWidgets('${look.name} $size renders as the root to an image of '
            'its size, with its ground in the padding band and the corners', (
          tester,
        ) async {
          tester.view
            ..physicalSize = size
            ..devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          const key = Key('face');
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: face(ayat.first, look: look, size: size),
            ),
          );
          expect(tester.takeException(), isNull);
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(key),
          );
          final pixels = await tester.runAsync(() async {
            // Pixel ratio 1 and raw RGBA, the defaults.
            final image = await boundary.toImage();
            final bytes = await image.toByteData();
            final result = (
              width: image.width,
              height: image.height,
              bytes: bytes!,
            );
            image.dispose();
            return result;
          });
          expect(pixels, isNotNull);
          final (:width, :height, :bytes) = pixels!;
          expect(Size(width.toDouble(), height.toDouble()), size);
          int argbAt(int x, int y) {
            final i = (y * width + x) * 4;
            return bytes.getUint8(i + 3) << 24 |
                bytes.getUint8(i) << 16 |
                bytes.getUint8(i + 1) << 8 |
                bytes.getUint8(i + 2);
          }

          final ground = _colorsOf(look).ground.toARGB32();
          expect(argbAt(5, height ~/ 2), ground, reason: 'padding band');
          expect(argbAt(width ~/ 2, 5), ground, reason: 'padding band');
          expect(argbAt(0, 0), ground, reason: 'square corner');
          expect(
            argbAt(width - 1, height - 1),
            ground,
            reason: 'square corner',
          );
        });
      }
    }

    testWidgets('a system text scale and bold text change no size', (
      tester,
    ) async {
      for (final size in _sizes) {
        await tester.pumpWidget(Center(child: face(ayat.first, size: size)));
        final plain = (
          tester.getSize(_quranRichText),
          tester.getSize(_referenceRichText),
        );
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2),
              boldText: true,
            ),
            child: Center(child: face(ayat.first, size: size)),
          ),
        );
        expect(tester.getSize(find.byType(AyahWidgetFace)), size);
        expect((
          tester.getSize(_quranRichText),
          tester.getSize(_referenceRichText),
        ), plain);
      }
    });
  });

  testWidgets('the reference stays one line for every synthetic name at both '
      'sizes', (tester) async {
    for (final size in _sizes) {
      final line =
          size.height -
          2 * (_innerFrameInset + _innerBorder) -
          _gap -
          AyahWidgetFace.ayahBoxOf(size).height;
      for (final ayah in ayat) {
        for (final number in [ayah.address.ayah, _longestAyahNumber]) {
          await tester.pumpWidget(
            Center(
              child: AyahWidgetFace(
                ayah: ayat.first.text,
                surahName: ayah.surahName,
                ayahNumber: number,
                quranSize: 28,
                look: WidgetLook.paper,
                size: size,
              ),
            ),
          );
          expect(
            tester.getSize(_referenceRichText).height,
            line,
            reason: '${ayah.address} as ayah $number at $size',
          );
        }
      }
    }
  });
}

final _quranRichText = find.descendant(
  of: find.byType(QuranText),
  matching: find.byType(RichText),
);

final _referenceRichText = find.descendant(
  of: find.byType(SurahName),
  matching: find.byType(RichText),
);

final _frameFinder = find.descendant(
  of: find.byType(AyahWidgetFace),
  matching: find.byType(DecoratedBox),
);

/// The face's frames, outer first.
List<({Border border, double radius})> _frames(WidgetTester tester) => [
  for (final box in tester.widgetList<DecoratedBox>(_frameFinder))
    switch (box.decoration) {
      BoxDecoration(
        border: final Border border,
        borderRadius: final BorderRadius radius,
      ) =>
        (border: border, radius: radius.topLeft.x),
      final other => fail('an unexpected decoration $other'),
    },
];

/// The bytes the reference should draw: the `surahAyahReference` template
/// read from the ARB file, with the stored [name] whole and [ayah] in
/// Arabic-Indic digits.
List<int> _reference(List<int> name, int ayah) {
  final template = _templates['surahAyahReference']! as String;
  final bytes = <int>[];
  var at = 0;
  for (final placeholder in RegExp(r'\{(\w+)\}').allMatches(template)) {
    bytes
      ..addAll(utf8.encode(template.substring(at, placeholder.start)))
      ..addAll(switch (placeholder[1]) {
        'name' => name,
        'ayah' => utf8.encode(arabicDigits(ayah)),
        final other => fail('the template has the placeholder $other'),
      });
    at = placeholder.end;
  }
  return bytes..addAll(utf8.encode(template.substring(at)));
}

/// Every ayah of [pack] as the verified repository gives it, with its surah
/// name, and the bytes the independent reader finds for each.
Future<List<_Ayah>> _ayatOf(PackUnderTest pack) async {
  final repository = pack.openRepository();
  T ok<T>(Result<T> result, String what) => switch (result) {
    Ok(:final value) => value,
    Failure(:final error) => fail('$what: $error'),
  };
  final names = {
    for (final surah in ok(await repository.surahs(), 'surah list'))
      surah.number: surah.name,
  };
  return [
    for (final row in pack.raw.surahs())
      for (final (number, bytes) in pack.raw.ayat(row.number))
        (
          address: QuranAddress(repository.riwaya, row.number, number),
          text: ok(
            await repository.ayahText(
              QuranAddress(repository.riwaya, row.number, number),
            ),
            'surah ${row.number} ayah $number',
          ),
          stored: bytes,
          surahName: names[row.number] ?? fail('surah ${row.number} unlisted'),
          storedName: row.name,
        ),
  ];
}
