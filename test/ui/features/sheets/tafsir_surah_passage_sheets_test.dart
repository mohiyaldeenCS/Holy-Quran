import 'package:flutter/material.dart' hide Icon, IconButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/widgets/ayah_row.dart';
import 'package:holyquran/ui/core/widgets/source_badge.dart';
import 'package:holyquran/ui/core/widgets/word_sheet.dart';
import 'package:holyquran/ui/features/sheets/views/ayah_sheet_view.dart';

import '../../../../testing/packs/synthetic_tafsir_pack.dart';
import '../tafsir/tafsir_harness.dart' show passageOf;
import 'sheets_harness.dart';

// A book's passage on a surah as a whole (D-184) in the tafsir of the ayah
// sheet and of the word sheet, over the synthetic text pack (surahs of 4, 3
// and 1 ayat). Every text is synthetic: surahs 1 and 2 have such a passage,
// surah 3 has none.

final _surahOne = syntheticPassagesWithSurahLevel[0].text;
final _surahTwo = syntheticPassagesWithSurahLevel[2].text;
final _overThree = syntheticPassagesWithSurahLevel[1].text;
final _twoOne = syntheticPassagesWithSurahLevel[3].text;

/// The passages less the one over ayah 2:1, so that surah 2's tafsir begins
/// at an ayah with no passage.
final _withoutTwoOne = [
  for (final passage in syntheticPassagesWithSurahLevel)
    if (passage.text != _twoOne) passage,
];

final _heading = find.text(sheetsL10n.tafsirAboutSurah);

Future<void> _install(
  WidgetTester tester,
  SheetsWorld world, {
  List<SyntheticPassage> passages = syntheticPassagesWithSurahLevel,
}) async {
  await tester.runAsync(() => world.fixture.install(passages: passages));
}

Future<void> _openAyah(
  WidgetTester tester,
  SheetsWorld world,
  QuranAddress ayah, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
  Size size = tallPhone,
}) async {
  final router = await pumpSheetsApp(
    tester,
    world,
    theme: theme,
    textScale: textScale,
    size: size,
  );
  await openSheet(
    tester,
    router,
    Routes.ayahSheet(ayah),
    until: find.descendant(
      of: find.byType(AyahSheetView),
      matching: find.byType(AyahRow),
    ),
  );
  await settleReads(tester, until: find.byType(SourceBadge));
}

Future<void> _openWordTafsir(
  WidgetTester tester,
  SheetsWorld world,
  QuranAddress word,
) async {
  final router = await pumpSheetsApp(tester, world);
  await openSheet(
    tester,
    router,
    Routes.wordSheet(word),
    until: find.byType(WordSheet),
  );
  await tester.tap(
    find.descendant(
      of: find.byType(WordSheet),
      matching: find.text(sheetsL10n.wordSheetTabTafsir),
    ),
  );
  await settleReads(tester, until: find.byType(SourceBadge));
}

double _top(WidgetTester tester, Finder finder) => tester.getTopLeft(finder).dy;

