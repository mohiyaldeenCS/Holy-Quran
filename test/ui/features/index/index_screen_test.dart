import 'dart:io';

import 'package:flutter/material.dart' hide Icon, IconButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/level_switch.dart';
import 'package:holyquran/ui/core/widgets/surah_list_item.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';
import 'package:holyquran/ui/features/index/views/division_row.dart';
import 'package:holyquran/ui/features/index/views/go_to_sheet.dart';
import 'package:holyquran/ui/features/index/views/index_screen.dart';

import '../../../../testing/fakes/fake_reading_position_repository.dart';
import 'index_fixture.dart';
import 'index_harness.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

void main() {
  late Directory root;
  late IndexFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('index_screen_test');
    fixture = await IndexFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  Future<GoRouter> openIndex(
    WidgetTester tester, {
    FakeReadingPositionRepository? positions,
    ReadingTheme theme = ReadingTheme.paper,
    double textScale = 1,
  }) => pumpIndexApp(
    tester,
    fixture,
    positions: positions,
    theme: theme,
    textScale: textScale,
    location: Routes.mushafIndex,
  );

  Future<void> chooseTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(of: find.byType(LevelSwitch), matching: find.text(label)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the title, the summary and the three tabs', (
    tester,
  ) async {
    await openIndex(tester);
    expect(find.byType(IndexScreen), findsOneWidget);
    expect(find.text(_l10n.indexTitle), findsOneWidget);
    expect(
      find.text(
        _l10n.indexSummary(
          arabicDigits(fixture.surahs.length),
          arabicDigits(fixture.index.count(Division.juz)),
        ),
      ),
      findsOneWidget,
    );
    final tabs = tester.widget<LevelSwitch>(find.byType(LevelSwitch));
    expect(tabs.options, [
      _l10n.indexTabSurahs,
      _l10n.indexTabJuz,
      _l10n.indexTabHizb,
    ]);
    expect(tabs.selectedIndex, 0);
  });

  testWidgets('the surah tab lists every surah of the pack, in order', (
    tester,
  ) async {
    await openIndex(tester);
    final items = tester
        .widgetList<SurahListItem>(find.byType(SurahListItem))
        .toList();
    expect(items.map((item) => item.number), [
      for (final surah in fixture.surahs) surah.number,
    ]);
    for (final (index, surah) in fixture.surahs.indexed) {
      final item = items[index];
      expect(item.name, surah.name);
      expect(item.ayahCount, surah.ayahCount);
      expect(item.revelation, surah.revelationPlace);
      expect(item.page, fixture.index.firstPage(surah.number));
    }
    final names = tester.widgetList<SurahName>(find.byType(SurahName));
    expect(names.map((name) => name.name), [
      for (final surah in fixture.surahs) surah.name,
    ]);
  });

  testWidgets('the last-read badge is on the surah of the last position', (
    tester,
  ) async {
    await openIndex(
      tester,
      positions: FakeReadingPositionRepository(
        last: QuranAddress(fixture.index.riwaya, 2, 3),
      ),
    );
    expect(find.text(_l10n.surahListLastRead), findsOneWidget);
    expect(
      tester
          .widgetList<SurahListItem>(find.byType(SurahListItem))
          .map((item) => item.lastRead),
      [for (final surah in fixture.surahs) surah.number == 2],
    );
  });

  testWidgets('no badge before a position has been read', (tester) async {
    await openIndex(tester);
    expect(find.text(_l10n.surahListLastRead), findsNothing);
  });

  testWidgets('the juz tab lists every juz with its surah, ayah and page', (
    tester,
  ) async {
    await openIndex(tester);
    await chooseTab(tester, _l10n.indexTabJuz);
    final entries = fixture.index.divisions(Division.juz);
    expect(find.byType(DivisionRow), findsNWidgets(entries.length));
    expect(find.byType(SurahListItem), findsNothing);
    for (final entry in entries) {
      expect(
        find.text(_l10n.juzLabel(arabicDigits(entry.number))),
        findsOneWidget,
      );
    }
    final names = tester.widgetList<SurahName>(find.byType(SurahName));
    expect(names.map((name) => (name.name, name.ayah)), [
      for (final entry in entries)
        (fixture.surahs[entry.firstAyah.surah - 1].name, entry.firstAyah.ayah),
    ]);
  });

  testWidgets('the hizb tab lists every hizb and every rub of the pack', (
    tester,
  ) async {
    await openIndex(tester);
    // Tall enough for the list to build every row.
    tester.view.physicalSize = const Size(390, 4000);
    await chooseTab(tester, _l10n.indexTabHizb);
    final hizb = fixture.index.divisions(Division.hizb);
    final rubs = fixture.index.divisions(Division.rub);
    for (final entry in hizb) {
      expect(
        find.text(_l10n.hizbLabel(arabicDigits(entry.number))),
        findsOneWidget,
      );
    }
    expect(find.text(_l10n.rubLabel), findsNWidgets(rubs.length));
    expect(find.byType(DivisionRow), findsNWidgets(hizb.length + rubs.length));
    // The first rub of a hizb is a row of its own, with its global number.
    final numbers = tester
        .widgetList<DivisionRow>(find.byType(DivisionRow))
        .where((row) => row.row.isRub)
        .map((row) => row.row.number);
    expect(numbers, [for (final rub in rubs) rub.number]);
    expect(numbers, containsAll([1, 5]));
  });

  testWidgets('a surah row opens the reader at its first ayah', (tester) async {
    final router = await openIndex(tester);
    await tester.tap(find.byType(SurahListItem).at(1));
    await tester.pumpAndSettle();
    final address = QuranAddress(fixture.index.riwaya, 2, 1);
    expect(router.state.uri.path, Routes.mushafRead(address));
  });

  testWidgets('a juz row and a rub row open the reader at their first ayah', (
    tester,
  ) async {
    final router = await openIndex(tester);
    await chooseTab(tester, _l10n.indexTabJuz);
    final juz = fixture.index.divisions(Division.juz).last;
    await tester.tap(find.byType(DivisionRow).last);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, Routes.mushafRead(juz.firstAyah));

    router.pop();
    await tester.pumpAndSettle();
    await chooseTab(tester, _l10n.indexTabHizb);
    await tester.tap(find.text(_l10n.rubLabel).first);
    await tester.pumpAndSettle();
    expect(
      router.state.uri.path,
      Routes.mushafRead(fixture.index.divisions(Division.rub).first.firstAyah),
    );
  });

  testWidgets('a button under the title opens the go-to sheet', (tester) async {
    final router = await openIndex(tester);
    final button = find.widgetWithText(Button, _l10n.goToTitle);
    expect(button, findsOneWidget);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, Routes.goToSheet);
    expect(find.byType(GoToSheet), findsOneWidget);
  });

  testWidgets('shows the title alone while the app has no base pack', (
    tester,
  ) async {
    await pumpIndexApp(
      tester,
      fixture,
      withPack: false,
      location: Routes.mushafIndex,
    );
    expect(find.text(_l10n.indexTitle), findsOneWidget);
    expect(find.byType(LevelSwitch), findsNothing);
    expect(find.byType(Button), findsNothing);
    expect(find.byType(SurahListItem), findsNothing);
  });

  for (final theme in ReadingTheme.values) {
    testWidgets('lays out without overflow in ${theme.name} at 200%', (
      tester,
    ) async {
      await openIndex(tester, theme: theme, textScale: 2);
      for (final label in [
        _l10n.indexTabJuz,
        _l10n.indexTabHizb,
        _l10n.indexTabSurahs,
      ]) {
        await chooseTab(tester, label);
        expect(tester.takeException(), isNull);
      }
    });
  }

  group('with the counts of the real edition', () {
    late Directory fullRoot;
    late IndexFixture full;

    setUpAll(() async {
      fullRoot = await Directory.systemTemp.createTemp('index_full_counts');
      full = await IndexFixture.load(
        fullRoot,
        surahs: fullCountSurahs,
        divisions: fullCountDivisions,
      );
    });
    tearDownAll(() async {
      full.close();
      await fullRoot.delete(recursive: true);
    });

    for (final theme in ReadingTheme.values) {
      testWidgets('the summary of 114 surahs and 30 juz fits in '
          '${theme.name} at 200%, wrapping if it must', (tester) async {
        await pumpIndexApp(
          tester,
          full,
          theme: theme,
          textScale: 2,
          size: const Size(360, 800),
          location: Routes.mushafIndex,
        );
        expect(
          find.text(_l10n.indexSummary(arabicDigits(114), arabicDigits(30))),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('every row is at least 48 high and a labelled target', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await openIndex(tester);
    for (final label in [_l10n.indexTabSurahs, _l10n.indexTabHizb]) {
      await chooseTab(tester, label);
      final rows = find.byWidgetPredicate(
        (widget) => widget is SurahListItem || widget is DivisionRow,
      );
      expect(rows, findsWidgets);
      for (final row in rows.evaluate()) {
        expect(
          tester.getSize(find.byWidget(row.widget)).height,
          greaterThanOrEqualTo(48),
        );
      }
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
