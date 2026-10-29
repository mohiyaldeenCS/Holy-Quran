import 'package:flutter/material.dart' hide Icon, IconButton;
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/routing/route_table.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/tafsir/source_details_sheet.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/source_badge.dart';
import 'package:holyquran/ui/core/widgets/tafsir_text.dart';
import 'package:holyquran/ui/core/widgets/word_sheet.dart';
import 'package:holyquran/ui/features/sheets/views/word_sheet_view.dart';

import '../../../../testing/packs/synthetic_tafsir_pack.dart';
import '../tafsir/tafsir_harness.dart' show passageOf;
import 'sheets_harness.dart';

Finder get _sheet => find.byType(WordSheet);

Finder _tab(String label) =>
    find.descendant(of: _sheet, matching: find.text(label));

/// The string the sheet draws for the word, as the paragraph holds it.
String _drawnWord(WidgetTester tester) => tester
    .widget<RichText>(
      find.descendant(
        of: find.descendant(of: _sheet, matching: find.byType(QuranText)),
        matching: find.byType(RichText),
      ),
    )
    .text
    .toPlainText();

Future<void> _openWord(
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
}

void main() {
  group('the text tab', () {
    sheetsTest('draws the word cut at its stored offsets, nothing else of '
        'the ayah', (tester, world) async {
      await _openWord(tester, world, world.word(1, 2, 3));

      final ayah = await world.ayahText(tester, world.ayah(1, 2));
      final span = await world.wordSpan(tester, world.ayah(1, 2), 3);
      expect(_drawnWord(tester), ayah.verbatim.substring(span.start, span.end));
      expect(_drawnWord(tester), 'two');
      final quran = tester.widget<QuranText>(
        find.descendant(of: _sheet, matching: find.byType(QuranText)),
      );
      expect(quran.text, ayah);
      expect(quran.colour, QuranTextColour.accent);
    });

    sheetsTest('keeps the marks and spaces of the ayah out of the word', (
      tester,
      world,
    ) async {
      // 1:2 holds a mark between its words; the second word is the letter
      // alone.
      await _openWord(tester, world, world.word(1, 2, 2));

      expect(_drawnWord(tester), '\u{E9}');
    });

    sheetsTest('tells the place of the word in its ayah', (
      tester,
      world,
    ) async {
      await _openWord(tester, world, world.word(1, 2, 3));

      expect(find.text(sheetsL10n.wordSheetPosition('٣', '٣')), findsOneWidget);
    });

    sheetsTest('has no row and no source note: no source of word facts is '
        'ready', (tester, world) async {
      await _openWord(tester, world, world.word(1, 1, 1));

      final sheet = tester.widget<WordSheet>(_sheet);
      expect(sheet.rows, isEmpty);
      expect(sheet.note, isNull);
      expect(sheet.body, isNull);
    });

    sheetsTest('shows only the text tab while no tafsir is installed', (
      tester,
      world,
    ) async {
      final router = await pumpSheetsApp(tester, world, tafsirs: false);
      await openSheet(
        tester,
        router,
        Routes.wordSheet(world.word(1, 1, 1)),
        until: _sheet,
      );

      expect(tester.widget<WordSheet>(_sheet).tabs, {WordSheetTab.text});
      expect(_tab(sheetsL10n.wordSheetTabText), findsOneWidget);
      for (final label in [
        sheetsL10n.wordSheetTabTafsir,
        sheetsL10n.wordSheetTabIrab,
        sheetsL10n.wordSheetTabSarf,
        sheetsL10n.wordSheetTabTajweed,
      ]) {
        expect(_tab(label), findsNothing, reason: label);
      }
    }, install: false);

    sheetsTest('shows only the text and tafsir tabs with a tafsir', (
      tester,
      world,
    ) async {
      await _openWord(tester, world, world.word(1, 1, 1));

      expect(tester.widget<WordSheet>(_sheet).tabs, {
        WordSheetTab.text,
        WordSheetTab.tafsir,
      });
      for (final label in [
        sheetsL10n.wordSheetTabIrab,
        sheetsL10n.wordSheetTabSarf,
        sheetsL10n.wordSheetTabTajweed,
      ]) {
        expect(_tab(label), findsNothing, reason: label);
      }
    });
  });

  group('the tafsir tab', () {
    Future<void> openTafsirTab(
      WidgetTester tester,
      SheetsWorld world,
      QuranAddress word,
    ) async {
      await _openWord(tester, world, word);
      await tester.tap(_tab(sheetsL10n.wordSheetTabTafsir));
      await settleReads(tester, until: find.byType(SourceBadge));
    }

    sheetsTest('shows the passage of the ayah of the word, unchanged, with '
        'its range and its source badge', (tester, world) async {
      await openTafsirTab(tester, world, world.word(1, 2, 1));

      expect(passageOf(defaultSyntheticPassages[0].text), findsOneWidget);
      expect(find.text(sheetsL10n.tafsirRange('١', '٣')), findsOneWidget);
      final badge = tester.widget<SourceBadge>(find.byType(SourceBadge));
      expect(badge.name, const PackText.fromPack('Synthetic tafsir title'));
      expect(badge.version, 1);
      // The word stays above the passage.
      expect(_drawnWord(tester), 'Synthetic');
      expect(find.text(sheetsL10n.tafsirNoPassage), findsNothing);
    });

    sheetsTest('reads nothing until the tab is chosen', (tester, world) async {
      await _openWord(tester, world, world.word(1, 2, 1));
      await settleReads(tester);

      expect(find.byType(TafsirText), findsNothing);
      expect(find.byType(SourceBadge), findsNothing);
    });

    sheetsTest('goes back to the word facts by the text tab', (
      tester,
      world,
    ) async {
      await openTafsirTab(tester, world, world.word(1, 2, 1));

      await tester.tap(_tab(sheetsL10n.wordSheetTabText));
      await tester.pumpAndSettle();

      expect(find.byType(SourceBadge), findsNothing);
      expect(tester.widget<WordSheet>(_sheet).selectedTab, WordSheetTab.text);
    });

    sheetsTest('says so, in the fixed sentence, for an ayah the book has no '
        'passage for', (tester, world) async {
      await openTafsirTab(tester, world, world.word(1, 4, 1));

      expect(find.text(sheetsL10n.tafsirNoPassage), findsOneWidget);
      expect(find.byType(TafsirText), findsNothing);
      // The book is still named.
      expect(find.byType(SourceBadge), findsOneWidget);
    });

    sheetsTest('shows no range for a passage over one ayah', (
      tester,
      world,
    ) async {
      await openTafsirTab(tester, world, world.word(2, 1, 1));

      expect(find.textContaining('الآية'), findsNothing);
      expect(find.byType(TafsirText), findsOneWidget);
    });

    sheetsTest('opens the details of the book from the badge', (
      tester,
      world,
    ) async {
      await openTafsirTab(tester, world, world.word(1, 2, 1));

      await tester.tap(find.byType(SourceBadge));
      await tester.pumpAndSettle();

      expect(find.byType(SourceDetailsSheet), findsOneWidget);
      expect(find.text(sheetsL10n.versionLabel), findsOneWidget);
    });

    sheetsTest(
      'shows the integrity alert, not the pack, when the tafsir failed its '
      'checks',
      (tester, world) async {
        await tester.runAsync(
          () =>
              world.fixture.install(id: 'synthetic-tafsir-bad', corrupt: true),
        );
        await _openWord(tester, world, world.word(1, 2, 1));
        await tester.tap(_tab(sheetsL10n.wordSheetTabTafsir));
        await settleReads(tester, until: find.byType(IntegrityAlert));

        expect(find.text(sheetsL10n.integrityPackTitle), findsOneWidget);
        expect(find.byType(TafsirText), findsNothing);
        expect(find.byType(SourceBadge), findsNothing);
      },
      install: false,
    );

    sheetsTest('leaves when the tafsir is removed while it is open', (
      tester,
      world,
    ) async {
      await openTafsirTab(tester, world, world.word(1, 2, 1));

      world.fixture.installs.installed = const [];
      await tester.pumpAndSettle();

      expect(_tab(sheetsL10n.wordSheetTabTafsir), findsNothing);
      expect(tester.widget<WordSheet>(_sheet).selectedTab, WordSheetTab.text);
      expect(find.byType(SourceBadge), findsNothing);
    });
  });

  group('the route', () {
    sheetsTest('closes for a word the ayah does not have', (
      tester,
      world,
    ) async {
      await _openWord(tester, world, world.word(1, 1, 4));
      await settleReads(tester);

      expect(find.byType(WordSheetView), findsNothing);
    });

    sheetsTest('closes for an address that is not a word', (
      tester,
      world,
    ) async {
      final router = await pumpSheetsApp(tester, world);
      await openSheet(tester, router, '/sheet/word/${world.ayah(1, 1)}');
      await settleReads(tester);

      expect(find.byType(WordSheetView), findsNothing);
      expect(router.state.uri.path, Routes.home);
    });

    sheetsTest('closes for an ayah the pack does not have', (
      tester,
      world,
    ) async {
      await _openWord(tester, world, world.word(1, 9, 1));
      await settleReads(tester);

      expect(find.byType(WordSheetView), findsNothing);
    });

    sheetsTest('closes at once with no text pack', (tester, world) async {
      final router = await pumpSheetsApp(tester, world, text: false);
      await openSheet(tester, router, Routes.wordSheet(world.word(1, 1, 1)));
      await settleReads(tester);

      expect(find.byType(WordSheetView), findsNothing);
    });

    sheetsTest('closes when the pack stops serving while it is open', (
      tester,
      world,
    ) async {
      await _openWord(tester, world, world.word(1, 1, 1));
      expect(_sheet, findsOneWidget);

      world.text.failing = true;
      world.integrity.report(
        'synthetic-text',
        const IntegrityFailed(PackDisabled('synthetic-text')),
      );
      await settleReads(tester);

      expect(find.byType(WordSheetView), findsNothing);
    });

    sheetsTest('is a route the reader finds, so a word tap opens it', (
      tester,
      world,
    ) async {
      final router = await pumpSheetsApp(tester, world);

      expect(hasRoute(router, Routes.wordSheet(world.word(2, 255, 3))), isTrue);
      expect(hasRoute(router, Routes.ayahSheet(world.ayah(2, 255))), isTrue);
    });
  });

  group('for everyone', () {
    sheetsTest('announces the tabs, the selected one, and the word', (
      tester,
      world,
    ) async {
      final handle = tester.ensureSemantics();
      await _openWord(tester, world, world.word(1, 2, 3));

      for (final (label, selected) in [
        (sheetsL10n.wordSheetTabText, true),
        (sheetsL10n.wordSheetTabTafsir, false),
      ]) {
        final node = tester.getSemantics(_tab(label));
        expect(
          node,
          matchesSemantics(
            label: label,
            hasSelectedState: true,
            isSelected: selected,
            isFocusable: true,
            hasTapAction: true,
            hasFocusAction: true,
          ),
          reason: label,
        );
        expect(node.role, SemanticsRole.tab);
      }
      expect(find.bySemanticsLabel(RegExp('two')), findsWidgets);
      handle.dispose();
    });

    sheetsTest('a screen reader chooses the tafsir tab', (tester, world) async {
      final handle = tester.ensureSemantics();
      await _openWord(tester, world, world.word(1, 2, 1));

      tester.semantics.tap(
        find.semantics.byLabel(sheetsL10n.wordSheetTabTafsir),
      );
      await settleReads(tester, until: find.byType(SourceBadge));

      expect(find.byType(SourceBadge), findsOneWidget);
      handle.dispose();
    });

    sheetsTest('the badge is a labelled target of at least 48', (
      tester,
      world,
    ) async {
      await _openWord(tester, world, world.word(1, 2, 1));
      await tester.tap(_tab(sheetsL10n.wordSheetTabTafsir));
      await settleReads(tester, until: find.byType(SourceBadge));

      expect(
        tester.getSize(find.byType(SourceBadge)).height,
        greaterThanOrEqualTo(AppSizes.targetMin),
      );
    });

    for (final theme in ReadingTheme.values) {
      sheetsTest(
        'fits in ${theme.name} at 200% text on 360 wide, a long passage '
        'scrolling',
        (tester, world) async {
          final long = List.filled(80, 'Synthetic passage words').join(' ');
          await tester.runAsync(
            () => world.fixture.install(
              id: 'synthetic-tafsir-long',
              passages: [SyntheticPassage(1, 1, 4, long)],
            ),
          );
          await tester.runAsync(
            () =>
                world.fixture.tafsirs.setDefaultTafsir('synthetic-tafsir-long'),
          );
          final router = await pumpSheetsApp(
            tester,
            world,
            theme: theme,
            textScale: 2,
            size: const Size(360, 640),
          );
          await openSheet(
            tester,
            router,
            Routes.wordSheet(world.word(1, 2, 1)),
            until: _sheet,
          );
          await tester.tap(_tab(sheetsL10n.wordSheetTabTafsir));
          await settleReads(tester, until: find.byType(SourceBadge));

          expect(tester.takeException(), isNull);
          final sheet = tester.getRect(_sheet);
          expect(sheet.top, greaterThanOrEqualTo(0));
          expect(sheet.bottom, lessThanOrEqualTo(640));
          final scrollable = find.descendant(
            of: _sheet,
            matching: find.byType(Scrollable),
          );
          // The tab strip and the passage each scroll.
          expect(scrollable, findsNWidgets(2));
          await tester.drag(scrollable.last, const Offset(0, -2000));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(SourceBadge), findsOneWidget);
        },
      );
    }
  });
}
