import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/address_input_repository.dart';
import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/data/repositories/search_history_repository.dart';
import 'package:holyquran/data/repositories/search_repository.dart';
import 'package:holyquran/domain/models/quran_structure.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/search_hit.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:provider/provider.dart';

import '../../../../testing/fakes/fake_address_input_repository.dart';
import '../../../../testing/fakes/fake_app_settings_repository.dart';
import '../../../../testing/fakes/fake_pack_integrity_repository.dart';
import '../../../../testing/fakes/fake_reading_position_repository.dart';
import '../../../../testing/fakes/fake_search_history_repository.dart';
import '../../../../testing/fakes/fake_search_repository.dart';
import '../index/index_fixture.dart';
import 'search_fixture.dart';

/// The app on [location], phone sized, over [fixture]'s pack and the fakes
/// the search screen reads. Returns the router.
Future<GoRouter> pumpSearchApp(
  WidgetTester tester,
  IndexFixture fixture, {
  required FakeSearchRepository search,
  FakeSearchHistoryRepository? history,
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
  Size size = const Size(390, 844),
  String location = Routes.search,
  bool withPack = true,
  List<FeatureRoutes>? features,
  FakePackIntegrityRepository? integrity,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final router = createRouter(features: features ?? appFeatures);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettingsRepository>.value(
          value: FakeAppSettingsRepository(
            themePreference: ThemePreference(theme: theme),
          ),
        ),
        ChangeNotifierProvider<ReadingPositionRepository>.value(
          value: FakeReadingPositionRepository(),
        ),
        if (withPack) ...[
          Provider<QuranIndexRepository>.value(value: fixture.index),
          Provider<QuranStructure>.value(value: fixture.index),
          Provider<QuranTextRepository>.value(value: fixture.text),
          Provider<SearchRepository>.value(value: search),
          Provider<AddressInputRepository>.value(
            value: FakeAddressInputRepository(),
          ),
        ],
        if (integrity != null)
          ListenableProvider<PackIntegrityRepository>.value(value: integrity),
        ChangeNotifierProvider<SearchHistoryRepository>.value(
          value: history ?? FakeSearchHistoryRepository(),
        ),
      ],
      child: QuranApp(router: router),
    ),
  );
  router.go(location);
  await tester.pumpAndSettle();
  return router;
}

/// A fake search that finds [hits] for [query].
FakeSearchRepository searchFinding(List<SearchHit> hits) =>
    FakeSearchRepository(kinds: const ['word', 'bare'], hits: {query: hits});
