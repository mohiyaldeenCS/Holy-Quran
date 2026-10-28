import 'dart:io';

import 'package:flutter/material.dart' hide IconButton, Tag;
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/bookmark.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/ui_level.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/widgets/annotation_card.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/level_switch.dart';
import 'package:holyquran/ui/core/widgets/tag.dart';
import 'package:holyquran/ui/core/widgets/undo_bar.dart';
import 'package:holyquran/ui/features/bookmarks/views/bookmark_tags_sheet.dart';
import 'package:holyquran/ui/features/bookmarks/views/bookmarks_screen.dart';
import 'package:holyquran/utils/result.dart';

import '../index/index_fixture.dart';
import 'bookmarks_harness.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

// Tall enough that the controls and several cards are built at once.
const _tall = Size(390, 3000);

void main() {
  late Directory root;
  late IndexFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('bookmarks_screen_test');
    fixture = await IndexFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  late BookmarksWorld world;
  setUp(() => world = BookmarksWorld(fixture));

  Finder button(String label) => find.byWidgetPredicate(
    (widget) => widget is IconButton && widget.label == label,
  );

  List<int> shownAyat(WidgetTester tester) => [
    for (final card in tester.widgetList<AnnotationCard>(
      find.byType(AnnotationCard),
    ))
      card.ayahNumber,
  ];

  Future<void> chooseTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(of: find.byType(LevelSwitch), matching: find.text(label)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the title and the empty state of each list', (
    tester,
  ) async {
    await pumpBookmarksApp(tester, world);
    expect(find.byType(BookmarksScreen), findsOneWidget);
    expect(find.text(_l10n.bookmarksAndNotes), findsOneWidget);
    expect(find.text(_l10n.noBookmarksYet), findsOneWidget);
    expect(find.byType(AnnotationCard), findsNothing);

    await chooseTab(tester, _l10n.bookmarksTabNotes);
    expect(find.text(_l10n.noNotesYet), findsOneWidget);
    expect(find.text(_l10n.noBookmarksYet), findsNothing);
  });

  testWidgets('shows only the title without the user data', (tester) async {
    await pumpBookmarksApp(tester, world, withUserData: false);
    expect(find.text(_l10n.bookmarksAndNotes), findsOneWidget);
    expect(find.byType(LevelSwitch), findsNothing);
    expect(find.text(_l10n.noBookmarksYet), findsNothing);
  });

  testWidgets('a card shows the reference, the ayah, the category and tags', (
    tester,
  ) async {
    final tag = await world.makeTag('وسم تجريبي');
    await world.bookmark(
      world.ayah(1, 3),
      category: BookmarksWorld.category('review'),
      tagIds: {tag.id},
    );
    await pumpBookmarksApp(tester, world);

    final card = tester.widget<AnnotationCard>(find.byType(AnnotationCard));
    expect(card.ayahNumber, 3);
    expect(card.surahName, fixture.surahs.first.name);
    expect(card.ayahText, isNotNull);
    expect(
      find.text(
        _l10n.surahAyahReference(
          fixture.surahs.first.name.verbatim,
          arabicDigits(3),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AnnotationCard),
        matching: find.text(_l10n.tagReview),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AnnotationCard),
        matching: find.text('وسم تجريبي'),
      ),
      findsOneWidget,
    );
    expect(find.text(_l10n.bookmarksCount(1, arabicDigits(1))), findsOneWidget);
  });

  testWidgets('the order switches between newest and the mushaf', (
    tester,
  ) async {
    await world.bookmark(world.ayah(1, 5));
    await world.bookmark(world.ayah(1, 2));
    await world.bookmark(world.ayah(1, 4));
    await pumpBookmarksApp(tester, world, size: _tall);
    expect(shownAyat(tester), [4, 2, 5]);
    expect(find.text(_l10n.sortNewest), findsOneWidget);

    await tester.tap(find.text(_l10n.sortNewest));
    await tester.pumpAndSettle();
    expect(shownAyat(tester), [2, 4, 5]);
    expect(find.text(_l10n.searchSortMushafOrder), findsOneWidget);
  });

  testWidgets('filters by category and by tag, and by both again', (
    tester,
  ) async {
    final tag = await world.makeTag('وسم تجريبي');
    await world.bookmark(
      world.ayah(1, 1),
      category: BookmarksWorld.category('review'),
    );
    await world.bookmark(
      world.ayah(1, 2),
      category: BookmarksWorld.category('memorise'),
      tagIds: {tag.id},
    );
    await world.bookmark(
      world.ayah(1, 3),
      category: BookmarksWorld.category('memorise'),
    );
    await pumpBookmarksApp(tester, world, size: _tall);
    expect(shownAyat(tester), [3, 2, 1]);

    // The filter strip comes before the cards, so its tag is the first.
    await tester.tap(find.widgetWithText(Tag, _l10n.tagMemorise).first);
    await tester.pumpAndSettle();
    expect(shownAyat(tester), [3, 2]);

    await tester.tap(find.widgetWithText(Tag, 'وسم تجريبي').first);
    await tester.pumpAndSettle();
    expect(shownAyat(tester), [2]);

    await tester.tap(find.widgetWithText(Tag, 'وسم تجريبي').first);
    await tester.tap(find.widgetWithText(Tag, _l10n.tagMemorise).first);
    await tester.pumpAndSettle();
    expect(shownAyat(tester), [3, 2, 1]);
  });

  testWidgets('searches the tags of bookmarks and says when nothing matches', (
    tester,
  ) async {
    final tag = await world.makeTag('وسم تجريبي');
    await world.bookmark(world.ayah(1, 1), tagIds: {tag.id});
    await world.bookmark(world.ayah(1, 2));
    await pumpBookmarksApp(tester, world, size: _tall);

    await tester.enterText(find.byType(TextField), 'تجريبي');
    await tester.pumpAndSettle();
    expect(shownAyat(tester), [1]);

    await tester.enterText(find.byType(TextField), 'غير موجود');
    await tester.pumpAndSettle();
    expect(find.byType(AnnotationCard), findsNothing);
    expect(find.text(_l10n.noSearchResults), findsOneWidget);
    expect(find.text(_l10n.noBookmarksYet), findsNothing);
  });

  testWidgets('the search field is named for what it searches', (tester) async {
    await pumpBookmarksApp(tester, world);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration!.hintText, _l10n.bookmarksSearchHint);
  });

  testWidgets('the notes tab lists notes with their text, several on an ayah', (
    tester,
  ) async {
    await world.note(world.ayah(1, 2), 'نص تجريبي');
    await world.note(world.ayah(1, 2), 'نص تجريبي ثان');
    await world.bookmark(world.ayah(1, 4));
    await pumpBookmarksApp(tester, world, size: _tall);
    await chooseTab(tester, _l10n.bookmarksTabNotes);

    expect(shownAyat(tester), [2, 2]);
    expect(find.text('نص تجريبي'), findsOneWidget);
    expect(find.text('نص تجريبي ثان'), findsOneWidget);
    expect(find.text(_l10n.notesCount(2, arabicDigits(2))), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ثان');
    await tester.pumpAndSettle();
    expect(find.text('نص تجريبي ثان'), findsOneWidget);
    expect(find.text('نص تجريبي'), findsNothing);
  });

  testWidgets('deleting offers «تراجع», and undoing brings the card back', (
    tester,
  ) async {
    await world.bookmark(world.ayah(1, 3));
    await pumpBookmarksApp(tester, world);

    await tester.tap(button(_l10n.bookmarkDelete));
    await tester.pumpAndSettle();
    expect(find.byType(AnnotationCard), findsNothing);
    expect(find.text(_l10n.noBookmarksYet), findsOneWidget);
    expect(find.byType(UndoBar), findsOneWidget);
    expect(find.text(_l10n.itemDeleted), findsOneWidget);

    await tester.tap(find.text(_l10n.undo));
    await tester.pumpAndSettle();
    expect(find.byType(AnnotationCard), findsOneWidget);
    expect(find.byType(UndoBar), findsNothing);
  });

  testWidgets('the undo goes away on its own', (tester) async {
    await world.bookmark(world.ayah(1, 3));
    await pumpBookmarksApp(tester, world);

    await tester.tap(button(_l10n.bookmarkDelete));
    await tester.pumpAndSettle();
    expect(find.byType(UndoBar), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    expect(find.byType(UndoBar), findsNothing);
    expect(find.byType(AnnotationCard), findsNothing);
  });

  testWidgets('a note is deleted and undone from its own tab', (tester) async {
    await world.note(world.ayah(1, 3), 'نص تجريبي');
    await pumpBookmarksApp(tester, world);
    await chooseTab(tester, _l10n.bookmarksTabNotes);

    await tester.tap(button(_l10n.noteDelete));
    await tester.pumpAndSettle();
    expect(find.text(_l10n.noNotesYet), findsOneWidget);

    await tester.tap(find.text(_l10n.undo));
    await tester.pumpAndSettle();
    expect(find.text('نص تجريبي'), findsOneWidget);
  });

  testWidgets('a card opens the reader at its ayah, or the context sheet', (
    tester,
  ) async {
    await world.bookmark(world.ayah(2, 4));
    final router = await pumpBookmarksApp(tester, world);

    await tester.tap(button(_l10n.searchResultContext));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, Routes.contextSheet(world.ayah(2, 4)));
    router.pop();
    await tester.pumpAndSettle();

    await tester.tap(button(_l10n.searchResultOpen));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, Routes.mushafRead(world.ayah(2, 4)));
  });

  testWidgets('without a base pack a card has no ayah and no way to open it', (
    tester,
  ) async {
    await world.bookmark(world.ayah(2, 4));
    await pumpBookmarksApp(tester, world, withPack: false);

    expect(find.byType(AnnotationCard), findsOneWidget);
    expect(button(_l10n.searchResultOpen), findsNothing);
    expect(button(_l10n.searchResultContext), findsNothing);
    expect(button(_l10n.bookmarkDelete), findsOneWidget);
  });

  testWidgets('a bookmark changes its category from its tag', (tester) async {
    await world.bookmark(
      world.ayah(1, 3),
      category: BookmarksWorld.category('memorise'),
    );
    await pumpBookmarksApp(tester, world);

    // The card's own tag opens the sheet that changes it.
    await tester.tap(
      find
          .descendant(
            of: find.byType(AnnotationCard),
            matching: find.byType(Tag),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.byType(BookmarkTagsSheet), findsOneWidget);

    await tester.tap(
      find
          .descendant(
            of: find.byType(BookmarkTagsSheet),
            matching: find.text(_l10n.tagStudy),
          )
          .first,
    );
    await tester.pumpAndSettle();
    final stored = await world.bookmarks.bookmarkAt(world.ayah(1, 3));
    expect(
      (stored as Ok<Bookmark?>).value!.categoryId,
      BookmarksWorld.category('study'),
    );
  });

  testWidgets('a level change loses nothing', (tester) async {
    await world.bookmark(world.ayah(1, 3));
    await world.note(world.ayah(1, 4), 'نص تجريبي');
    await pumpBookmarksApp(tester, world);
    expect(find.byType(AnnotationCard), findsOneWidget);

    for (final level in [UiLevel.study, UiLevel.medium, UiLevel.simple]) {
      await changeLevel(tester, world, level);
      expect(find.byType(AnnotationCard), findsOneWidget);
    }
    await chooseTab(tester, _l10n.bookmarksTabNotes);
    expect(find.text('نص تجريبي'), findsOneWidget);
  });

  testWidgets('every control is at least 48 high and wide, and named', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await world.bookmark(world.ayah(1, 3));
    await pumpBookmarksApp(tester, world, size: _tall);

    for (final control in tester.widgetList<IconButton>(
      find.byType(IconButton),
    )) {
      final size = tester.getSize(find.byWidget(control));
      expect(size.width, greaterThanOrEqualTo(48), reason: control.label);
      expect(size.height, greaterThanOrEqualTo(48), reason: control.label);
      expect(control.label, isNotEmpty);
    }
    for (final tag in tester.widgetList<Tag>(find.byType(Tag))) {
      expect(
        tester.getSize(find.byWidget(tag)).height,
        greaterThanOrEqualTo(48),
        reason: tag.label,
      );
    }
    handle.dispose();
  });

  for (final theme in ReadingTheme.values) {
    testWidgets('lays out in ${theme.name} at 200% text without overflow', (
      tester,
    ) async {
      final tag = await world.makeTag('وسم تجريبي');
      await world.bookmark(
        world.ayah(2, 4),
        category: BookmarksWorld.category('important'),
        tagIds: {tag.id},
      );
      await world.note(world.ayah(1, 2), 'نص تجريبي', tagIds: {tag.id});
      await pumpBookmarksApp(tester, world, theme: theme, textScale: 2);
      expect(tester.takeException(), isNull);

      await chooseTab(tester, _l10n.bookmarksTabNotes);
      expect(tester.takeException(), isNull);
      await tester.tap(button(_l10n.noteDelete));
      await tester.pumpAndSettle();
      expect(find.byType(UndoBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
