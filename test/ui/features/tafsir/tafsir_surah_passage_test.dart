import 'dart:io';

import 'package:flutter/material.dart' hide Icon, IconButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/models/pack_manifest_json.dart';
import 'package:holyquran/data/repositories/tafsir_search_repository.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/search_hit.dart';
import 'package:holyquran/domain/models/verified_pack.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/ayah_row.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/tafsir_text.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../testing/packs/synthetic_files.dart';
import '../../../../testing/packs/synthetic_tafsir_pack.dart';
import 'tafsir_fixture.dart';
import 'tafsir_harness.dart';

// A book's passage on a surah as a whole (D-184), in the reader over the
// synthetic text pack (surahs of 4, 3 and 1 ayat). Every text is synthetic:
// surahs 1 and 2 have such a passage, surah 3 has none.

final _surahOne = syntheticPassagesWithSurahLevel[0].text;
final _surahTwo = syntheticPassagesWithSurahLevel[2].text;
final _overThree = syntheticPassagesWithSurahLevel[1].text;
final _twoOne = syntheticPassagesWithSurahLevel[3].text;

/// The passages with surah-level ones, less the passage over ayah 2:1, so
/// that surah 2's tafsir begins at an ayah with no passage.
final _withoutTwoOne = [
  for (final passage in syntheticPassagesWithSurahLevel)
    if (passage.text != _twoOne) passage,
];

