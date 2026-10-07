import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/lockup.dart';
import 'package:holyquran/ui/core/widgets/mark.dart';

import '../../../../testing/golden.dart';

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(goldenApp(ReadingTheme.paper, child));

Text _name(WidgetTester tester) => tester.widget<Text>(
  find.descendant(of: find.byType(Lockup), matching: find.byType(Text)),
);

Mark _mark(WidgetTester tester) => tester.widget<Mark>(find.byType(Mark));

void main() {
  final appTitle = lookupAppLocalizations(const Locale('ar')).appTitle;

  testWidgets('writes the app name in Reem Kufi 700 at half the size', (
    tester,
  ) async {
    await _pump(tester, const Lockup());

    final name = _name(tester);
    expect(name.data, appTitle);
    expect(name.style!.fontFamily, AppFonts.kufi);
    expect(name.style!.fontWeight, FontWeight.w700);
    expect(name.style!.fontSize, 24);
    expect(name.style!.height, 1.3);
    expect(name.style!.color, AppColors.paper.brandInk);

    await _pump(tester, const Lockup(size: 37));
    expect(_name(tester).style!.fontSize, 19);
  });

  testWidgets('puts a decorative mark first, so the name is read once', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const Lockup());

    expect(_mark(tester).decorative, isTrue);
    expect(_mark(tester).variant, MarkVariant.paper);
    expect(find.bySemanticsLabel(appTitle), findsOneWidget);
    expect(
      tester.getCenter(find.byType(Mark)).dx,
      greaterThan(tester.getCenter(find.byType(Text)).dx),
    );
    handle.dispose();
  });

  testWidgets('uses the emerald mark and paper-100 name on emerald', (
    tester,
  ) async {
    await _pump(tester, const Lockup(onEmerald: true));

    expect(_mark(tester).variant, MarkVariant.emerald);
    expect(_name(tester).style!.color, Ramps.paper100);
  });

  testWidgets('stacks the name under a mark 1.4 times larger', (tester) async {
    await _pump(tester, const Lockup(stacked: true));

    expect(_mark(tester).size, 48 * 1.4);
    expect(
      tester.getCenter(find.byType(Mark)).dy,
      lessThan(tester.getCenter(find.byType(Text)).dy),
    );
  });

  testWidgets('keeps its size at 200% text scale', (tester) async {
    await _pump(tester, const Lockup());
    final size = tester.getSize(find.byType(Lockup));

    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(tester, const Lockup());
    expect(tester.getSize(find.byType(Lockup)), size);
  });
}
