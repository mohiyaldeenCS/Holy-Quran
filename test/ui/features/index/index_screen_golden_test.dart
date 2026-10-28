@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/widgets/level_switch.dart';

import '../../../../testing/fakes/fake_reading_position_repository.dart';
import 'index_fixture.dart';
import 'index_harness.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

void main() {
  late Directory root;
  late IndexFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('index_screen_golden_test');
    fixture = await IndexFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  for (final theme in ReadingTheme.values) {
    testWidgets('the surah index with a last read in ${theme.name}', (
      tester,
    ) async {
      await pumpIndexApp(
        tester,
        fixture,
        theme: theme,
        positions: FakeReadingPositionRepository(
          last: QuranAddress(fixture.index.riwaya, 2, 3),
        ),
        location: Routes.mushafIndex,
      );
      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/index_surahs_${theme.name}.png'),
      );
    });

    testWidgets('the hizb index with its rubs in ${theme.name}', (
      tester,
    ) async {
      await pumpIndexApp(
        tester,
        fixture,
        theme: theme,
        location: Routes.mushafIndex,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(LevelSwitch),
          matching: find.text(_l10n.indexTabHizb),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/index_hizb_${theme.name}.png'),
      );
    });
  }
}
