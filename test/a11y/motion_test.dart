import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/features/settings/views/settings_screen.dart';

import '../../testing/test_app.dart';
import '../ui/features/sheets/sheets_harness.dart';
import 'a11y_support.dart';

// AX-06: with the system asking for reduced motion, screens and sheets are in
// place at once and nothing is left running.
void main() {
  testWidgets('a screen opens at once and settles with no animation', (
    tester,
  ) async {
    reduceMotion(tester);
    final router = createRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(testApp(router));
    router.go(Routes.more);
    await tester.pumpAndSettle();

    router.go(Routes.settings);
    await tester.pump();

    expect(find.byType(SettingsScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(tester.hasRunningAnimations, isFalse);
  });

  sheetsTest('a sheet opens at once and settles with no animation', (
    tester,
    world,
  ) async {
    reduceMotion(tester);
    final router = await pumpSheetsApp(tester, world, size: phonePortrait);

    unawaited(router.push(Routes.ayahSheet(world.ayah(1, 2))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
    final sheet = tester.getRect(find.byType(BottomSheet));
    expect(sheet.bottom, phonePortrait.height);
  });
}
