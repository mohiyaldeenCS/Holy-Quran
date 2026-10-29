import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/ui/core/widgets/word_sheet.dart';
import 'package:holyquran/ui/features/sheets/view_models/word_sheet_view_model.dart';

import 'sheets_harness.dart';

void main() {
  WordSheetViewModel open(
    WidgetTester tester,
    SheetsWorld world,
    int surah,
    int ayah,
    int word, {
    bool tafsirs = true,
  }) {
    final model = WordSheetViewModel(
      address: world.word(surah, ayah, word),
      text: world.text,
      tafsirs: tafsirs ? world.fixture.tafsirs : null,
      integrity: world.integrity,
    );
    addTearDown(model.dispose);
    return model;
  }

  sheetsTest('holds the ayah as stored and the offsets of the word', (
    tester,
    world,
  ) async {
    final model = open(tester, world, 1, 2, 3);
    await waitUntil(tester, () => model.loaded);

    expect(model.unavailable, isFalse);
    expect(model.ayahText, await world.ayahText(tester, world.ayah(1, 2)));
    expect(model.span, await world.wordSpan(tester, world.ayah(1, 2), 3));
    expect(model.wordCount, 3);
  });

  sheetsTest('offers the text tab alone while no tafsir is installed', (
    tester,
    world,
  ) async {
    final model = open(tester, world, 1, 1, 1, tafsirs: false);
    await waitUntil(tester, () => model.loaded);

    expect(model.tabs, {WordSheetTab.text});
    expect(model.selectedTab, WordSheetTab.text);
    expect(model.tafsir.available, isFalse);
  }, install: false);

  sheetsTest('adds the tafsir tab while a tafsir is installed', (
    tester,
    world,
  ) async {
    final model = open(tester, world, 1, 1, 1);
    await waitUntil(tester, () => model.loaded);

    expect(model.tabs, {WordSheetTab.text, WordSheetTab.tafsir});
  });

  sheetsTest('reads the tafsir only once its tab is chosen', (
    tester,
    world,
  ) async {
    final model = open(tester, world, 1, 2, 1);
    await waitUntil(tester, () => model.loaded);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    expect(model.tafsir.loaded, isFalse);

    model.select(WordSheetTab.tafsir);
    expect(model.selectedTab, WordSheetTab.tafsir);
    await waitUntil(tester, () => model.tafsir.loaded);

    expect(model.tafsir.page, isNotNull);
    expect(model.tafsir.page!.passage, isNotNull);
  });

  sheetsTest('refuses a tab that is not offered', (tester, world) async {
    final model = open(tester, world, 1, 1, 1, tafsirs: false);
    await waitUntil(tester, () => model.loaded);

    model.select(WordSheetTab.tafsir);
    model.select(WordSheetTab.sarf);

    expect(model.selectedTab, WordSheetTab.text);
  }, install: false);

  sheetsTest('goes back to the text tab when the tafsir is removed', (
    tester,
    world,
  ) async {
    final model = open(tester, world, 1, 1, 1);
    await waitUntil(tester, () => model.loaded);
    model.select(WordSheetTab.tafsir);
    await waitUntil(tester, () => model.tafsir.loaded);

    world.fixture.installs.installed = const [];
    await tester.pump();

    expect(model.tabs, {WordSheetTab.text});
    expect(model.selectedTab, WordSheetTab.text);
  });

  sheetsTest('a word the ayah does not have makes the sheet unavailable', (
    tester,
    world,
  ) async {
    final model = open(tester, world, 1, 1, 4);
    await waitUntil(tester, () => model.loaded);

    expect(model.unavailable, isTrue);
  });

  sheetsTest('an ayah the pack does not have makes it unavailable', (
    tester,
    world,
  ) async {
    final model = open(tester, world, 1, 9, 1);
    await waitUntil(tester, () => model.loaded);

    expect(model.unavailable, isTrue);
    expect(model.ayahText, isNull);
  });

  sheetsTest('becomes unavailable when the pack stops serving', (
    tester,
    world,
  ) async {
    final model = open(tester, world, 1, 1, 1);
    await waitUntil(tester, () => model.loaded);
    expect(model.unavailable, isFalse);

    world.text.failing = true;
    world.integrity.report(
      'synthetic-text',
      const IntegrityFailed(PackDisabled('synthetic-text')),
    );
    await waitUntil(tester, () => model.unavailable);

    expect(model.ayahText, isNull);
  });

  // NF-05: a word or ayah sheet opens in 200 ms. What the sheet waits for is
  // its reads of the pack; the draw is a frame.
  sheetsTest('has its word within the 200 ms of NF-05', (tester, world) async {
    final model = open(tester, world, 1, 2, 3);
    final took = await timeUntil(tester, () => model.loaded);

    expect(took, lessThan(const Duration(milliseconds: 200)));
  });
}