void main() {
  QuranAddress at(TafsirFixture fixture, int surah, int ayah) =>
      QuranAddress(fixture.quran.riwaya, surah, ayah);

  final heading = find.text(tafsirL10n.tafsirAboutSurah);

  /// Every passage of the book's text style on the screen.
  Finder passages() => find.byWidgetPredicate(
    (widget) => widget is TafsirText && widget.style == AppTextStyles.tafsir,
  );

  Future<void> installWhole(
    WidgetTester tester,
    TafsirFixture fixture, {
    List<SyntheticPassage> passages = syntheticPassagesWithSurahLevel,
  }) async {
    await tester.runAsync(() => fixture.install(passages: passages));
  }

  tafsirTest('shows the passage on the surah above the ayah passage where '
      'the surah\'s tafsir begins, as the pack stores it', (
    tester,
    fixture,
  ) async {
    await installWhole(tester, fixture);
    final model = await openModel(tester, fixture, at(fixture, 1, 1));
    await pumpScreen(tester, reader(model));

    expect(passageOf(_surahOne), findsOneWidget);
    expect(passageOf(_overThree), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: passageOf(_surahOne),
              matching: find.byType(Text),
            ),
          )
          .data,
      _surahOne,
    );
    final range = find.text(tafsirL10n.tafsirRange('١', '٣'));
    double top(Finder finder) => tester.getTopLeft(finder).dy;
    expect(heading, findsOneWidget);
    expect(top(find.byType(AyahRow)), lessThan(top(heading)));
    expect(top(heading), lessThan(top(passageOf(_surahOne))));
    expect(top(passageOf(_surahOne)), lessThan(top(range)));
    expect(top(range), lessThan(top(passageOf(_overThree))));
    // Its U+000A is drawn as a break: two lines, where the one-line passage
    // below takes one.
    expect(
      tester.getSize(passageOf(_surahOne)).height,
      greaterThan(tester.getSize(passageOf(_overThree)).height * 1.5),
    );
  }, install: false);

  tafsirTest('shows it where its surah\'s tafsir begins and nowhere else', (
    tester,
    fixture,
  ) async {
    await installWhole(tester, fixture);
    const ayat = {1: 4, 2: 3, 3: 1};
    for (final MapEntry(key: surah, value: count) in ayat.entries) {
      for (var ayah = 1; ayah <= count; ayah++) {
        final model = await openModel(
          tester,
          fixture,
          at(fixture, surah, ayah),
        );
        await pumpScreen(tester, reader(model));

        // Ayat 1:1 to 1:3 are one passage, which begins surah 1's tafsir.
        final shown = (surah == 1 && ayah <= 3) || (surah == 2 && ayah == 1);
        final where = '$surah:$ayah';
        expect(
          passageOf(_surahOne),
          surah == 1 && shown ? findsOneWidget : findsNothing,
          reason: where,
        );
        expect(
          passageOf(_surahTwo),
          surah == 2 && shown ? findsOneWidget : findsNothing,
          reason: where,
        );
        expect(heading, shown ? findsOneWidget : findsNothing, reason: where);
      }
    }
  }, install: false);

  tafsirTest('shows it above the fixed sentence where the surah\'s first '
      'ayah has no passage, and offers no copy of it', (tester, fixture) async {
    await installWhole(tester, fixture, passages: _withoutTwoOne);
    final model = await openModel(tester, fixture, at(fixture, 2, 1));
    await pumpScreen(tester, reader(model));

    expect(model.page!.passage, isNull);
    expect(passageOf(_surahTwo), findsOneWidget);
    expect(passages(), findsOneWidget);
    final none = find.text(tafsirL10n.tafsirNoPassage);
    expect(none, findsOneWidget);
    expect(
      tester.getTopLeft(heading).dy,
      lessThan(tester.getTopLeft(passageOf(_surahTwo)).dy),
    );
    expect(
      tester.getTopLeft(passageOf(_surahTwo)).dy,
      lessThan(tester.getTopLeft(none).dy),
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.label == tafsirL10n.toolbarCopy,
      ),
      findsNothing,
    );
  }, install: false);

  group('a screen reader reads its heading, then it, then the passage', () {
    /// Everything read, in traversal order; texts merged into one node are
    /// read in their order within it.
    String read(WidgetTester tester) => [
      for (final node in tester.semantics.simulatedAccessibilityTraversal())
        if (node.label.isNotEmpty) node.label,
    ].join('\n');

    tafsirTest('with an ayah passage', (tester, fixture) async {
      final handle = tester.ensureSemantics();
      await installWhole(tester, fixture);
      final model = await openModel(tester, fixture, at(fixture, 1, 1));
      await pumpScreen(tester, reader(model));

      final all = read(tester);
      final title = all.indexOf(tafsirL10n.tafsirAboutSurah);
      expect(title, isNonNegative);
      expect(tester.getSemantics(heading).flagsCollection.isHeader, isTrue);
      final whole = all.indexOf(_surahOne);
      expect(whole, greaterThan(title));
      final range = all.indexOf(tafsirL10n.tafsirRange('١', '٣'));
      expect(range, greaterThan(whole));
      expect(all.indexOf(_overThree), greaterThan(range));
      handle.dispose();
    }, install: false);

    tafsirTest('without one', (tester, fixture) async {
      final handle = tester.ensureSemantics();
      await installWhole(tester, fixture, passages: _withoutTwoOne);
      final model = await openModel(tester, fixture, at(fixture, 2, 1));
      await pumpScreen(tester, reader(model));

      final all = read(tester);
      final title = all.indexOf(tafsirL10n.tafsirAboutSurah);
      expect(title, isNonNegative);
      final whole = all.indexOf(_surahTwo);
      expect(whole, greaterThan(title));
      expect(all.indexOf(tafsirL10n.tafsirNoPassage), greaterThan(whole));
      handle.dispose();
    }, install: false);
  });

  for (final theme in ReadingTheme.values) {
    tafsirTest('lays out without overflow in ${theme.name} at 200%, in the '
        'reader and the sheet', (tester, fixture) async {
      await installWhole(tester, fixture);
      final model = await openModel(tester, fixture, at(fixture, 1, 1));
      await pumpScreen(tester, reader(model), theme: theme, textScale: 2);
      expect(tester.takeException(), isNull);
      expect(passageOf(_surahOne), findsOneWidget);

      await pumpScreen(
        tester,
        sheetOf(model),
        theme: theme,
        textScale: 2,
        sheet: true,
      );
      expect(tester.takeException(), isNull);
      expect(passageOf(_surahOne), findsOneWidget);
      expect(heading, findsOneWidget);
    }, install: false);
  }

  tafsirTest('a search hit in it opens where it is shown', (
    tester,
    fixture,
  ) async {
    await installWhole(tester, fixture);
    final book = fixture.books[TafsirFixture.bookId]!;
    final verified = VerifiedPack(
      directory: book.directory.path,
      manifest: (parsePackManifest(
        File('${book.directory.path}/$manifestFileName').readAsBytesSync(),
        pack: TafsirFixture.bookId,
      ) as Ok<PackManifest>).value,
      signatureChecked: false,
    );
    final search = PackTafsirSearchRepository(
      installed: () async => [verified],
      surahCount: 3,
    );
    final hits = (await tester.runAsync(
      () => search.search('surah', [TafsirFixture.bookId]),
    ))!;
    final hit = (hits as Ok<List<TafsirHit>>).value.last;
    expect(hit.surahPassage!.surah, 2);

    final model = await openModel(tester, fixture, hit.ayah);
    await pumpScreen(tester, reader(model));
    expect(model.address, at(fixture, 2, 1));
    expect(passageOf(_surahTwo), findsOneWidget);
  }, install: false);
}
