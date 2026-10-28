import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Icon, IconButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/context_sheet.dart';
import 'package:holyquran/ui/core/widgets/level_switch.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

import 'index_fixture.dart';
import 'index_harness.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

void main() {
  late Directory root;
  late IndexFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('context_sheet_route_test');
    fixture = await IndexFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  QuranAddress at(int surah, int ayah) =>
      QuranAddress(fixture.index.riwaya, surah, ayah);

  Future<GoRouter> openSheet(
    WidgetTester tester,
    QuranAddress address, {
    ReadingTheme theme = ReadingTheme.paper,
    double textScale = 1,
    bool withPack = true,
  }) async {
    final router = await pumpIndexApp(
      tester,
      fixture,
      theme: theme,
      textScale: textScale,
      withPack: withPack,
    );
    unawaited(router.push(Routes.contextSheet(address)));
    await tester.pumpAndSettle();
    return router;
  }

  /// The numbers the markers on screen show, in drawing order.
  List<int> markers(WidgetTester tester) => [
    for (final marker in tester.widgetList<AyahMarker>(find.byType(AyahMarker)))
      marker.number,
  ];

  testWidgets('opens on the ayah alone, named in the header', (tester) async {
    await openSheet(tester, at(2, 5));
    expect(find.byType(ContextSheet), findsOneWidget);
    final name = tester.widget<SurahName>(find.byType(SurahName));
    expect(name.name, fixture.surahs[1].name);
    expect(name.ayah, 5);
    expect(markers(tester), [5]);
    final choice = tester.widget<LevelSwitch>(find.byType(LevelSwitch));
    expect(choice.selectedIndex, 0);
    expect(choice.options, [
      _l10n.contextOneAyah,
      _l10n.ayahCount(3, arabicDigits(3)),
      _l10n.ayahCount(5, arabicDigits(5)),
      _l10n.contextSurah,
    ]);
  });

  testWidgets('the amounts show 3 ayat, 5 ayat and the surah around the '
      'ayah', (tester) async {
    await openSheet(tester, at(2, 6));
    await tester.tap(find.text(_l10n.ayahCount(3, '٣')));
    await tester.pumpAndSettle();
    expect(markers(tester), [5, 6, 7]);
    await tester.tap(find.text(_l10n.ayahCount(5, '٥')));
    await tester.pumpAndSettle();
    expect(markers(tester), [4, 5, 6, 7, 8]);
    await tester.tap(find.text(_l10n.contextSurah));
    await tester.pumpAndSettle();
    expect(markers(tester).first, 1);
    await tester.tap(find.text(_l10n.contextOneAyah));
    await tester.pumpAndSettle();
    expect(markers(tester), [6]);
  });

  testWidgets('the sheet draws the pack\'s bytes of the ayat, unchanged', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await openSheet(tester, at(2, 6));
    await tester.tap(find.text(_l10n.ayahCount(3, '٣')));
    await tester.pumpAndSettle();
    for (final (number, bytes) in fixture.pack.raw.ayat(2)) {
      final found = find.bySemanticsLabel(utf8.decode(bytes));
      expect(found, number >= 5 && number <= 7 ? findsOneWidget : findsNothing);
    }
    handle.dispose();
  });

  testWidgets('«افتح في المصحف» opens the reader at the ayah asked for and '
      'closes the sheet', (tester) async {
    final router = await openSheet(tester, at(2, 6));
    await tester.tap(find.text(_l10n.ayahCount(5, '٥')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Button, _l10n.searchResultOpen));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, Routes.mushafRead(at(2, 6)));
    expect(find.text('reader ${at(2, 6)}'), findsOneWidget);
    expect(find.byType(ContextSheet), findsNothing);
  });

  testWidgets('Back from the reader returns to where the sheet was opened', (
    tester,
  ) async {
    final router = await openSheet(tester, at(2, 6));
    await tester.tap(find.widgetWithText(Button, _l10n.searchResultOpen));
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, Routes.mushaf);
    expect(find.byType(ContextSheet), findsNothing);
  });

  testWidgets('shows no play button before the player is wired to it', (
    tester,
  ) async {
    await openSheet(tester, at(2, 6));
    expect(find.bySemanticsLabel(_l10n.contextPlayFromAyah), findsNothing);
  });

  testWidgets('closes at once for an ayah the edition does not have, and '
      'while the app has no base pack', (tester) async {
    await openSheet(tester, at(2, fixture.surahs[1].ayahCount + 1));
    expect(find.byType(ContextSheet), findsNothing);
    await openSheet(tester, at(2, 5), withPack: false);
    expect(find.byType(ContextSheet), findsNothing);
  });

  testWidgets('closes, without an error, when the pack stops serving while '
      'it is open', (tester) async {
    final router = await openSheet(tester, at(2, 6));
    expect(find.byType(ContextSheet), findsOneWidget);
    addTearDown(() => fixture.serving = true);
    fixture.serving = false;
    await tester.tap(find.text(_l10n.contextSurah));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(ContextSheet), findsNothing);
    expect(router.state.uri.path, isNot(Routes.contextSheet(at(2, 6))));
  });

  testWidgets('does not open when the pack is already off', (tester) async {
    addTearDown(() => fixture.serving = true);
    fixture.serving = false;
    await openSheet(tester, at(2, 6));
    expect(tester.takeException(), isNull);
    expect(find.byType(ContextSheet), findsNothing);
  });

  for (final theme in ReadingTheme.values) {
    testWidgets('lays out the whole surah in ${theme.name} at 200%', (
      tester,
    ) async {
      await openSheet(tester, at(2, 6), theme: theme, textScale: 2);
      await tester.tap(find.text(_l10n.contextSurah));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ContextSheet), findsOneWidget);
    });
  }
}
