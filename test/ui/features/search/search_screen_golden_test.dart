@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';

import '../../../../testing/fakes/fake_search_history_repository.dart';
import '../index/index_fixture.dart';
import 'search_fixture.dart';
import 'search_harness.dart';

void main() {
  late Directory root;
  late IndexFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('search_screen_golden_test');
    fixture = await IndexFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  for (final theme in ReadingTheme.values) {
    testWidgets('the results, one with two matches and a long one, in '
        '${theme.name}', (tester) async {
      await pumpSearchApp(
        tester,
        fixture,
        theme: theme,
        search: searchFinding([
          hit(fixture, 2, 3, ranges: [(2, 3), (5, 5)]),
          hit(fixture, 2, 12),
          hit(fixture, 3, 1),
        ]),
      );
      await tester.enterText(find.byType(TextField).first, query);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/search_results_${theme.name}.png'),
      );
    });

    testWidgets('the history under the empty field in ${theme.name}', (
      tester,
    ) async {
      await pumpSearchApp(
        tester,
        fixture,
        theme: theme,
        search: searchFinding(const []),
        history: FakeSearchHistoryRepository(['one', 'two']),
      );

      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/search_history_${theme.name}.png'),
      );
    });
  }
}
