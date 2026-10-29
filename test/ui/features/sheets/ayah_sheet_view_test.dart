import 'package:flutter/material.dart' hide Icon, IconButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/tafsir/source_details_sheet.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/ayah_row.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';
import 'package:holyquran/ui/core/widgets/source_badge.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';
import 'package:holyquran/ui/core/widgets/tafsir_text.dart';
import 'package:holyquran/ui/features/bookmarks/views/note_sheet_view.dart';
import 'package:holyquran/ui/features/listen/views/controls/play_options_sheet.dart';
import 'package:holyquran/ui/features/report/views/report_sheet.dart';
import 'package:holyquran/ui/features/sheets/views/ayah_sheet_view.dart';
import 'package:holyquran/ui/features/tafsir/views/tafsir_reader_screen.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../testing/fakes/fake_player_repository.dart';
import '../../../../testing/packs/synthetic_tafsir_pack.dart';
import '../listen/controls/controls_harness.dart' show planOf;
import '../tafsir/tafsir_harness.dart' show passageOf;
import 'sheets_harness.dart';

Finder get _sheet => find.byType(AyahSheetView);

Finder _button(String label) => find.descendant(
  of: _sheet,
  matching: find.byWidgetPredicate(
    (widget) => widget is Button && widget.label == label,
  ),
);

Finder _heading(String label) =>
    find.descendant(of: _sheet, matching: find.text(label));

Future<GoRouter> _open(
  WidgetTester tester,
  SheetsWorld world, {
  QuranAddress? ayah,
  bool tafsirs = true,
  bool userData = true,
  bool player = true,
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
  Size size = tallPhone,
}) async {
  final router = await pumpSheetsApp(
    tester,
    world,
    tafsirs: tafsirs,
    userData: userData,
    player: player,
    theme: theme,
    textScale: textScale,
    size: size,
  );
  await openSheet(
    tester,
    router,
    Routes.ayahSheet(ayah ?? world.ayah(1, 2)),
    until: find.descendant(of: _sheet, matching: find.byType(AyahRow)),
  );
  await settleReads(tester);
  return router;
}