void main() {
  group('the ayah sheet', () {
    sheetsTest('shows it under its heading, above the range and the ayah '
        'passage, where the surah\'s tafsir begins', (tester, world) async {
      await _install(tester, world);
      await _openAyah(tester, world, world.ayah(1, 1));

      expect(_heading, findsOneWidget);
      expect(passageOf(_surahOne), findsOneWidget);
      final range = find.text(sheetsL10n.tafsirRange('١', '٣'));
      expect(
        _top(tester, _heading),
        lessThan(_top(tester, passageOf(_surahOne))),
      );
      expect(_top(tester, passageOf(_surahOne)), lessThan(_top(tester, range)));
      expect(
        _top(tester, range),
        lessThan(_top(tester, passageOf(_overThree))),
      );
    }, install: false);

    sheetsTest('shows it where its surah begins and nowhere else', (
      tester,
      world,
    ) async {
      await _install(tester, world);
      for (final (surah, ayah, shown) in [
        (1, 1, true),
        (1, 4, false),
        (2, 1, true),
        (2, 2, false),
        (3, 1, false),
      ]) {
        await _openAyah(tester, world, world.ayah(surah, ayah));

        final where = '$surah:$ayah';
        final one = shown ? findsOneWidget : findsNothing;
        expect(find.byType(SourceBadge), findsOneWidget, reason: where);
        expect(_heading, one, reason: where);
        expect(
          passageOf(_surahOne),
          surah == 1 ? one : findsNothing,
          reason: where,
        );
        expect(
          passageOf(_surahTwo),
          surah == 2 ? one : findsNothing,
          reason: where,
        );
      }
    }, install: false);

    sheetsTest('shows it above the fixed sentence where the surah\'s first '
        'ayah has no passage', (tester, world) async {
      await _install(tester, world, passages: _withoutTwoOne);
      await _openAyah(tester, world, world.ayah(2, 1));

      final none = find.text(sheetsL10n.tafsirNoPassage);
      expect(none, findsOneWidget);
      expect(
        _top(tester, _heading),
        lessThan(_top(tester, passageOf(_surahTwo))),
      );
      expect(_top(tester, passageOf(_surahTwo)), lessThan(_top(tester, none)));
    }, install: false);

    sheetsTest('a screen reader reads the heading, then it, then the '
        'passage', (tester, world) async {
      final handle = tester.ensureSemantics();
      await _install(tester, world);
      await _openAyah(tester, world, world.ayah(1, 1));

      final all = [
        for (final node in tester.semantics.simulatedAccessibilityTraversal())
          if (node.label.isNotEmpty) node.label,
      ].join('\n');
      final title = all.indexOf(sheetsL10n.tafsirAboutSurah);
      expect(title, isNonNegative);
      expect(tester.getSemantics(_heading).flagsCollection.isHeader, isTrue);
      final whole = all.indexOf(_surahOne);
      expect(whole, greaterThan(title));
      expect(all.indexOf(_overThree), greaterThan(whole));
      handle.dispose();
    }, install: false);

    for (final theme in ReadingTheme.values) {
      sheetsTest('lays it out in ${theme.name} at 200% text on 360 wide', (
        tester,
        world,
      ) async {
        await _install(tester, world);
        await _openAyah(
          tester,
          world,
          world.ayah(1, 1),
          theme: theme,
          textScale: 2,
          size: const Size(360, 640),
        );

        expect(tester.takeException(), isNull);
        expect(_heading, findsOneWidget);
        expect(passageOf(_surahOne), findsOneWidget);
      }, install: false);
    }
  });

  group('the word sheet', () {
    sheetsTest('shows it under its heading at a word of the ayah where the '
        'surah\'s tafsir begins', (tester, world) async {
      await _install(tester, world);
      await _openWordTafsir(tester, world, world.word(2, 1, 1));

      expect(_heading, findsOneWidget);
      expect(passageOf(_surahTwo), findsOneWidget);
      expect(
        _top(tester, _heading),
        lessThan(_top(tester, passageOf(_surahTwo))),
      );
      expect(
        _top(tester, passageOf(_surahTwo)),
        lessThan(_top(tester, passageOf(_twoOne))),
      );
    }, install: false);

    sheetsTest('shows it at a word of the first ayah and of no other', (
      tester,
      world,
    ) async {
      await _install(tester, world);
      for (final (ayah, shown) in [(1, true), (2, false)]) {
        await _openWordTafsir(tester, world, world.word(2, ayah, 1));

        final one = shown ? findsOneWidget : findsNothing;
        expect(find.byType(SourceBadge), findsOneWidget, reason: '$ayah');
        expect(_heading, one, reason: '$ayah');
        expect(passageOf(_surahTwo), one, reason: '$ayah');
      }
    }, install: false);
  });
}
