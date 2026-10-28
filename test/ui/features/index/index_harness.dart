import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/domain/models/quran_structure.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:provider/provider.dart';

import '../../../../testing/fakes/fake_app_settings_repository.dart';
import '../../../../testing/fakes/fake_reading_position_repository.dart';
import 'index_fixture.dart';

/// Pumps the app on its mushaf tab, phone sized, over [fixture] and a reading
/// position at [last], with the index feature's routes. Returns the router.
Future<GoRouter> pumpIndexApp(
  WidgetTester tester,
  IndexFixture fixture, {
  FakeReadingPositionRepository? positions,
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
  Size size = const Size(390, 844),
  String location = Routes.mushaf,
  bool withPack = true,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final router = createRouter(features: appFeatures);
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
          value: positions ?? FakeReadingPositionRepository(),
        ),
        if (withPack) ...[
          Provider<QuranIndexRepository>.value(value: fixture.index),
          Provider<QuranStructure>.value(value: fixture.index),
          Provider<QuranTextRepository>.value(value: fixture.text),
        ],
      ],
      child: QuranApp(router: router),
    ),
  );
  router.go(location);
  await tester.pumpAndSettle();
  return router;
}
