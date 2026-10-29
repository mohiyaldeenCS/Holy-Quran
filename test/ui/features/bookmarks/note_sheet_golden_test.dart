@Tags(['golden'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/routing/routes/note_location.dart';

import '../index/index_fixture.dart';
import 'bookmarks_harness.dart';

// Tall enough for the whole sheet.
const _tall = Size(390, 1500);

void main() {
  late Directory root;
  late IndexFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('note_sheet_golden');
    fixture = await IndexFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  for (final theme in ReadingTheme.values) {
    testWidgets('the note sheet on a saved note in ${theme.name}', (
      tester,
    ) async {
      final world = BookmarksWorld(fixture);
      final tag = await world.makeTag('وسم تجريبي');
      await world.note(world.ayah(1, 2), 'نص أول');
      final second = await world.note(
        world.ayah(1, 2),
        'نص تجريبي',
        category: BookmarksWorld.category('review'),
        tagIds: {tag.id},
      );
      final router = await pumpBookmarksApp(
        tester,
        world,
        theme: theme,
        size: _tall,
      );
      unawaited(
        router.push(noteSheetLocation(world.ayah(1, 2), noteId: second.id)),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/note_sheet_${theme.name}.png'),
      );
    });
  }
}
