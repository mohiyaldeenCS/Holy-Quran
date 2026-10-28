@Tags(['golden'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/mode_chips.dart';
import 'package:holyquran/ui/features/index/views/go_to_field.dart';

import 'index_fixture.dart';
import 'index_harness.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

void main() {
  late Directory root;
  late IndexFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('go_to_sheet_golden_test');
    fixture = await IndexFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  for (final theme in ReadingTheme.values) {
    testWidgets('the go-to sheet, empty, in ${theme.name}', (tester) async {
      final router = await pumpIndexApp(tester, fixture, theme: theme);
      unawaited(router.push(Routes.goToSheet));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/go_to_sheet_${theme.name}.png'),
      );
    });

    testWidgets('the go-to sheet with an ayah the surah lacks in '
        '${theme.name}', (tester) async {
      final router = await pumpIndexApp(tester, fixture, theme: theme);
      unawaited(router.push(Routes.goToSheet));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(ModeChips),
          matching: find.text(_l10n.goToAyah),
        ),
      );
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(GoToField),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), '2');
      await tester.enterText(fields.at(1), '99');
      await tester.tap(find.widgetWithText(Button, _l10n.goToTitle));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/go_to_sheet_error_${theme.name}.png'),
      );
    });
  }
}
