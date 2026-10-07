import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';

import '../../../../testing/golden.dart';

// Synthetic, never Quran text. Spaces at both ends and a double space inside
// would be lost to any trimming or normalising.
const _sample = ' نص تجريبي  للاختبار ';

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(goldenApp(ReadingTheme.paper, child));

RenderParagraph _paragraph(WidgetTester tester) =>
    tester.renderObject<RenderParagraph>(find.byType(RichText));

TextStyle _style(WidgetTester tester) => _paragraph(tester).text.style!;

void main() {
  testWidgets('draws exactly the string it was given', (tester) async {
    final text = String.fromCharCodes(_sample.codeUnits);
    await _pump(tester, QuranText(text));

    final span = _paragraph(tester).text as TextSpan;
    expect(identical(span.text, text), isTrue);
    expect(span.text, _sample);
    expect(span.children, isNull);
    expect(_paragraph(tester).text.toPlainText(), _sample);
  });

  testWidgets('uses the Quran font with no fallback, in quran-ink', (
    tester,
  ) async {
    await _pump(tester, const QuranText(_sample));

    final style = _style(tester);
    expect(style.fontFamily, AppFonts.quran);
    expect(style.fontFamilyFallback, isNull);
    expect(style.color, AppColors.paper.quranInk);
    expect(style.fontWeight, FontWeight.w400);
    expect(style.letterSpacing, 0);
  });

  testWidgets('sets each size from its style', (tester) async {
    const expected = {
      QuranTextSize.page: (size: 25.0, height: 2.3),
      QuranTextSize.ayah: (size: 34.0, height: 2.3),
      QuranTextSize.focus: (size: 44.0, height: 2.0),
      QuranTextSize.compact: (size: 22.0, height: 2.2),
    };
    for (final MapEntry(key: size, value: metric) in expected.entries) {
      await _pump(tester, QuranText(_sample, size: size));
      final style = _style(tester);
      expect(style.fontSize, metric.size, reason: '$size');
      expect(style.height, metric.height, reason: '$size');
      expect(style.fontFamily, AppFonts.quran, reason: '$size');
      expect(style.fontFamilyFallback, isNull, reason: '$size');
      expect(
        style.leadingDistribution,
        TextLeadingDistribution.even,
        reason: '$size',
      );
    }
  });

  testWidgets('is right to left and Arabic, aligned as the reference renders', (
    tester,
  ) async {
    const expected = {
      QuranTextSize.page: {
        QuranTextAlign.justify: TextAlign.justify,
        QuranTextAlign.center: TextAlign.center,
        QuranTextAlign.start: TextAlign.start,
      },
      QuranTextSize.ayah: {
        QuranTextAlign.justify: TextAlign.start,
        QuranTextAlign.center: TextAlign.center,
        QuranTextAlign.start: TextAlign.start,
      },
      QuranTextSize.focus: {
        QuranTextAlign.justify: TextAlign.start,
        QuranTextAlign.center: TextAlign.center,
        QuranTextAlign.start: TextAlign.start,
      },
      QuranTextSize.compact: {
        QuranTextAlign.justify: TextAlign.start,
        QuranTextAlign.center: TextAlign.center,
        QuranTextAlign.start: TextAlign.start,
      },
    };
    for (final MapEntry(key: size, value: aligns) in expected.entries) {
      for (final MapEntry(key: align, value: textAlign) in aligns.entries) {
        await _pump(tester, QuranText(_sample, size: size, align: align));
        final paragraph = _paragraph(tester);
        expect(paragraph.textAlign, textAlign, reason: '$size $align');
        expect(paragraph.textDirection, TextDirection.rtl);
        expect(paragraph.locale, const Locale('ar'));
      }
    }
  });

  testWidgets('takes nothing from the surrounding style or bold text', (
    tester,
  ) async {
    await _pump(
      tester,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(boldText: true),
          child: const DefaultTextStyle(
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              letterSpacing: 3,
              decoration: TextDecoration.underline,
              shadows: [Shadow(blurRadius: 2)],
              fontFamilyFallback: [AppFonts.sans],
            ),
            child: QuranText(_sample),
          ),
        ),
      ),
    );

    final style = _style(tester);
    expect(style.fontWeight, FontWeight.w400);
    expect(style.fontStyle, isNot(FontStyle.italic));
    expect(style.letterSpacing, 0);
    expect(style.decoration, isNot(TextDecoration.underline));
    expect(style.shadows, isNull);
    expect(style.fontFamilyFallback, isNull);
  });

  testWidgets('follows the system text scale', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(tester, const QuranText(_sample));

    expect(_paragraph(tester).textScaler.scale(25), 50);
  });

  testWidgets('wraps without overflow at 200% on a 360 wide screen', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final size in QuranTextSize.values) {
      await _pump(
        tester,
        QuranText(List.filled(6, _sample).join(), size: size),
      );
      expect(tester.takeException(), isNull, reason: '$size');
      expect(tester.getSize(find.byType(RichText)).width, lessThan(361));
    }
  });

  testWidgets('is read by screen readers as its text', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const QuranText(_sample));

    expect(find.bySemanticsLabel(_sample), findsOneWidget);
    handle.dispose();
  });
}
