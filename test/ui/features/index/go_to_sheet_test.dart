import 'dart:async';
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
import 'package:holyquran/ui/core/widgets/mode_chips.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';
import 'package:holyquran/ui/features/index/views/go_to_field.dart';
import 'package:holyquran/ui/features/index/views/go_to_sheet.dart';

import 'index_fixture.dart';
import 'index_harness.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

void main() {
  late Directory root;
  late IndexFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('go_to_sheet_test');
    fixture = await IndexFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  Future<GoRouter> openSheet(
    WidgetTester tester, {
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
    unawaited(router.push(Routes.goToSheet));
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> choose(WidgetTester tester, String label) async {
    final chip = find.descendant(
      of: find.byType(ModeChips),
      matching: find.text(label),
    );
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, int field, String text) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(GoToField).at(field),
        matching: find.byType(TextField),
      ),
      text,
    );
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(Button, _l10n.goToTitle));
    await tester.pumpAndSettle();
  }

  QuranAddress at(int surah, int ayah) =>
      QuranAddress(fixture.index.riwaya, surah, ayah);

  testWidgets('offers the six targets and a number field', (tester) async {
    await openSheet(tester);
    expect(find.byType(GoToSheet), findsOneWidget);
    final chips = tester.widget<ModeChips>(find.byType(ModeChips));
    expect(chips.options, [
      _l10n.goToSurah,
      _l10n.goToAyah,
      _l10n.goToPage,
      _l10n.goToJuz,
      _l10n.goToHizb,
      _l10n.goToRub,
    ]);
    expect(chips.selectedIndex, 0);
    expect(find.byType(GoToField), findsOneWidget);
    expect(find.text(_l10n.goToTitle), findsNWidgets(2));
  });

  testWidgets('a surah, typed in Arabic-Indic digits, opens at its first '
      'ayah and closes the sheet', (tester) async {
    final router = await openSheet(tester);
    await type(tester, 0, arabicDigits(2));
    await submit(tester);
    expect(router.state.uri.path, Routes.mushafRead(at(2, 1)));
    expect(find.text('reader ${at(2, 1)}'), findsOneWidget);
    expect(find.byType(GoToSheet), findsNothing);
  });

  testWidgets('the keyboard action key goes too', (tester) async {
    final router = await openSheet(tester);
    await type(tester, 0, '3');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, Routes.mushafRead(at(3, 1)));
  });

  testWidgets('a surah and an ayah open at that ayah', (tester) async {
    final router = await openSheet(tester);
    await choose(tester, _l10n.goToAyah);
    expect(find.byType(GoToField), findsNWidgets(2));
    await type(tester, 0, arabicDigits(2));
    await type(tester, 1, '5');
    await submit(tester);
    expect(router.state.uri.path, Routes.mushafRead(at(2, 5)));
  });

  for (final (label, division) in [
    (_l10n.goToPage, Division.page),
    (_l10n.goToJuz, Division.juz),
    (_l10n.goToHizb, Division.hizb),
    (_l10n.goToRub, Division.rub),
  ]) {
    testWidgets('the last ${division.name} opens at its first ayah, typed in '
        'either digit system', (tester) async {
      final last = fixture.index.count(division);
      for (final digits in [arabicDigits, (int n) => '$n']) {
        final router = await openSheet(tester);
        await choose(tester, label);
        await type(tester, 0, digits(last));
        await submit(tester);
        expect(
          router.state.uri.path,
          Routes.mushafRead(fixture.index.firstAyah(division, last)),
        );
      }
    });
  }

  testWidgets('an ayah the surah does not have names the reason and the '
      'surah, and stays open', (tester) async {
    final router = await openSheet(tester);
    await choose(tester, _l10n.goToAyah);
    final beyond = fixture.surahs[1].ayahCount + 1;
    await type(tester, 0, '2');
    await type(tester, 1, arabicDigits(beyond));
    await submit(tester);
    expect(find.byType(GoToSheet), findsOneWidget);
    expect(router.state.uri.path, Routes.goToSheet);
    final sentence = _l10n.ayahNotInSurah(arabicDigits(beyond), '\u0000');
    final parts = sentence.split('\u0000');
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().startsWith(parts.first) &&
            widget.text.toPlainText().endsWith(parts.last),
      ),
      findsOneWidget,
    );
    final name = tester.widget<SurahName>(find.byType(SurahName));
    expect(name.name, fixture.surahs[1].name);
  });

  testWidgets('a page the pack does not have names the reason', (tester) async {
    final router = await openSheet(tester);
    await choose(tester, _l10n.goToPage);
    final beyond = fixture.index.count(Division.page) + 1;
    await type(tester, 0, arabicDigits(beyond));
    await submit(tester);
    expect(find.text(_l10n.pageNotFound(arabicDigits(beyond))), findsOneWidget);
    expect(router.state.uri.path, Routes.goToSheet);
  });

  testWidgets('a juz, a hizb and a rub the pack does not have name the '
      'reason', (tester) async {
    await openSheet(tester);
    for (final (label, division, sentence) in [
      (_l10n.goToJuz, Division.juz, _l10n.juzNotFound),
      (_l10n.goToHizb, Division.hizb, _l10n.hizbNotFound),
      (_l10n.goToRub, Division.rub, _l10n.rubNotFound),
    ]) {
      await choose(tester, label);
      final beyond = arabicDigits(fixture.index.count(division) + 1);
      await type(tester, 0, beyond);
      await submit(tester);
      expect(find.text(sentence(beyond)), findsOneWidget);
    }
  });

  testWidgets('a surah the pack does not have is named by its number, in '
      'either digit system', (tester) async {
    await openSheet(tester);
    final beyond = fixture.index.surahCount + 1;
    for (final digits in [(int n) => '$n', arabicDigits]) {
      await type(tester, 0, digits(beyond));
      await submit(tester);
      expect(
        find.text(_l10n.surahNumberNotFound(arabicDigits(beyond))),
        findsOneWidget,
      );
      expect(find.text(_l10n.surahNotFound), findsNothing);
      await type(tester, 0, '');
    }
    await type(tester, 0, '0');
    await submit(tester);
    expect(
      find.text(_l10n.surahNumberNotFound(arabicDigits(0))),
      findsOneWidget,
    );
  });

  testWidgets('input that is not a number says it is unreadable', (
    tester,
  ) async {
    await openSheet(tester);
    await type(tester, 0, 'x');
    await submit(tester);
    expect(find.text(_l10n.addressUnreadable), findsOneWidget);
    expect(find.text(_l10n.surahNotFound), findsNothing);
    await type(tester, 0, '');
    expect(find.text(_l10n.addressUnreadable), findsNothing);
  });

  testWidgets('the refusal is announced and carries a shape, not only a '
      'colour', (tester) async {
    final handle = tester.ensureSemantics();
    await openSheet(tester);
    await type(tester, 0, 'x');
    await submit(tester);
    expect(
      tester.getSemantics(find.text(_l10n.addressUnreadable)),
      matchesSemantics(label: _l10n.addressUnreadable, isLiveRegion: true),
    );
    expect(find.byIcon(Icons.error), findsNothing);
    expect(
      find.ancestor(
        of: find.text(_l10n.addressUnreadable),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.liveRegion == true,
        ),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('closes at once while the app has no base pack', (tester) async {
    await openSheet(tester, withPack: false);
    expect(find.byType(GoToSheet), findsNothing);
  });

  testWidgets('its fields are labelled and at least 48 high', (tester) async {
    final handle = tester.ensureSemantics();
    await openSheet(tester);
    await choose(tester, _l10n.goToAyah);
    expect(find.bySemanticsLabel(_l10n.goToSurah), findsWidgets);
    expect(find.bySemanticsLabel(_l10n.goToAyah), findsWidgets);
    for (final field in tester.widgetList(find.byType(GoToField))) {
      expect(
        tester.getSize(find.byWidget(field)).height,
        greaterThanOrEqualTo(48),
      );
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  for (final theme in ReadingTheme.values) {
    testWidgets('lays out without overflow in ${theme.name} at 200%, with an '
        'error', (tester) async {
      await openSheet(tester, theme: theme, textScale: 2);
      await choose(tester, _l10n.goToAyah);
      await type(tester, 0, '2');
      await type(tester, 1, '999');
      await submit(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(GoToSheet), findsOneWidget);
    });
  }
}
