import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/star_outline.dart';
import 'package:holyquran/ui/core/widgets/surah_header.dart';

import '../../../../testing/golden.dart';

// Synthetic name and information line.
const _name = 'اسم تجريبي';
const _info = 'سطر تجريبي';

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(goldenApp(ReadingTheme.paper, child));

Text _nameText(WidgetTester tester) => tester.widget<Text>(
  find.descendant(of: find.byType(SurahHeader), matching: find.byType(Text)),
);

void _scaleText(WidgetTester tester, double factor) {
  tester.platformDispatcher.textScaleFactorTestValue = factor;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('ar'));

  testWidgets('writes «سورة» before the name, in Reem Kufi 600 primary', (
    tester,
  ) async {
    await _pump(tester, const SurahHeader(name: _name));

    final name = _nameText(tester);
    expect(l10n.surahHeaderName(_name), 'سورة $_name');
    expect(name.data, l10n.surahHeaderName(_name));
    expect(name.style!.fontFamily, AppFonts.kufi);
    expect(name.style!.fontWeight, FontWeight.w600);
    expect(name.style!.fontSize, 26);
    expect(name.style!.color, AppColors.paper.primary);

    await _pump(
      tester,
      const SurahHeader(name: _name, size: SurahHeaderSize.lg),
    );
    expect(_nameText(tester).style!.fontSize, 30);
  });

  testWidgets('has a quarter star on each side', (tester) async {
    await _pump(tester, const SurahHeader(name: _name));
    final stars = tester.widgetList<StarOutline>(find.byType(StarOutline));
    expect(stars.map((star) => star.size), [28, 28]);

    await _pump(
      tester,
      const SurahHeader(name: _name, size: SurahHeaderSize.lg),
    );
    expect(
      tester
          .widgetList<StarOutline>(find.byType(StarOutline))
          .map((s) => s.size),
      [32, 32],
    );
  });

  testWidgets('is as tall as the reference frames at 100%', (tester) async {
    // Inner height plus its 1px border, the 4px padding and the 1.5px frame.
    await _pump(tester, const SurahHeader(name: _name));
    expect(tester.getSize(find.byType(SurahHeader)).height, 56 + 2 + 8 + 3);

    await _pump(
      tester,
      const SurahHeader(name: _name, size: SurahHeaderSize.lg),
    );
    expect(tester.getSize(find.byType(SurahHeader)).height, 64 + 2 + 8 + 3);
  });

  testWidgets('shows the information line only when given', (tester) async {
    await _pump(tester, const SurahHeader(name: _name));
    expect(find.text(_info), findsNothing);
    expect(find.byType(Text), findsOneWidget);

    await _pump(tester, const SurahHeader(name: _name, info: _info));
    final info = tester.widget<Text>(find.text(_info));
    expect(info.style!.fontSize, 14);
    expect(info.style!.color, AppColors.paper.inkMuted);
    expect(info.textAlign, TextAlign.center);
  });

  testWidgets('is read as its name and information, not its stars', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const SurahHeader(name: _name, info: _info));

    expect(find.bySemanticsLabel(l10n.surahHeaderName(_name)), findsOneWidget);
    expect(find.bySemanticsLabel(_info), findsOneWidget);
    handle.dispose();
  });

  testWidgets('grows without overflow at 200% on a 360 wide screen', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    _scaleText(tester, 2);

    for (final size in SurahHeaderSize.values) {
      await _pump(
        tester,
        SurahHeader(name: '$_name $_name', size: size, info: '$_info $_info'),
      );
      expect(tester.takeException(), isNull, reason: '$size');
      expect(
        tester.getSize(find.byType(SurahHeader)).height,
        greaterThan(size == SurahHeaderSize.lg ? 77 : 69),
      );
    }
  });
}
