import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/widgets/lockup.dart';
import 'package:holyquran/ui/core/widgets/splash.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

Future<void> _pump(
  WidgetTester tester, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
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
          child: const SizedBox.expand(child: Splash()),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('fills the screen with emerald-700 in every theme', (
    tester,
  ) async {
    for (final theme in ReadingTheme.values) {
      await _pump(tester, theme: theme);
      expect(tester.getSize(find.byType(Splash)), const Size(360, 800));
      final ground = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(Splash),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(ground.color, Ramps.emerald700, reason: theme.name);
    }
  });

  testWidgets('centres the 64 lockup on emerald', (tester) async {
    await _pump(tester);
    final lockup = tester.widget<Lockup>(find.byType(Lockup));
    expect(lockup.size, 64);
    expect(lockup.onEmerald, isTrue);
    expect(lockup.stacked, isFalse);
    expect(
      tester.getCenter(find.byType(Lockup)),
      tester.getCenter(find.byType(Splash)),
    );
  });

  testWidgets('reads the app name once', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    expect(find.bySemanticsLabel(_l10n.appTitle), findsOneWidget);
    handle.dispose();
  });

  testWidgets('keeps the lockup size at 200% on 360 wide', (tester) async {
    await _pump(tester);
    final size = tester.getSize(find.byType(Lockup));
    await _pump(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(Lockup)), size);
    expect(size.width, lessThan(360));
  });
}