void main() {
  group('the ayah', () {
    sheetsTest('is the text of the pack, whole, under the surah and ayah it '
        'is of', (tester, world) async {
      await _open(tester, world);

      final ayah = await world.ayahText(tester, world.ayah(1, 2));
      final row = tester.widget<AyahRow>(
        find.descendant(of: _sheet, matching: find.byType(AyahRow)),
      );
      expect(row.text, ayah);
      expect(row.number, 2);
      final title = tester.widget<SurahName>(
        find.descendant(of: _sheet, matching: find.byType(SurahName)),
      );
      expect(title.format, SurahNameFormat.titledWithAyah);
      expect(title.ayah, 2);
      final surahs = await tester.runAsync(world.fixture.quran.surahs);
      expect(title.name, (surahs! as Ok<List<SurahInfo>>).value.first.name);
    });

    sheetsTest('closes for an ayah the pack does not have', (
      tester,
      world,
    ) async {
      await _open(tester, world, ayah: world.ayah(1, 9));
      await settleReads(tester);

      expect(_sheet, findsNothing);
    });

    sheetsTest('closes with no text pack', (tester, world) async {
      final router = await pumpSheetsApp(tester, world, text: false);
      await openSheet(tester, router, Routes.ayahSheet(world.ayah(1, 2)));
      await settleReads(tester);

      expect(_sheet, findsNothing);
    });

    sheetsTest('closes when the pack stops serving while it is open', (
      tester,
      world,
    ) async {
      await _open(tester, world);
      expect(_sheet, findsOneWidget);

      world.text.failing = true;
      world.integrity.report(
        'synthetic-text',
        const IntegrityFailed(PackDisabled('synthetic-text')),
      );
      await settleReads(tester);

      expect(_sheet, findsNothing);
    });

    sheetsTest('is the ayah of a word address', (tester, world) async {
      await _open(tester, world, ayah: world.word(1, 2, 2));

      final row = tester.widget<AyahRow>(
        find.descendant(of: _sheet, matching: find.byType(AyahRow)),
      );
      expect(row.number, 2);
    });
  });

  group('the tafsir section', () {
    sheetsTest('shows the passage, unchanged, with its range and source '
        'badge', (tester, world) async {
      await _open(tester, world);

      expect(_heading(sheetsL10n.wordSheetTabTafsir), findsOneWidget);
      expect(passageOf(defaultSyntheticPassages[0].text), findsOneWidget);
      expect(find.text(sheetsL10n.tafsirRange('١', '٣')), findsOneWidget);
      final badge = tester.widget<SourceBadge>(find.byType(SourceBadge));
      expect(badge.name, const PackText.fromPack('Synthetic tafsir title'));
    });

    sheetsTest('is not shown while no tafsir is installed', (
      tester,
      world,
    ) async {
      await _open(tester, world, tafsirs: false);

      expect(_heading(sheetsL10n.wordSheetTabTafsir), findsNothing);
      expect(find.byType(SourceBadge), findsNothing);
      expect(find.byType(TafsirText), findsNothing);
      expect(find.text(sheetsL10n.tafsirNoPassage), findsNothing);
      expect(find.text(sheetsL10n.noTafsirsYet), findsNothing);
    }, install: false);

    sheetsTest('says so, in the fixed sentence, for an ayah the book has no '
        'passage for', (tester, world) async {
      await _open(tester, world, ayah: world.ayah(1, 4));

      expect(find.text(sheetsL10n.tafsirNoPassage), findsOneWidget);
      expect(find.byType(TafsirText), findsNothing);
      expect(find.byType(SourceBadge), findsOneWidget);
      expect(_button(sheetsL10n.tafsirReaderTitle), findsOneWidget);
    });

    sheetsTest(
      'shows the integrity alert, not the pack, when the tafsir failed its '
      'checks',
      (tester, world) async {
        await tester.runAsync(
          () =>
              world.fixture.install(id: 'synthetic-tafsir-bad', corrupt: true),
        );
        await _open(tester, world);
        await settleReads(tester, until: find.byType(IntegrityAlert));

        expect(find.byType(IntegrityAlert), findsOneWidget);
        expect(find.text(sheetsL10n.integrityPackTitle), findsOneWidget);
        expect(find.byType(TafsirText), findsNothing);
        expect(_button(sheetsL10n.tafsirReaderTitle), findsNothing);
      },
      install: false,
    );

    sheetsTest('opens the details of the book from the badge', (
      tester,
      world,
    ) async {
      await _open(tester, world);

      await tester.ensureVisible(find.byType(SourceBadge));
      await tester.tap(find.byType(SourceBadge));
      await tester.pumpAndSettle();

      expect(find.byType(SourceDetailsSheet), findsOneWidget);
    });

    sheetsTest('leads to the full reader at the ayah', (tester, world) async {
      final router = await _open(tester, world);

      await tester.ensureVisible(_button(sheetsL10n.tafsirReaderTitle));
      await tester.tap(_button(sheetsL10n.tafsirReaderTitle));
      await settleReads(tester, until: find.byType(TafsirReaderScreen));

      expect(_sheet, findsNothing);
      expect(find.byType(TafsirReaderScreen), findsOneWidget);
      expect(router.state.uri.path, Routes.studyTafsir(world.ayah(1, 2)));
    });

    sheetsTest('follows the tafsir when it is removed while open', (
      tester,
      world,
    ) async {
      await _open(tester, world);
      expect(find.byType(SourceBadge), findsOneWidget);

      world.fixture.installs.installed = const [];
      await settleReads(tester);

      expect(find.byType(SourceBadge), findsNothing);
      expect(_heading(sheetsL10n.wordSheetTabTafsir), findsNothing);
    });
  });

  group('the notes section', () {
    Finder tile(String body) => find.ancestor(
      of: find.descendant(of: _sheet, matching: find.text(body)),
      matching: find.byType(Pressable),
    );

    sheetsTest('has only the way to add one while the ayah has none', (
      tester,
      world,
    ) async {
      await _open(tester, world);

      expect(_heading(sheetsL10n.bookmarksTabNotes), findsOneWidget);
      expect(_button(sheetsL10n.noteAdd), findsOneWidget);
      expect(
        find.descendant(of: _sheet, matching: find.byType(Pressable)),
        findsWidgets,
      );
      expect(tile('نص أول'), findsNothing);
    });

    sheetsTest('shows the notes of the ayah whole, and no other ayah\'s', (
      tester,
      world,
    ) async {
      await world.note(world.ayah(1, 2), 'نص أول');
      await world.note(world.ayah(1, 3), 'نص آخر');
      await world.note(world.ayah(1, 2), 'نص ثان طويل يمتد على عدة أسطر ' * 6);
      await _open(tester, world);

      expect(tile('نص أول'), findsOneWidget);
      expect(tile('نص ثان طويل يمتد على عدة أسطر ' * 6), findsOneWidget);
      expect(find.text('نص آخر'), findsNothing);
    });

    sheetsTest('add opens the note sheet of the ayah, and the note saved '
        'there appears when it closes', (tester, world) async {
      await _open(tester, world);

      await tester.ensureVisible(_button(sheetsL10n.noteAdd));
      await tester.tap(_button(sheetsL10n.noteAdd));
      await tester.pumpAndSettle();
      expect(find.byType(NoteSheetView), findsOneWidget);

      await tester.enterText(
        find
            .descendant(
              of: find.byType(NoteSheetView),
              matching: find.byType(TextField),
            )
            .first,
        'نص تجريبي',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(Button, sheetsL10n.noteSave));
      await settleReads(tester);

      expect(find.byType(NoteSheetView), findsNothing);
      expect(_sheet, findsOneWidget);
      expect(tile('نص تجريبي'), findsOneWidget);
    });

    sheetsTest('a note opens in the note sheet on that note', (
      tester,
      world,
    ) async {
      await world.note(world.ayah(1, 2), 'نص أول');
      final second = await world.note(world.ayah(1, 2), 'نص ثان');
      await _open(tester, world);

      await tester.ensureVisible(tile('نص ثان'));
      await tester.tap(tile('نص ثان'));
      await tester.pumpAndSettle();

      expect(find.byType(NoteSheetView), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find
                  .descendant(
                    of: find.byType(NoteSheetView),
                    matching: find.byType(TextField),
                  )
                  .first,
            )
            .controller!
            .text,
        second.body,
      );
    });

    sheetsTest('is not shown without the data of the user', (
      tester,
      world,
    ) async {
      await _open(tester, world, userData: false);

      expect(_heading(sheetsL10n.bookmarksTabNotes), findsNothing);
      expect(_button(sheetsL10n.noteAdd), findsNothing);
    });

    sheetsTest('a note is a labelled button of at least 48', (
      tester,
      world,
    ) async {
      final handle = tester.ensureSemantics();
      await world.note(world.ayah(1, 2), 'ن');
      await _open(tester, world);

      final node = tester.getSemantics(tile('ن'));
      expect(node.label, contains('ن'));
      expect(node.hint, sheetsL10n.noteEdit);
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(
        tester.getSize(tile('ن')).height,
        greaterThanOrEqualTo(AppSizes.targetMin),
      );
      handle.dispose();
    });
  });

  group('the audio section', () {
    sheetsTest('plays from this ayah through the play options', (
      tester,
      world,
    ) async {
      await _open(tester, world, ayah: world.ayah(1, 3));

      await tester.ensureVisible(_button(sheetsL10n.contextPlayFromAyah));
      await tester.tap(_button(sheetsL10n.contextPlayFromAyah));
      await tester.pumpAndSettle();

      expect(_sheet, findsNothing);
      expect(find.byType(PlayOptionsSheet), findsOneWidget);

      await tester.tap(find.widgetWithText(Button, sheetsL10n.playOnlyAyah));
      await tester.pumpAndSettle();

      expect(world.player.commands, ['play 0']);
      final range = world.player.state.plan!.range as FromAyahTool;
      expect(range.ayah, world.ayah(1, 3));
      expect(range.until, AyahToolEnd.ayah);
      expect(find.byType(PlayOptionsSheet), findsNothing);
    });

    sheetsTest('is not shown before the player holds a plan', (
      tester,
      world,
    ) async {
      world.player = FakePlayerRepository();
      await _open(tester, world);

      expect(_button(sheetsL10n.contextPlayFromAyah), findsNothing);
    });

    sheetsTest('appears once a plan is played, while the sheet is open', (
      tester,
      world,
    ) async {
      world.player = FakePlayerRepository();
      await _open(tester, world);
      expect(_button(sheetsL10n.contextPlayFromAyah), findsNothing);

      world.player.state = world.player.state.copyWith(
        plan: planOf(world.builder, WholeSurah(1)),
      );
      await tester.pumpAndSettle();

      expect(_button(sheetsL10n.contextPlayFromAyah), findsOneWidget);
    });

    sheetsTest('is not shown without a player', (tester, world) async {
      await _open(tester, world, player: false);

      expect(_button(sheetsL10n.contextPlayFromAyah), findsNothing);
    });
  });

  group('the report row', () {
    sheetsTest('opens the report of the ayah', (tester, world) async {
      await _open(tester, world);

      await tester.ensureVisible(_button(sheetsL10n.reportError));
      await tester.tap(_button(sheetsL10n.reportError));
      await tester.pumpAndSettle();

      expect(_sheet, findsNothing);
      expect(find.byType(ReportSheet), findsOneWidget);
    });

    sheetsTest('is the last thing in the sheet', (tester, world) async {
      await world.note(world.ayah(1, 2), 'نص أول');
      await _open(tester, world);

      final report = tester.getRect(_button(sheetsL10n.reportError));
      for (final label in [
        sheetsL10n.tafsirReaderTitle,
        sheetsL10n.noteAdd,
        sheetsL10n.contextPlayFromAyah,
      ]) {
        expect(
          tester.getRect(_button(label)).bottom,
          lessThan(report.top),
          reason: label,
        );
      }
    });
  });

  group('for everyone', () {
    sheetsTest('announces the title and each section as headings', (
      tester,
      world,
    ) async {
      final handle = tester.ensureSemantics();
      await _open(tester, world);

      for (final finder in [
        find.descendant(of: _sheet, matching: find.byType(SurahName)),
        _heading(sheetsL10n.wordSheetTabTafsir),
        _heading(sheetsL10n.bookmarksTabNotes),
      ]) {
        expect(
          tester
              .getSemantics(finder)
              .getSemanticsData()
              .flagsCollection
              .isHeader,
          isTrue,
        );
      }
      handle.dispose();
    });

    sheetsTest('every control is named and at least 48 high', (
      tester,
      world,
    ) async {
      final handle = tester.ensureSemantics();
      await world.note(world.ayah(1, 2), 'نص أول');
      await _open(tester, world);

      for (final button in tester.widgetList<Button>(
        find.descendant(of: _sheet, matching: find.byType(Button)),
      )) {
        expect(button.label, isNotEmpty);
        expect(
          tester.getSize(_button(button.label)).height,
          greaterThanOrEqualTo(AppSizes.targetMin),
          reason: button.label,
        );
      }
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    for (final theme in ReadingTheme.values) {
      sheetsTest('fits in ${theme.name} at 200% text on 360 wide, scrolling '
          'to its last row', (tester, world) async {
        await world.note(world.ayah(1, 2), 'نص تجريبي ' * 12);
        await _open(
          tester,
          world,
          theme: theme,
          textScale: 2,
          size: const Size(360, 640),
        );

        expect(tester.takeException(), isNull);
        final sheet = tester.getRect(_sheet);
        expect(sheet.top, greaterThanOrEqualTo(0));
        expect(sheet.bottom, lessThanOrEqualTo(640));
        await tester.ensureVisible(_button(sheetsL10n.reportError));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(_button(sheetsL10n.reportError)).bottom,
          lessThanOrEqualTo(640),
        );
      });
    }
  });
}
