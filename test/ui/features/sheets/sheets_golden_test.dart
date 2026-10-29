@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/widgets/source_badge.dart';
import 'package:holyquran/ui/core/widgets/word_sheet.dart';
import 'package:holyquran/ui/features/sheets/views/ayah_sheet_view.dart';

import 'sheets_harness.dart';

// The word sheet on its text tab and on its tafsir tab, and the mini ayah
// sheet with every section, in the four themes, over the synthetic packs.

const _phone = Size(390, 900);

void main() {
  for (final theme in ReadingTheme.values) {
    sheetsTest('the word sheet, text tab, in ${theme.name}', (
      tester,
      world,
    ) async {
      final router = await pumpSheetsApp(
        tester,
        world,
        theme: theme,
        size: _phone,
      );
      await openSheet(
        tester,
        router,
        Routes.wordSheet(world.word(1, 2, 3)),
        until: find.byType(WordSheet),
      );

      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/word_sheet_text_${theme.name}.png'),
      );
    });

    sheetsTest('the word sheet, tafsir tab, in ${theme.name}', (
      tester,
      world,
    ) async {
      final router = await pumpSheetsApp(
        tester,
        world,
        theme: theme,
        size: _phone,
      );
      await openSheet(
        tester,
        router,
        Routes.wordSheet(world.word(1, 2, 3)),
        until: find.byType(WordSheet),
      );
      await tester.tap(find.text(sheetsL10n.wordSheetTabTafsir));
      await settleReads(tester, until: find.byType(SourceBadge));

      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/word_sheet_tafsir_${theme.name}.png'),
      );
    });

    sheetsTest('the mini ayah sheet in ${theme.name}', (tester, world) async {
      await world.note(world.ayah(1, 2), 'نص تجريبي');
      final router = await pumpSheetsApp(
        tester,
        world,
        theme: theme,
        size: _phone,
      );
      await openSheet(
        tester,
        router,
        Routes.ayahSheet(world.ayah(1, 2)),
        until: find.byType(AyahSheetView),
      );
      await settleReads(tester, until: find.byType(SourceBadge));

      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/ayah_sheet_${theme.name}.png'),
      );
    });
  }
}
