import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' hide IconButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/domain/models/note.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/note_location.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/note_editor.dart';
import 'package:holyquran/ui/core/widgets/tag.dart';
import 'package:holyquran/ui/core/widgets/undo_bar.dart';
import 'package:holyquran/ui/features/bookmarks/views/note_sheet_view.dart';
import 'package:holyquran/utils/result.dart';

import '../index/index_fixture.dart';
import 'bookmarks_harness.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

void main() {
  late Directory root;
  late IndexFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('note_sheet_test');
    fixture = await IndexFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  late BookmarksWorld world;
  setUp(() => world = BookmarksWorld(fixture));

  Future<void> openSheet(
    WidgetTester tester,
    GoRouter router, {
    String? noteId,
  }) async {
    unawaited(router.push(noteSheetLocation(world.ayah(1, 2), noteId: noteId)));
    await tester.pumpAndSettle();
  }

  // The screen under the sheet has a search field of its own.
  Finder field(int index) => find
      .descendant(of: find.byType(NoteEditor), matching: find.byType(TextField))
      .at(index);
  Finder tag(String label) => find.descendant(
    of: find.byType(NoteEditor),
    matching: find.widgetWithText(Tag, label),
  );
  Finder button(String label) => find.widgetWithText(Button, label);

  Future<List<Note>> stored() async =>
      ((await world.notes.notesAt(world.ayah(1, 2))) as Ok<List<Note>>).value;

  testWidgets('opens on an empty editor that cannot be saved yet', (
    tester,
  ) async {
    final router = await pumpBookmarksApp(tester, world, size: tallSheet);
    await openSheet(tester, router);

    expect(find.byType(NoteSheetView), findsOneWidget);
    expect(find.text(_l10n.noteLabel), findsOneWidget);
    expect(find.text(_l10n.noteHint), findsOneWidget);
    expect(find.text(_l10n.categoryLabel), findsOneWidget);
    expect(find.text(_l10n.tagsLabel), findsOneWidget);
    expect(tester.widget<Button>(button(_l10n.noteSave)).onPressed, isNull);
    expect(button(_l10n.noteDelete), findsNothing);
    expect(button(_l10n.noteAdd), findsNothing);
    for (final category in [
      _l10n.tagMemorise,
      _l10n.tagReview,
      _l10n.tagStudy,
      _l10n.tagImportant,
    ]) {
      expect(tag(category), findsOneWidget);
    }
  });

  testWidgets('saves a note with its category and a tag it makes', (
    tester,
  ) async {
    final router = await pumpBookmarksApp(tester, world, size: tallSheet);
    await openSheet(tester, router);

    await tester.enterText(field(0), 'نص تجريبي');
    await tester.pump();
    await tester.tap(tag(_l10n.tagStudy));
    await tester.pump();
    await tester.enterText(field(1), 'وسم تجريبي');
    await tester.tap(button(_l10n.tagAdd));
    await tester.pumpAndSettle();
    expect(tag('وسم تجريبي'), findsOneWidget);
    expect(tester.widget<Tag>(tag('وسم تجريبي')).selected, isTrue);
    expect(tester.widget<Tag>(tag(_l10n.tagStudy)).selected, isTrue);

    await tester.tap(button(_l10n.noteSave));
    await tester.pumpAndSettle();

    expect(find.byType(NoteSheetView), findsNothing);
    final note = (await stored()).single;
    expect(note.body, 'نص تجريبي');
    expect(note.categoryId, BookmarksWorld.category('study'));
    expect(note.tagIds, hasLength(1));
  });

  testWidgets('a note of whitespace alone cannot be saved', (tester) async {
    final router = await pumpBookmarksApp(tester, world, size: tallSheet);
    await openSheet(tester, router);

    await tester.enterText(field(0), '   ');
    await tester.pump();
    expect(tester.widget<Button>(button(_l10n.noteSave)).onPressed, isNull);
  });

  testWidgets('pressing the chosen category again clears it', (tester) async {
    final router = await pumpBookmarksApp(tester, world, size: tallSheet);
    await openSheet(tester, router);

    await tester.tap(tag(_l10n.tagReview));
    await tester.pump();
    expect(tester.widget<Tag>(tag(_l10n.tagReview)).selected, isTrue);
    await tester.tap(tag(_l10n.tagReview));
    await tester.pump();
    expect(tester.widget<Tag>(tag(_l10n.tagReview)).selected, isFalse);
  });

  testWidgets('a second note on the ayah is listed beside the first', (
    tester,
  ) async {
    await world.note(world.ayah(1, 2), 'نص تجريبي');
    final router = await pumpBookmarksApp(tester, world, size: tallSheet);
    await openSheet(tester, router);

    expect(find.text('نص تجريبي'), findsOneWidget);
    await tester.enterText(field(0), 'نص تجريبي ثان');
    await tester.pump();
    await tester.tap(button(_l10n.noteSave));
    await tester.pumpAndSettle();
    expect((await stored()).map((note) => note.body), [
      'نص تجريبي',
      'نص تجريبي ثان',
    ]);

    await openSheet(tester, router);
    expect(find.text('نص تجريبي'), findsOneWidget);
    expect(find.text('نص تجريبي ثان'), findsOneWidget);
  });

  testWidgets('opens on the note it is asked for and edits it', (tester) async {
    await world.note(world.ayah(1, 2), 'نص أول');
    final second = await world.note(
      world.ayah(1, 2),
      'نص ثان',
      category: BookmarksWorld.category('important'),
    );
    final router = await pumpBookmarksApp(tester, world, size: tallSheet);
    await openSheet(tester, router, noteId: second.id);

    final box = tester.widget<TextField>(field(0));
    expect(box.controller!.text, 'نص ثان');
    expect(tester.widget<Tag>(tag(_l10n.tagImportant)).selected, isTrue);
    expect(button(_l10n.noteAdd), findsOneWidget);
    expect(button(_l10n.noteDelete), findsOneWidget);

    // Choosing the other note puts its text in the editor.
    await tester.tap(find.text('نص أول'));
    await tester.pump();
    expect(tester.widget<TextField>(field(0)).controller!.text, 'نص أول');
    expect(tester.widget<Tag>(tag(_l10n.tagImportant)).selected, isFalse);

    await tester.enterText(field(0), 'نص معدل');
    await tester.pump();
    await tester.tap(button(_l10n.noteSave));
    await tester.pumpAndSettle();
    expect((await stored()).map((note) => note.body), ['نص معدل', 'نص ثان']);
  });

  testWidgets('another note starts from an empty editor', (tester) async {
    final made = await world.note(world.ayah(1, 2), 'نص تجريبي');
    final router = await pumpBookmarksApp(tester, world, size: tallSheet);
    await openSheet(tester, router, noteId: made.id);

    await tester.tap(button(_l10n.noteAdd));
    await tester.pump();
    expect(tester.widget<TextField>(field(0)).controller!.text, isEmpty);
    expect(button(_l10n.noteDelete), findsNothing);
    expect(tester.widget<Button>(button(_l10n.noteSave)).onPressed, isNull);
  });

  testWidgets('deleting a note offers «تراجع», and undoing restores it', (
    tester,
  ) async {
    final made = await world.note(world.ayah(1, 2), 'نص تجريبي');
    final router = await pumpBookmarksApp(tester, world, size: tallSheet);
    await openSheet(tester, router, noteId: made.id);

    await tester.tap(button(_l10n.noteDelete));
    await tester.pumpAndSettle();
    expect(await stored(), isEmpty);
    expect(find.byType(UndoBar), findsOneWidget);
    expect(find.text(_l10n.itemDeleted), findsOneWidget);
    expect(find.byType(NoteSheetView), findsOneWidget);

    await tester.tap(find.text(_l10n.undo));
    await tester.pumpAndSettle();
    expect((await stored()).single.body, 'نص تجريبي');
    expect(find.byType(UndoBar), findsNothing);
  });

  testWidgets('says so when the note cannot be stored, and stays open', (
    tester,
  ) async {
    final router = await pumpBookmarksApp(tester, world, size: tallSheet);
    await openSheet(tester, router);
    await tester.enterText(field(0), 'نص تجريبي');
    await tester.pump();

    world.notes.failure = Exception('write failed');
    await tester.tap(button(_l10n.noteSave));
    await tester.pumpAndSettle();

    expect(find.byType(NoteSheetView), findsOneWidget);
    expect(find.text(_l10n.userDataNotSaved), findsOneWidget);
    expect(tester.widget<TextField>(field(0)).controller!.text, 'نص تجريبي');
  });

  testWidgets('closes at once without the user data', (tester) async {
    final router = await pumpBookmarksApp(
      tester,
      world,
      withUserData: false,
      size: tallSheet,
    );
    await openSheet(tester, router);

    expect(find.byType(NoteSheetView), findsNothing);
    expect(router.state.uri.path, isNot(Routes.noteSheet(world.ayah(1, 2))));
  });

  testWidgets('a cold start at the sheet goes to the reader at its ayah', (
    tester,
  ) async {
    final router = await pumpBookmarksApp(
      tester,
      world,
      size: tallSheet,
      location: Routes.noteSheet(world.ayah(1, 2)),
    );
    expect(router.state.uri.path, Routes.mushafRead(world.ayah(1, 2)));
  });

  testWidgets('every control is at least 48 high and named', (tester) async {
    final handle = tester.ensureSemantics();
    await world.note(world.ayah(1, 2), 'نص تجريبي');
    final router = await pumpBookmarksApp(tester, world, size: tallSheet);
    await openSheet(tester, router, noteId: 'fake-note-0');

    for (final control in tester.widgetList<Button>(find.byType(Button))) {
      expect(
        tester.getSize(find.byWidget(control)).height,
        greaterThanOrEqualTo(48),
        reason: control.label,
      );
    }
    for (final chip in tester.widgetList<Tag>(find.byType(Tag))) {
      expect(
        tester.getSize(find.byWidget(chip)).height,
        greaterThanOrEqualTo(48),
        reason: chip.label,
      );
    }
    for (final label in [
      _l10n.noteHint,
      _l10n.tagNewHint,
      _l10n.noteSave,
      _l10n.noteDelete,
    ]) {
      expect(
        find.bySemanticsLabel(label),
        findsAtLeastNWidgets(1),
        reason: label,
      );
    }
    handle.dispose();
  });

  for (final theme in ReadingTheme.values) {
    testWidgets('lays out in ${theme.name} at 200% text without overflow', (
      tester,
    ) async {
      final tag = await world.makeTag('وسم تجريبي');
      final made = await world.note(
        world.ayah(1, 2),
        'نص تجريبي طويل يمتد على عدة أسطر ليظهر التفاف الكلام في النموذج',
        category: BookmarksWorld.category('review'),
        tagIds: {tag.id},
      );
      final router = await pumpBookmarksApp(
        tester,
        world,
        theme: theme,
        textScale: 2,
        size: tallSheet,
      );
      await openSheet(tester, router, noteId: made.id);
      expect(find.byType(NoteSheetView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

/// Tall enough for the whole sheet, so that every control is on the screen.
const tallSheet = Size(390, 3000);
