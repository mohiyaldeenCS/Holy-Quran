import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/mark.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/share_card.dart';
import 'package:holyquran/ui/core/widgets/star_outline.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

// Synthetic ayah and surah name.
const _text = PackText.fromPack('نص تجريبي');
const _name = 'اسم تجريبي';
const _packName = PackText.fromPack(_name);
const _ayah = 5;

Future<void> _pump(
  WidgetTester tester,
  ShareCardDesign design, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
  double fontSize = 34,
}) async {
  tester.view
    ..physicalSize = const Size(360, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    goldenApp(
      theme,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: ShareCard(
            ayah: _text,
            surahName: _packName,
            ayahNumber: _ayah,
            ayahFontSize: fontSize,
            design: design,
          ),
        ),
      ),
    ),
  );
}

Finder _in(Type type) =>
    find.descendant(of: find.byType(ShareCard), matching: find.byType(type));

BoxDecoration _decorationAt(WidgetTester tester, int index) =>
    tester.widget<Container>(_in(Container).at(index)).decoration!
        as BoxDecoration;

Text _appName(WidgetTester tester) =>
    tester.widget<Text>(find.text(_l10n.appTitle));

void main() {
  testWidgets('is 300 by 375 with radius 20, in every design', (tester) async {
    for (final design in ShareCardDesign.values) {
      await _pump(tester, design);
      expect(tester.getSize(find.byType(ShareCard)), const Size(300, 375));
      expect(
        _decorationAt(tester, 0).borderRadius,
        BorderRadius.circular(20),
        reason: design.name,
      );
    }
  });

  testWidgets('keeps its colours whatever the app theme', (tester) async {
    for (final theme in ReadingTheme.values) {
      for (final (design, ground) in [
        (ShareCardDesign.emerald, Ramps.emerald700),
        (ShareCardDesign.paper, AppColors.paper.ground),
        (ShareCardDesign.night, AppColors.night.ground),
      ]) {
        await _pump(tester, design, theme: theme);
        expect(
          _decorationAt(tester, 0).color,
          ground,
          reason: '${design.name} in ${theme.name}',
        );
      }
    }
  });

  testWidgets('emerald: paper-100 ayah, gold-400 reference, emerald mark', (
    tester,
  ) async {
    await _pump(tester, ShareCardDesign.emerald, theme: ReadingTheme.night);
    final ayah = tester.widget<QuranText>(find.byType(QuranText));
    expect(identical(ayah.text, _text), isTrue);
    expect(ayah.cardFontSize, 34);
    expect(ayah.colour, QuranTextColour.onEmerald);

    final reference = tester.widget<SurahName>(find.byType(SurahName));
    expect(reference.format, SurahNameFormat.withAyah);
    expect(reference.ayah, _ayah);
    expect(reference.style.fontFamily, AppFonts.kufi);
    expect(reference.style.fontSize, 18);
    expect(reference.style.fontWeight, FontWeight.w600);
    expect(reference.style.color, Ramps.gold400);
    expect(
      find.text(_l10n.surahAyahReference(_name, arabicDigits(_ayah))),
      findsOneWidget,
    );

    final mark = tester.widget<Mark>(find.byType(Mark));
    expect(mark.size, 26);
    expect(mark.variant, MarkVariant.emerald);
    expect(_appName(tester).style!.fontSize, 14);
    expect(_appName(tester).style!.fontWeight, FontWeight.w700);
    expect(_appName(tester).style!.color, Ramps.paper100);

    final stars = tester.widgetList<StarOutline>(find.byType(StarOutline));
    expect(stars.map((star) => star.size), [280, 220]);
    expect(stars.map((star) => star.stroke), [0.8, 0.8]);
    expect(stars.map((star) => star.color), [
      Ramps.gold400.withValues(alpha: 0.28),
      Ramps.gold400.withValues(alpha: 0.18),
    ]);
  });

  testWidgets('paper: double ornament frame, paper ink and accent', (
    tester,
  ) async {
    const paper = AppColors.paper;
    await _pump(tester, ShareCardDesign.paper, theme: ReadingTheme.night);
    final card = _decorationAt(tester, 0);
    expect((card.border! as Border).top.color, paper.line);
    final outer = _decorationAt(tester, 1);
    expect((outer.border! as Border).top.color, paper.ornament);
    expect((outer.border! as Border).top.width, 1.5);
    expect(outer.borderRadius, BorderRadius.circular(12));
    final inner = _decorationAt(tester, 2);
    expect((inner.border! as Border).top.color, paper.ornamentSoft);
    expect((inner.border! as Border).top.width, 1);
    expect(inner.borderRadius, BorderRadius.circular(8));

    final quran = tester.widget<RichText>(
      find.descendant(
        of: find.byType(QuranText),
        matching: find.byType(RichText),
      ),
    );
    expect(quran.text.style!.color, paper.quranInk);
    final reference = tester.widget<SurahName>(find.byType(SurahName));
    expect(reference.style.fontSize, 17);
    expect(reference.style.color, paper.accent);

    final star = tester.widget<StarOutline>(find.byType(StarOutline));
    expect(star.size, 26);
    final mark = tester.widget<Mark>(find.byType(Mark));
    expect(mark.size, 24);
    expect(mark.variant, MarkVariant.paper);
    expect(_appName(tester).style!.fontSize, 13);
    expect(_appName(tester).style!.color, paper.brandInk);
  });

  testWidgets('night: night ink and accent, one faint ornament star', (
    tester,
  ) async {
    const night = AppColors.night;
    await _pump(tester, ShareCardDesign.night);
    final card = _decorationAt(tester, 0);
    expect((card.border! as Border).top.color, night.line);

    final quran = tester.widget<RichText>(
      find.descendant(
        of: find.byType(QuranText),
        matching: find.byType(RichText),
      ),
    );
    expect(quran.text.style!.color, night.quranInk);
    final reference = tester.widget<SurahName>(find.byType(SurahName));
    expect(reference.style.color, night.accent);

    final star = tester.widget<StarOutline>(find.byType(StarOutline));
    expect(star.size, 300);
    expect(star.color, night.ornament.withValues(alpha: 0.16));
    final mark = tester.widget<Mark>(find.byType(Mark));
    expect(mark.variant, MarkVariant.paper);
    expect(_appName(tester).style!.color, night.brandInk);
  });

  testWidgets('paper and night draw their own themes in sepia and contrast', (
    tester,
  ) async {
    for (final (design, colors) in [
      (ShareCardDesign.paper, AppColors.paper),
      (ShareCardDesign.night, AppColors.night),
    ]) {
      for (final theme in [ReadingTheme.sepia, ReadingTheme.contrast]) {
        final reason = '${design.name} in ${theme.name}';
        await _pump(tester, design, theme: theme);
        final card = _decorationAt(tester, 0);
        expect(card.color, colors.ground, reason: reason);
        expect((card.border! as Border).top.color, colors.line, reason: reason);
        final quran = tester.widget<RichText>(
          find.descendant(
            of: find.byType(QuranText),
            matching: find.byType(RichText),
          ),
        );
        expect(quran.text.style!.color, colors.quranInk, reason: reason);
        expect(
          tester.widget<SurahName>(find.byType(SurahName)).style.color,
          colors.accent,
          reason: reason,
        );
        expect(_appName(tester).style!.color, colors.brandInk, reason: reason);
        if (design == ShareCardDesign.paper) {
          final outer = _decorationAt(tester, 1).border! as Border;
          final inner = _decorationAt(tester, 2).border! as Border;
          expect(outer.top.color, colors.ornament, reason: reason);
          expect(inner.top.color, colors.ornamentSoft, reason: reason);
          final star = tester.widget<CustomPaint>(
            find.descendant(
              of: find.byType(StarOutline),
              matching: find.byType(CustomPaint),
            ),
          );
          expect(
            (star.painter! as StarOutlinePainter).color,
            colors.ornament,
            reason: reason,
          );
        } else {
          expect(
            tester.widget<StarOutline>(find.byType(StarOutline)).color,
            colors.ornament.withValues(alpha: 0.16),
            reason: reason,
          );
        }
      }
    }
  });

  testWidgets('draws the ayah at the size the caller gives', (tester) async {
    await _pump(tester, ShareCardDesign.paper, fontSize: 23);
    expect(tester.widget<QuranText>(find.byType(QuranText)).cardFontSize, 23);
  });

  testWidgets('puts the reference under the ayah, the mark at the foot', (
    tester,
  ) async {
    for (final design in ShareCardDesign.values) {
      await _pump(tester, design);
      final ayah = tester.getRect(find.byType(QuranText));
      final reference = tester.getRect(find.byType(SurahName));
      final mark = tester.getRect(find.byType(Mark));
      final card = tester.getRect(find.byType(ShareCard));
      expect(reference.top, greaterThan(ayah.bottom), reason: design.name);
      expect(mark.top, greaterThan(reference.bottom), reason: design.name);
      expect(ayah.center.dx, closeTo(card.center.dx, 0.5));
    }
  });

  testWidgets('puts the mark before the name, at the right', (tester) async {
    await _pump(tester, ShareCardDesign.emerald);
    expect(
      tester.getRect(find.byType(Mark)).left,
      greaterThan(tester.getRect(find.text(_l10n.appTitle)).right),
    );
  });

  testWidgets('reads the mark by its label', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, ShareCardDesign.emerald);
    expect(
      tester.getSemantics(
        find
            .ancestor(of: find.byType(Mark), matching: find.byType(Semantics))
            .first,
      ),
      matchesSemantics(label: _l10n.markLabel, isImage: true),
    );
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('ignores the system text scale', (tester) async {
    for (final design in ShareCardDesign.values) {
      await _pump(tester, design);
      final reference = tester.getSize(find.byType(SurahName));
      final name = tester.getSize(find.text(_l10n.appTitle));

      await _pump(tester, design, textScale: 2);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(ShareCard)), const Size(300, 375));
      expect(tester.getSize(find.byType(SurahName)), reference);
      expect(tester.getSize(find.text(_l10n.appTitle)), name);
    }
  });
}
