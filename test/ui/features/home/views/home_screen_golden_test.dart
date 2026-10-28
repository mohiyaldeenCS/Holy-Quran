@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';

import '../home_harness.dart';

void main() {
  for (final theme in ReadingTheme.values) {
    testWidgets('home on first run in ${theme.name}', (tester) async {
      await pumpHome(tester, theme: theme);
      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/home_screen_first_run_${theme.name}.png'),
      );
    });

    testWidgets('home with a reading position in ${theme.name}', (
      tester,
    ) async {
      await pumpHome(tester, theme: theme, last: syntheticAyah());
      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/home_screen_${theme.name}.png'),
      );
    });
  }
}
