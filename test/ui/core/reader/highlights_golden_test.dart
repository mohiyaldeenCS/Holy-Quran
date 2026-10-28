@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/metrics/reader_metrics.dart';
import 'package:holyquran/ui/core/reader/interactive_surah_sliver.dart';
import 'package:holyquran/ui/core/reader/reader_highlights.dart';

import '../../../../testing/golden.dart';
import 'reader_fixture.dart';

// The highlight states of the Mushaf board («التمييز داخل النص») in the
// reader's column (390 wide, 28 on each side), on the synthetic long surah:
// the recited ayah with its spoken word and filled marker, a selected ayah, a
// search match.
const _column = 390 - 2 * ReaderMetrics.textInset;

void main() {
  late Directory root;
  late ReaderFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('highlights_golden');
    fixture = await ReaderFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  testWidgets('recited, selected and matched text', (tester) async {
    final surah = fixture.surahs[longSurah]!;
    QuranAddress at(int ayah, [int? word]) =>
        QuranAddress(surah.riwaya, surah.surah, ayah, word);
    await expectGoldensInThemes(
      tester,
      'reader_highlights',
      (context) => SizedBox(
        width: _column,
        height: 560,
        child: CustomScrollView(
          slivers: [
            InteractiveSurahSliver(
              text: surah,
              highlights: ReaderHighlights(
                recitedAyah: at(2),
                spokenWord: at(2, 2),
                selectedAyah: at(4),
                searchMatches: {at(6, 1)},
              ),
            ),
          ],
        ),
      ),
      surfaceSize: const Size(390, 600),
    );
  });
}
