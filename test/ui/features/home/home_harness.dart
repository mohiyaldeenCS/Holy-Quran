import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/routing/routes/home_routes.dart';
import 'package:holyquran/routing/routes/listen_routes.dart';
import 'package:holyquran/routing/routes/more_routes.dart';
import 'package:holyquran/routing/routes/mushaf_routes.dart';
import 'package:holyquran/routing/routes/study_routes.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:provider/provider.dart';

import '../../../../testing/fakes/fake_quran_index_repository.dart';
import '../../../../testing/fakes/fake_reading_position_repository.dart';

/// An ayah of the synthetic index: surah 2 ayah 3, on page 3 of 4, juz 2.
QuranAddress syntheticAyah() => QuranAddress('hafs', 2, 3);

/// Stands in for the screens home opens, which other tasks build.
final _targets = FeatureRoutes(
  tabChildren: {
    ShellTab.mushaf: [
      GoRoute(path: RoutePaths.mushafIndex, builder: _target),
      GoRoute(path: RoutePaths.mushafRead, builder: _target),
    ],
    ShellTab.study: [GoRoute(path: RoutePaths.search, builder: _target)],
  },
);

Widget _target(BuildContext context, GoRouterState state) =>
    const SizedBox.shrink();

/// Pumps the app on its home tab, phone sized, with the synthetic index and
/// a reading position at [last], or none. Returns the router.
Future<GoRouter> pumpHome(
  WidgetTester tester, {
  QuranAddress? last,
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
  Size size = const Size(390, 844),
  bool withIndex = true,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final router = createRouter(
    features: [
      homeRoutes,
      mushafRoutes,
      listenRoutes,
      studyRoutes,
      moreRoutes,
      _targets,
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ReadingPositionRepository>(
          create: (context) => FakeReadingPositionRepository(last: last),
        ),
        if (withIndex)
          Provider<QuranIndexRepository>.value(
            value: FakeQuranIndexRepository.synthetic(),
          ),
      ],
      child: QuranApp(
        router: router,
        themePreference: ThemePreference(theme: theme),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}
