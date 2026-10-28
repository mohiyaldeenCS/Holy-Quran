import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

import '../../../../testing/golden.dart';

// Synthetic, never Quran text. Spaces at both ends and a double space inside
// would be lost to any trimming or normalising.
const _sample = ' نص تجريبي  للاختبار ';
const _packSample = PackText.fromPack(_sample);

final _l10n = lookupAppLocalizations(const Locale('ar'));

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(goldenApp(ReadingTheme.paper, child));

RenderParagraph _paragraph(WidgetTester tester) =>
    tester.renderObject<RenderParagraph>(find.byType(RichText));

TextStyle _style(WidgetTester tester) => _paragraph(tester).text.style!;

void main() {
  testWidgets('draws exactly the string it was given', (tester) async {
    final packText = PackText.fromPack(String.fromCharCodes(_sample.codeUnits));
    await _pump(tester, QuranText(packText));

    final span = _paragraph(tester).text as TextSpan;
    expect(identical(span.text, packText.verbatim), isTrue);
    expect(span.text, _sample);
    expect(span.children, isNull);
    expect(_paragraph(tester).text.toPlainText(), _sample);
  });

  testWidgets('uses the Quran font with no fallback, in quran-ink', (
    tester,
  ) async {
    await _pump(tester, const QuranText(_packSample));

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
      await _pump(tester, QuranText(_packSample, size: size));
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
        await _pump(tester, QuranText(_packSample, size: size, align: align));
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
            child: QuranText(_packSample),
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
    await _pump(tester, const QuranText(_packSample));

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
        QuranText(
          PackText.fromPack(List.filled(6, _sample).join()),
          size: size,
        ),
      );
      expect(tester.takeException(), isNull, reason: '$size');
      expect(tester.getSize(find.byType(RichText)).width, lessThan(361));
    }
  });

  testWidgets('is read by screen readers as its text', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const QuranText(_packSample));

    expect(find.bySemanticsLabel(_sample), findsOneWidget);
    handle.dispose();
  });
  testWidgets('draws each colour role from its source', (tester) async {
    for (final theme in ReadingTheme.values) {
      final colors = buildAppTheme(theme).extension<AppColors>()!;
      final expected = {
        QuranTextColour.quranInk: colors.quranInk,
        QuranTextColour.accent: colors.accent,
        QuranTextColour.onEmerald: Ramps.paper100,
      };
      for (final MapEntry(key: colour, value: color) in expected.entries) {
        await tester.pumpWidget(
          goldenApp(theme, QuranText(_packSample, colour: colour)),
        );
        expect(_style(tester).color, color, reason: '${theme.name} $colour');
        await tester.pumpWidget(
          goldenApp(
            theme,
            QuranText.card(_packSample, fontSize: 26, colour: colour),
          ),
        );
        expect(_style(tester).color, color, reason: '${theme.name} $colour');
      }
    }
  });

  testWidgets('card: centred, at its size with line height 2.2', (
    tester,
  ) async {
    for (final size in const [34.0, 26.0, 23.0, 22.0]) {
      await _pump(tester, QuranText.card(_packSample, fontSize: size));
      final paragraph = _paragraph(tester);
      final style = _style(tester);
      expect(paragraph.textAlign, TextAlign.center);
      expect(paragraph.textDirection, TextDirection.rtl);
      expect(paragraph.locale, const Locale('ar'));
      expect(style.fontSize, size);
      expect(style.height, 2.2);
      expect(style.fontFamily, AppFonts.quran);
      expect(style.fontFamilyFallback, isNull);
      expect(style.leadingDistribution, TextLeadingDistribution.even);
      expect(style.color, AppColors.paper.quranInk);
    }
  });

  testWidgets('card: draws exactly the string it was given', (tester) async {
    final packText = PackText.fromPack(String.fromCharCodes(_sample.codeUnits));
    await _pump(tester, QuranText.card(packText, fontSize: 34));

    final span = _paragraph(tester).text as TextSpan;
    expect(identical(span.text, packText.verbatim), isTrue);
    expect(span.children, isNull);
  });

  testWidgets('card: ignores the system text scale, as an exported image', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(tester, const QuranText.card(_packSample, fontSize: 34));

    expect(_paragraph(tester).textScaler, TextScaler.noScaling);
  });

  testWidgets('card: still RichText, never bold, whatever the ambient style', (
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
              letterSpacing: 3,
              fontFamilyFallback: [AppFonts.sans],
            ),
            child: QuranText.card(
              _packSample,
              fontSize: 26,
              colour: QuranTextColour.onEmerald,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Text), findsNothing);
    expect(find.byType(RichText), findsOneWidget);
    final style = _style(tester);
    expect(style.fontWeight, FontWeight.w400);
    expect(style.letterSpacing, 0);
    expect(style.fontFamilyFallback, isNull);
  });

  testWidgets('quoted: the text whole in its own span, between the copy '
      "format's brackets, with what follows after", (tester) async {
    final packText = PackText.fromPack(String.fromCharCodes(_sample.codeUnits));
    final after = SurahName.span(
      const PackText.fromPack('اسم تجريبي'),
      format: SurahNameFormat.copyReference,
      ayah: 5,
      style: const TextStyle(inherit: false, fontSize: 15),
      l10n: _l10n,
    );
    await _pump(tester, QuranText.quoted(packText, after: after));

    final span = _paragraph(tester).text as TextSpan;
    expect(span.text, isNull);
    final children = span.children!;
    expect(children, hasLength(4));
    expect((children[0] as TextSpan).text, _l10n.ayahQuoteOpen);
    expect(
      identical((children[1] as TextSpan).text, packText.verbatim),
      isTrue,
    );
    expect((children[2] as TextSpan).text, _l10n.ayahQuoteClose);
    expect(children[3], same(after));
    expect(
      span.toPlainText(),
      '${_l10n.ayahQuoteOpen}$_sample${_l10n.ayahQuoteClose}${after.text}',
    );
  });

  testWidgets('quoted: the brackets alone when nothing follows', (
    tester,
  ) async {
    await _pump(tester, const QuranText.quoted(_packSample));

    final children = (_paragraph(tester).text as TextSpan).children!;
    expect(children.map((child) => (child as TextSpan).text), [
      _l10n.ayahQuoteOpen,
      _sample,
      _l10n.ayahQuoteClose,
    ]);
  });

  testWidgets('quoted: centred, at 22 with line height 2, in quran-ink, '
      'following the system text scale', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(tester, const QuranText.quoted(_packSample));

    final paragraph = _paragraph(tester);
    final style = _style(tester);
    expect(paragraph.textAlign, TextAlign.center);
    expect(paragraph.textDirection, TextDirection.rtl);
    expect(paragraph.locale, const Locale('ar'));
    expect(paragraph.textScaler.scale(22), 44);
    expect(style.fontFamily, AppFonts.quran);
    expect(style.fontFamilyFallback, isNull);
    expect(style.fontSize, 22);
    expect(style.height, 2);
    expect(style.fontWeight, FontWeight.w400);
    expect(style.letterSpacing, 0);
    expect(style.leadingDistribution, TextLeadingDistribution.even);
    expect(style.color, AppColors.paper.quranInk);
  });

  test('card: refuses a size below 22', () {
    expect(
      () => QuranText.card(_packSample, fontSize: 21.5),
      throwsAssertionError,
    );
  });
}
