import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/listening_position_repository.dart';
import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/data/repositories/recitation_repository.dart';
import 'package:holyquran/domain/models/catalogue_entry.dart';
import 'package:holyquran/domain/models/listening_position.dart';
import 'package:holyquran/domain/models/playback_plan_builder.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/routing/routes/home_routes.dart';
import 'package:holyquran/routing/routes/listen_routes.dart';
import 'package:holyquran/routing/routes/more_routes.dart';
import 'package:holyquran/routing/routes/mushaf_routes.dart';
import 'package:holyquran/routing/routes/study_routes.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/ui/features/home/view_models/home_view_model.dart';
import 'package:holyquran/ui/features/home/views/home_screen.dart';
import 'package:provider/provider.dart';

import '../../../../testing/fakes/fake_app_settings_repository.dart';
import '../../../../testing/fakes/fake_listening_position_repository.dart';
import '../../../../testing/fakes/fake_quran_index_repository.dart';
import '../../../../testing/fakes/fake_reading_position_repository.dart';
import '../../../../testing/fakes/fake_recitation_repository.dart';
import '../listen/controls/controls_harness.dart'
    show syntheticBuilder, syntheticRecitation;

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

/// Stands in for the bookmarks screen, which P1-24 builds.
final _bookmarks = FeatureRoutes(
  tabChildren: {
    ShellTab.more: [GoRoute(path: RoutePaths.bookmarks, builder: _target)],
  },
);

/// [recitation], by default the synthetic one, as the catalogue lists it.
CatalogueRecitation listedRecitation([Recitation? recitation]) =>
    CatalogueRecitation(
      recitation: recitation ?? syntheticRecitation(),
      qualities: const [64],
      packId: 'synthetic-recitation-pack',
    );

/// Where listening stopped, by default in the synthetic recitation.
ListeningPosition listenedAt(
  QuranAddress address, {
  Duration offset = Duration.zero,
  Recitation? recitation,
}) => ListeningPosition(
  address: address,
  recitationId: (recitation ?? syntheticRecitation()).id,
  offset: offset,
);

Widget _target(BuildContext context, GoRouterState state) =>
    const SizedBox.shrink();

/// Pumps the app on its home tab, phone sized, with the synthetic index and
/// a reading position at [last], or none. With [listened] it also has a
/// listening position, with [recitations] listed and a [player] over the
/// synthetic edition's plans. [bookmarks] gives the bookmarks door its
/// screen. [viewModel] replaces the one the home route builds, for what the
/// route cannot give it: a base pack that failed. Returns the router.
Future<GoRouter> pumpHome(
  WidgetTester tester, {
  QuranAddress? last,
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
  Size size = const Size(390, 844),
  bool withIndex = true,
  ListeningPosition? listened,
  List<CatalogueRecitation> recitations = const [],
  PlayerRepository? player,
  bool bookmarks = false,
  HomeViewModel? viewModel,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final router = createRouter(
    features: [
      if (viewModel == null)
        homeRoutes
      else
        FeatureRoutes(
          tabRoot: TabRoot(
            ShellTab.home,
            (context, state) => HomeScreen(viewModel: viewModel),
          ),
        ),
      mushafRoutes,
      listenRoutes,
      studyRoutes,
      moreRoutes,
      _targets,
      if (bookmarks) _bookmarks,
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettingsRepository>.value(
          value: FakeAppSettingsRepository(
            themePreference: ThemePreference(theme: theme),
          ),
        ),
        ChangeNotifierProvider<ReadingPositionRepository>(
          create: (context) => FakeReadingPositionRepository(last: last),
        ),
        if (withIndex)
          Provider<QuranIndexRepository>.value(
            value: FakeQuranIndexRepository.synthetic(),
          ),
        if (listened != null)
          ChangeNotifierProvider<ListeningPositionRepository>(
            create: (context) =>
                FakeListeningPositionRepository(last: listened),
          ),
        ListenableProvider<RecitationRepository>.value(
          value: FakeRecitationRepository(recitations),
        ),
        if (player != null) ...[
          ChangeNotifierProvider<PlayerRepository>.value(value: player),
          Provider<PlaybackPlanBuilder>.value(
            value: syntheticBuilder(FakeQuranIndexRepository.synthetic()),
          ),
        ],
      ],
      child: QuranApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// [pumpHome] over [viewModel]: the app's shell and theme around the home
/// screen.
Future<void> pumpHomeScreen(
  WidgetTester tester,
  HomeViewModel viewModel, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
  Size size = const Size(390, 844),
}) async {
  await pumpHome(
    tester,
    viewModel: viewModel,
    theme: theme,
    textScale: textScale,
    size: size,
  );
}
