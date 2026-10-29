@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/widgets/level_switch.dart';

import '../index/index_fixture.dart';
import 'bookmarks_harness.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

void main() {
  late Directory root;
  late IndexFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('bookmarks_screen_golden');
    fixture = await IndexFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  Future<void> fill(BookmarksWorld world) async {
    final tag = await world.makeTag('وسم تجريبي');
    await world.bookmark(
      world.ayah(2, 4),
      category: BookmarksWorld.category('important'),
      tagIds: {tag.id},
    );
    await world.bookmark(
      world.ayah(1, 2),
      category: BookmarksWorld.category('memorise'),
    );
    await world.note(
      world.ayah(1, 3),
      'نص تجريبي',
      category: BookmarksWorld.category('study'),
      tagIds: {tag.id},
    );
  }

  for (final theme in ReadingTheme.values) {
    testWidgets('the bookmarks in ${theme.name}', (tester) async {
      final world = BookmarksWorld(fixture);
      await fill(world);
      await pumpBookmarksApp(tester, world, theme: theme);
      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/bookmarks_${theme.name}.png'),
      );
    });

    testWidgets('the notes in ${theme.name}', (tester) async {
      final world = BookmarksWorld(fixture);
      await fill(world);
      await pumpBookmarksApp(tester, world, theme: theme);
      await tester.tap(
        find.descendant(
          of: find.byType(LevelSwitch),
          matching: find.text(_l10n.bookmarksTabNotes),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/notes_${theme.name}.png'),
      );
    });

    testWidgets('the empty list in ${theme.name}', (tester) async {
      await pumpBookmarksApp(tester, BookmarksWorld(fixture), theme: theme);
      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/bookmarks_empty_${theme.name}.png'),
      );
    });
  }
}
