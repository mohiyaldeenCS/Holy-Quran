@Tags(['golden'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';

import 'index_fixture.dart';
import 'index_harness.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

void main() {
  late Directory root;
  late IndexFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('context_sheet_golden_test');
    fixture = await IndexFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  for (final theme in ReadingTheme.values) {
    for (final (name, amount) in [
      ('ayah', _l10n.contextOneAyah),
      ('three', _l10n.ayahCount(3, '٣')),
    ]) {
      testWidgets('the context sheet at $name in ${theme.name}', (
        tester,
      ) async {
        final router = await pumpIndexApp(tester, fixture, theme: theme);
        unawaited(
          router.push(
            Routes.contextSheet(QuranAddress(fixture.index.riwaya, 2, 6)),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(amount));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(WidgetsApp),
          matchesGoldenFile('goldens/context_sheet_${name}_${theme.name}.png'),
        );
      });
    }
  }
}
