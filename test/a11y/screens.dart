import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/features/mushaf/view_models/mushaf_view_model.dart';
import 'package:holyquran/ui/features/mushaf/views/mushaf_screen.dart';

import '../../testing/fakes/fake_app_settings_repository.dart';
import '../../testing/test_app.dart';
import '../ui/features/bookmarks/bookmarks_harness.dart';
import '../ui/features/home/home_harness.dart';
import '../ui/features/index/index_fixture.dart';
import '../ui/features/index/index_harness.dart';
import '../ui/features/mushaf/mushaf_harness.dart';
import '../ui/features/search/search_fixture.dart';
import '../ui/features/search/search_harness.dart';
import 'a11y_support.dart';

/// The synthetic packs and data the screens are drawn over, opened once per
/// test file.
final class A11yWorld {
  late final Directory _root;
  late final Directory _readerRoot;
  late final IndexFixture fixture;
  late final MushafRig rig;

  /// The view model of the reader screen last drawn.
  MushafViewModel? readerModel;

  Future<void> open() async {
    _root = await Directory.systemTemp.createTemp('a11y_index');
    _readerRoot = await Directory.systemTemp.createTemp('a11y_reader');
    fixture = await IndexFixture.load(_root);
    rig = await MushafRig.load(_readerRoot);
  }

  Future<void> close() async {
    fixture.close();
    rig.close();
    await _root.delete(recursive: true);
    await _readerRoot.delete(recursive: true);
  }

  Future<GoRouter> _more(
    WidgetTester tester,
    Size size,
    double textScale,
    String location, {
    AppSettingsRepository? settings,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final router = createRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(testApp(router, settings: settings));
    router.go(location);
    await tester.pumpAndSettle();
    return router;
  }

  Future<GoRouter> _bookmarks(
    WidgetTester tester,
    Size size,
    double textScale,
  ) async {
    final world = BookmarksWorld(fixture);
    addTearDown(world.bookmarks.dispose);
    addTearDown(world.notes.dispose);
    addTearDown(world.tags.dispose);
    addTearDown(world.settings.dispose);
    final tag = await world.makeTag('synthetic');
    await world.bookmark(world.ayah(1, 2), tagIds: {tag.id});
    await world.note(world.ayah(2, 1), 'synthetic note');
    return pumpBookmarksApp(tester, world, size: size, textScale: textScale);
  }

  /// The reader in surah mode, its ayat activatable, over the reader pack.
  Future<void> _reader(WidgetTester tester, Size size, double textScale) async {
    setReaderView(tester, size);
    final viewModel = rig.viewModel(address: QuranAddress('hafs', 2, 1));
    addTearDown(viewModel.dispose);
    readerModel = viewModel;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => SizedBox.fromSize(
            size: size,
            child: MushafScreen(
              key: ObjectKey(viewModel),
              viewModel: viewModel,
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(readerRouterApp(router, textScale: textScale));
    await tester.pumpAndSettle();
  }

  /// Every screen of a tab or a route, in a state that has data.
  List<A11yScreen> get screens => [
    (
      name: 'home',
      pump: (tester, size, textScale) => pumpHome(
        tester,
        size: size,
        textScale: textScale,
        last: syntheticAyah(),
      ),
    ),
    (
      name: 'mushaf',
      pump: (tester, size, textScale) =>
          pumpIndexApp(tester, fixture, size: size, textScale: textScale),
    ),
    (
      name: 'index',
      pump: (tester, size, textScale) => pumpIndexApp(
        tester,
        fixture,
        size: size,
        textScale: textScale,
        location: Routes.mushafIndex,
      ),
    ),
    (name: 'reader', pump: _reader),
    (
      name: 'listen',
      pump: (tester, size, textScale) async {
        final router = await pumpHome(
          tester,
          size: size,
          textScale: textScale,
          recitations: [listedRecitation()],
        );
        router.go(Routes.listen);
        await tester.pumpAndSettle();
      },
    ),
    (
      name: 'recitations',
      pump: (tester, size, textScale) async {
        final router = await pumpHome(
          tester,
          size: size,
          textScale: textScale,
          recitations: [listedRecitation()],
        );
        router.go(Routes.recitations);
        await tester.pumpAndSettle();
      },
    ),
    (
      name: 'study',
      pump: (tester, size, textScale) => pumpSearchApp(
        tester,
        fixture,
        search: searchFinding(const []),
        size: size,
        textScale: textScale,
        location: Routes.study,
      ),
    ),
    (
      name: 'search',
      pump: (tester, size, textScale) async {
        await pumpSearchApp(
          tester,
          fixture,
          search: searchFinding([hit(fixture, 1, 2), hit(fixture, 2, 1)]),
          size: size,
          textScale: textScale,
        );
        await tester.enterText(find.byType(TextField).first, query);
        await tester.pumpAndSettle();
      },
    ),
    (
      name: 'more',
      pump: (tester, size, textScale) =>
          _more(tester, size, textScale, Routes.more),
    ),
    (
      name: 'settings',
      pump: (tester, size, textScale) =>
          _more(tester, size, textScale, Routes.settings),
    ),
    (
      name: 'onboarding',
      pump: (tester, size, textScale) => _more(
        tester,
        size,
        textScale,
        Routes.onboarding,
        settings: FakeAppSettingsRepository(),
      ),
    ),
    (name: 'bookmarks', pump: _bookmarks),
  ];
}
