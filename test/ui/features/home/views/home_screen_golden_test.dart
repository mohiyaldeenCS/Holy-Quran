@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/features/home/view_models/home_view_model.dart';

import '../../../../../testing/fakes/fake_pack_integrity_repository.dart';
import '../../../../../testing/fakes/fake_player_repository.dart';
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

    testWidgets('home with listening and both doors in ${theme.name}', (
      tester,
    ) async {
      await pumpHome(
        tester,
        theme: theme,
        last: syntheticAyah(),
        listened: listenedAt(syntheticAyah()),
        recitations: [listedRecitation()],
        player: FakePlayerRepository(),
        bookmarks: true,
      );
      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/home_screen_listening_${theme.name}.png'),
      );
    });

    testWidgets('home with the integrity alert in ${theme.name}', (
      tester,
    ) async {
      await pumpHomeScreen(
        tester,
        HomeViewModel(
          integrity: FakePackIntegrityRepository({
            'base': const IntegrityFailed(PackInconsistent('base', 'x')),
          }),
          basePackId: 'base',
        ),
        theme: theme,
      );
      await expectLater(
        find.byType(WidgetsApp),
        matchesGoldenFile('goldens/home_screen_integrity_${theme.name}.png'),
      );
    });
  }
}
