import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/routing/routes/home_routes.dart';
import 'package:holyquran/routing/routes/listen_routes.dart';
import 'package:holyquran/routing/routes/more_routes.dart';
import 'package:holyquran/routing/routes/study_routes.dart';
import 'package:holyquran/routing/startup_redirect.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:provider/provider.dart';

import '../../testing/fakes/fake_app_settings_repository.dart';
import '../../testing/fakes/fake_quran_index_repository.dart';
import '../../testing/fakes/fake_reading_position_repository.dart';

QuranAddress _at(int surah, int ayah) => QuranAddress('hafs', surah, ayah);

Widget _stub(BuildContext context, GoRouterState state) =>
    const SizedBox.shrink();

// The reader is another feature's; here it is only a place to land.
final _reader = FeatureRoutes(
  tabRoot: const TabRoot(ShellTab.mushaf, _stub),
  tabChildren: {
    ShellTab.mushaf: [GoRoute(path: RoutePaths.mushafRead, builder: _stub)],
  },
);

Future<GoRouter> _start(
  WidgetTester tester, {
  bool open = true,
  QuranAddress? last,
  bool withIndex = true,
}) async {
  final router = createRouter(
    features: [homeRoutes, _reader, listenRoutes, studyRoutes, moreRoutes],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettingsRepository>.value(
          value: FakeAppSettingsRepository(openAtLastPosition: open),
        ),
        ChangeNotifierProvider<ReadingPositionRepository>.value(
          value: FakeReadingPositionRepository(last: last),
        ),
        if (withIndex)
          Provider<QuranIndexRepository>.value(
            value: FakeQuranIndexRepository.synthetic(),
          ),
      ],
      child: QuranApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  group('opening at the last position (RD-13)', () {
    testWidgets(
      'starts in the reader at the saved ayah when the setting is on',
      (tester) async {
        final router = await _start(tester, last: _at(2, 3));

        expect(router.state.uri.path, Routes.mushafRead(_at(2, 3)));
      },
    );

    testWidgets('starts on home when the setting is off', (tester) async {
      final router = await _start(tester, open: false, last: _at(2, 3));

      expect(router.state.uri.path, Routes.home);
    });

    testWidgets('starts on home when no position was saved', (tester) async {
      final router = await _start(tester);

      expect(router.state.uri.path, Routes.home);
    });

    testWidgets('starts on home when the pack serves no text', (tester) async {
      final router = await _start(tester, last: _at(2, 3), withIndex: false);

      expect(router.state.uri.path, Routes.home);
    });

    testWidgets('starts on home when the position is not in the pack', (
      tester,
    ) async {
      final router = await _start(tester, last: _at(2, 9));

      expect(router.state.uri.path, Routes.home);
    });

    testWidgets('looks at the first location of the run only', (tester) async {
      final router = await _start(tester, last: _at(2, 3));

      router.go(Routes.home);
      await tester.pumpAndSettle();

      expect(router.state.uri.path, Routes.home);
    });

    testWidgets('keeps a location that is not home, such as a link', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: Routes.more,
        redirect: startupRedirect,
        routes: [
          for (final path in [Routes.home, Routes.more, Routes.mushaf])
            GoRoute(path: path, builder: _stub),
          GoRoute(path: '/mushaf/read/:address', builder: _stub),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppSettingsRepository>.value(
              value: FakeAppSettingsRepository(openAtLastPosition: true),
            ),
            ChangeNotifierProvider<ReadingPositionRepository>.value(
              value: FakeReadingPositionRepository(last: _at(2, 3)),
            ),
            Provider<QuranIndexRepository>.value(
              value: FakeQuranIndexRepository.synthetic(),
            ),
          ],
          child: QuranApp(router: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(router.state.uri.path, Routes.more);
    });
  });
}
