@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/ui/core/metrics/reader_metrics.dart';
import 'package:holyquran/ui/core/reader/surah_sliver.dart';

import '../../../../testing/golden.dart';
import 'reader_fixture.dart';

// The opening of the long synthetic surah as the reader's column draws it
// (`Screens.dc.html`: 390 wide, 28 on each side): the basmala, justified
// lines, pause marks kept with their words, markers and a page mark.
const _column = 390 - 2 * ReaderMetrics.textInset;

void main() {
  late Directory root;
  late ReaderFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('surah_sliver_golden');
    fixture = await ReaderFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  testWidgets('a surah-mode block', (tester) async {
    await expectGoldensInThemes(
      tester,
      'surah_block',
      (context) => SizedBox(
        width: _column,
        height: 560,
        child: CustomScrollView(
          slivers: [SurahSliver(text: fixture.surahs[longSurah]!)],
        ),
      ),
      surfaceSize: const Size(390, 600),
    );
  });

  testWidgets('the end of a surah, its last line centred', (tester) async {
    await expectGoldensInThemes(
      tester,
      'surah_block_end',
      (context) => SizedBox(
        width: _column,
        height: 300,
        child: CustomScrollView(
          slivers: [SurahSliver(text: fixture.surahs[overwideSurah]!)],
        ),
      ),
      surfaceSize: const Size(390, 340),
    );
  });
}
