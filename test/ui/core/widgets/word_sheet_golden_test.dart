@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/widgets/word_sheet.dart';

import '../../../../testing/golden.dart';

void main() {
  testWidgets('every tab, the third selected, four rows and a note', (
    tester,
  ) async {
    await expectGoldensInThemes(tester, 'word_sheet', (context) {
      final l10n = AppLocalizations.of(context);
      final row = WordSheetRow(l10n.sampleRowLabel, l10n.sampleRowValue);
      return SizedBox(
        width: 390,
        child: WordSheet(
          word: PackText.fromPack(l10n.sampleWord),
          wordNumber: 2,
          wordCount: 2,
          tabs: WordSheetTab.values.toSet(),
          selectedTab: WordSheetTab.irab,
          onTabSelected: (_) {},
          rows: [row, row, row, row],
          note: l10n.sampleNote,
        ),
      );
    }, surfaceSize: const Size(430, 520));
  });

  testWidgets('a long word at 200%: scaled to the sheet, its place under it', (
    tester,
  ) async {
    await expectGoldensInThemes(
      tester,
      'word_sheet_long_word',
      (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(2)),
        child: SizedBox(
          width: 390,
          child: WordSheet(
            // Synthetic, never Quran text: 14 letters, wider than the sheet
            // at 200%.
            word: const PackText.fromPack('تجريبيةتجريبية'),
            wordNumber: 2,
            wordCount: 2,
            tabs: const {WordSheetTab.text, WordSheetTab.irab},
            selectedTab: WordSheetTab.irab,
            onTabSelected: (_) {},
          ),
        ),
      ),
      surfaceSize: const Size(430, 420),
    );
  });
}
