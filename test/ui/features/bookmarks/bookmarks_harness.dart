import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/bookmark_repository.dart';
import 'package:holyquran/data/repositories/category_repository.dart';
import 'package:holyquran/data/repositories/note_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/repositories/tag_repository.dart';
import 'package:holyquran/domain/models/bookmark.dart';
import 'package:holyquran/domain/models/note.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_structure.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/ui_level.dart';
import 'package:holyquran/domain/models/user_tag.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/utils/result.dart';
import 'package:provider/provider.dart';

import '../../../../testing/fakes/fake_app_settings_repository.dart';
import '../../../../testing/fakes/fake_bookmark_repository.dart';
import '../../../../testing/fakes/fake_category_repository.dart';
import '../../../../testing/fakes/fake_note_repository.dart';
import '../../../../testing/fakes/fake_tag_repository.dart';
import '../index/index_fixture.dart';

/// The user's data in memory, with helpers that keep the tags' names the
/// searches look in equal to the tags'.
final class BookmarksWorld {
  BookmarksWorld(this.fixture);

  final IndexFixture fixture;
  final bookmarks = FakeBookmarkRepository();
  final notes = FakeNoteRepository();
  final tags = FakeTagRepository();
  final categories = FakeCategoryRepository();
  final settings = FakeAppSettingsRepository();

  /// The id the fake category repository gives the category [name].
  static String category(String name) => 'fake-$name';

  QuranAddress ayah(int surah, int ayah) =>
      QuranAddress(fixture.index.riwaya, surah, ayah);

  Future<UserTag> makeTag(String name) async {
    final tag = (await tags.create(name) as Ok<UserTag>).value;
    final names = {...bookmarks.tagNames, tag.id: tag.name};
    bookmarks.tagNames = names;
    notes.tagNames = names;
    return tag;
  }

  Future<Bookmark> bookmark(
    QuranAddress at, {
    String category = 'fake-memorise',
    Set<String> tagIds = const {},
  }) async {
    final made = (await bookmarks.add(at, category) as Ok<Bookmark>).value;
    if (tagIds.isNotEmpty) await bookmarks.setTags(made.id, tagIds);
    return made;
  }

  Future<Note> note(
    QuranAddress at,
    String body, {
    String? category,
    Set<String> tagIds = const {},
  }) async =>
      (await notes.add(at, body, categoryId: category, tagIds: tagIds)
              as Ok<Note>)
          .value;
}

/// Pumps the app, phone sized, over [world]'s data and pack, and goes to
/// [location]. Returns the router.
Future<GoRouter> pumpBookmarksApp(
  WidgetTester tester,
  BookmarksWorld world, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
  Size size = const Size(390, 844),
  String location = Routes.bookmarks,
  bool withPack = true,
  bool withUserData = true,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  world.settings.themePreference = ThemePreference(theme: theme);
  final router = createRouter(features: appFeatures);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettingsRepository>.value(
          value: world.settings,
        ),
        if (withUserData) ...[
          ChangeNotifierProvider<BookmarkRepository>.value(
            value: world.bookmarks,
          ),
          ChangeNotifierProvider<NoteRepository>.value(value: world.notes),
          ChangeNotifierProvider<TagRepository>.value(value: world.tags),
          Provider<CategoryRepository>.value(value: world.categories),
        ],
        if (withPack) ...[
          Provider<QuranIndexRepository>.value(value: world.fixture.index),
          Provider<QuranStructure>.value(value: world.fixture.index),
          Provider<QuranTextRepository>.value(value: world.fixture.text),
        ],
      ],
      child: QuranApp(router: router),
    ),
  );
  router.go(location);
  await tester.pumpAndSettle();
  return router;
}

/// Changes the interface level while the app runs.
Future<void> changeLevel(
  WidgetTester tester,
  BookmarksWorld world,
  UiLevel level,
) async {
  await world.settings.setLevel(level);
  await tester.pumpAndSettle();
}
