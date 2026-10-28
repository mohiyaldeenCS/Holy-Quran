import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/home_routes.dart';
import 'package:holyquran/routing/routes/listen_routes.dart';
import 'package:holyquran/routing/routes/more_routes.dart';
import 'package:holyquran/routing/routes/mushaf_routes.dart';
import 'package:holyquran/routing/routes/study_routes.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/ui/features/mushaf/view_models/mushaf_view_model.dart';
import 'package:holyquran/ui/features/mushaf/views/mushaf_screen.dart';
import 'package:provider/provider.dart';

import '../../testing/fakes/fake_app_settings_repository.dart';
import '../ui/features/mushaf/mushaf_harness.dart';

QuranAddress _at(int surah, int ayah) => QuranAddress('hafs', surah, ayah);

void main() {
  late Directory root;
  late MushafRig rig;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('mushaf_routes');
    rig = await MushafRig.load(root);
  });
  tearDownAll(() async {
    rig.close();
    await root.delete(recursive: true);
  });

  Future<GoRouter> pumpApp(WidgetTester tester, String location) async {
    setReaderView(tester);
    final router = createRouter(
      features: [
        homeRoutes,
        mushafRoutes,
        listenRoutes,
        studyRoutes,
        moreRoutes,
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppSettingsRepository>.value(
            value: FakeAppSettingsRepository(),
          ),
          Provider<QuranTextRepository>.value(value: rig.text),
          Provider<QuranIndexRepository>.value(value: rig.index),
          ListenableProvider<PackIntegrityRepository>.value(
            value: rig.integrity,
          ),
        ],
        child: QuranApp(router: router),
      ),
    );
    router.go(location);
    await tester.pumpAndSettle();
    return router;
  }

  MushafViewModel modelOf(WidgetTester tester) =>
      tester.widget<MushafScreen>(find.byType(MushafScreen)).viewModel;

  testWidgets('the mushaf tab opens the reader at the first ayah', (
    tester,
  ) async {
    await pumpApp(tester, Routes.mushaf);

    expect(modelOf(tester).status, ReaderStatus.ready);
    expect(modelOf(tester).anchor, _at(1, 1));
  });

  testWidgets('an address opens the reader there', (tester) async {
    final router = await pumpApp(tester, Routes.mushafRead(_at(2, 30)));

    expect(router.state.uri.path, '/mushaf/read/hafs:2:30');
    expect(find.byType(MushafScreen), findsOneWidget);
    expect(modelOf(tester).anchor, _at(2, 30));
  });

  testWidgets('a word address in the canonical form opens its ayah', (
    tester,
  ) async {
    await pumpApp(tester, '${Routes.mushaf}/read/hafs:2:30:2');

    expect(modelOf(tester).anchor, _at(2, 30));
  });

  testWidgets('a malformed address goes home', (tester) async {
    for (final address in ['hafs:0:1', 'hafs:٢:٢٥٥', 'hafs:2', 'x']) {
      final router = await pumpApp(tester, '${Routes.mushaf}/read/$address');

      expect(router.state.uri.path, Routes.home, reason: address);
      expect(find.byType(MushafScreen), findsNothing, reason: address);
    }
  });

  testWidgets('a well-formed address outside the edition opens the start', (
    tester,
  ) async {
    await pumpApp(tester, Routes.mushafRead(_at(400, 1)));

    expect(modelOf(tester).anchor, _at(1, 1));
  });
}
