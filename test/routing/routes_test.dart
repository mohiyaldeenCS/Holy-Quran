import 'package:flutter/material.dart' hide TabBar;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/routing/routes/home_routes.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/ui/core/widgets/tab_bar.dart';
import 'package:holyquran/ui/features/home/views/home_screen.dart';
import 'package:holyquran/ui/features/listen/views/listen_screen.dart';
import 'package:holyquran/ui/features/more/views/more_screen.dart';
import 'package:holyquran/ui/features/mushaf/views/mushaf_screen.dart';
import 'package:holyquran/ui/features/study/views/study_screen.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

final _addresses = [
  QuranAddress('hafs', 1, 1),
  QuranAddress('hafs', 2, 255),
  QuranAddress('hafs', 2, 255, 3),
  QuranAddress('warsh', 114, 6),
  QuranAddress('qalun_2', 9, 129, 12),
];

final _arabicIndicDigits = RegExp('[٠-٩۰-۹]');

/// A location, the route pattern it must match, and what it carries.
typedef _Case = ({
  String location,
  String pattern,
  QuranAddress? address,
  int? surah,
  String? pack,
});

_Case _case(
  String location,
  String pattern, {
  QuranAddress? address,
  int? surah,
  String? pack,
}) => (
  location: location,
  pattern: pattern,
  address: address,
  surah: surah,
  pack: pack,
);

List<_Case> _cases() => [
  _case(Routes.home, Routes.home),
  _case(Routes.mushaf, Routes.mushaf),
  _case(Routes.mushafIndex, Routes.mushafIndex),
  _case(Routes.listen, Routes.listen),
  _case(Routes.recitations, Routes.recitations),
  _case(Routes.study, Routes.study),
  _case(Routes.search, Routes.search),
  _case(Routes.more, Routes.more),
  _case(Routes.bookmarks, Routes.bookmarks),
  _case(Routes.resources, Routes.resources),
  _case(Routes.settings, Routes.settings),
  _case(Routes.sources, Routes.sources),
  _case(Routes.onboarding, Routes.onboarding),
  _case(Routes.gallery, Routes.gallery),
  for (final (location, pattern) in [
    (Routes.goToSheet, RoutePaths.goToSheet),
    (Routes.rangeSheet, RoutePaths.rangeSheet),
    (Routes.repeatSheet, RoutePaths.repeatSheet),
    (Routes.silenceSheet, RoutePaths.silenceSheet),
    (Routes.stopAfterSheet, RoutePaths.stopAfterSheet),
    (Routes.sleepSheet, RoutePaths.sleepSheet),
    (Routes.queueSheet, RoutePaths.queueSheet),
    (Routes.firstUseTafsirSheet, RoutePaths.firstUseTafsirSheet),
  ])
    _case(location, pattern),
  for (final address in _addresses) ...[
    _case(
      Routes.mushafRead(address),
      '${Routes.mushaf}/${RoutePaths.mushafRead}',
      address: address,
    ),
    _case(
      Routes.studyTafsir(address),
      '${Routes.study}/${RoutePaths.studyTafsir}',
      address: address,
    ),
    for (final (build, pattern) in [
      (Routes.contextSheet, RoutePaths.contextSheet),
      (Routes.wordSheet, RoutePaths.wordSheet),
      (Routes.ayahSheet, RoutePaths.ayahSheet),
      (Routes.tafsirSheet, RoutePaths.tafsirSheet),
      (Routes.copySheet, RoutePaths.copySheet),
      (Routes.shareSheet, RoutePaths.shareSheet),
      (Routes.noteSheet, RoutePaths.noteSheet),
      (Routes.playOptionsSheet, RoutePaths.playOptionsSheet),
      (Routes.reportSheet, RoutePaths.reportSheet),
    ])
      _case(build(address), pattern, address: address),
    _case(
      Routes.reportSheet(address, pack: 'tafsir.synthetic'),
      RoutePaths.reportSheet,
      address: address,
      pack: 'tafsir.synthetic',
    ),
  ],
  for (final surah in [1, 2, 114])
    _case(
      Routes.surahInfoSheet(surah),
      RoutePaths.surahInfoSheet,
      surah: surah,
    ),
];

/// A router with one plain route per pattern of [Routes], nested as in the
/// app: screens of a tab under its root, sheets at the top.
GoRouter _patternRouter() {
  GoRoute leaf(String path) =>
      GoRoute(path: path, builder: (context, state) => const SizedBox.expand());
  GoRoute tab(String path, List<String> children) => GoRoute(
    path: path,
    builder: (context, state) => const SizedBox.expand(),
    routes: [for (final child in children) leaf(child)],
  );
  return GoRouter(
    initialLocation: Routes.home,
    routes: [
      tab(Routes.home, []),
      tab(Routes.mushaf, [RoutePaths.mushafRead, RoutePaths.mushafIndex]),
      tab(Routes.listen, [RoutePaths.recitations]),
      tab(Routes.study, [RoutePaths.search, RoutePaths.studyTafsir]),
      tab(Routes.more, [
        RoutePaths.bookmarks,
        RoutePaths.resources,
        RoutePaths.settings,
        RoutePaths.sources,
      ]),
      leaf(Routes.onboarding),
      leaf(Routes.gallery),
      for (final sheet in [
        RoutePaths.goToSheet,
        RoutePaths.contextSheet,
        RoutePaths.wordSheet,
        RoutePaths.ayahSheet,
        RoutePaths.surahInfoSheet,
        RoutePaths.tafsirSheet,
        RoutePaths.copySheet,
        RoutePaths.shareSheet,
        RoutePaths.noteSheet,
        RoutePaths.playOptionsSheet,
        RoutePaths.rangeSheet,
        RoutePaths.repeatSheet,
        RoutePaths.silenceSheet,
        RoutePaths.stopAfterSheet,
        RoutePaths.sleepSheet,
        RoutePaths.queueSheet,
        RoutePaths.firstUseTafsirSheet,
        RoutePaths.reportSheet,
      ])
        leaf(sheet),
    ],
  );
}

const _sheetKey = Key('synthetic sheet');
const _childKey = Key('synthetic child');
const _syntheticSheet = '/sheet/synthetic/:${Routes.addressParameter}';
const _syntheticChild = 'synthetic';

String _syntheticSheetAt(QuranAddress address) => '/sheet/synthetic/$address';

/// A feature that adds a sheet owned by the reader at its address, and a
/// child screen under every tab.
final _synthetic = FeatureRoutes(
  sheets: [
    SheetRoute(
      path: _syntheticSheet,
      builder: (context, state) => const SizedBox(key: _sheetKey, height: 120),
      owner: (state) => Routes.mushafRead(Routes.addressOf(state)!),
    ),
  ],
  tabChildren: {
    for (final tab in ShellTab.values)
      tab: [
        GoRoute(
          path: _syntheticChild,
          builder: (context, state) => const SizedBox.expand(key: _childKey),
        ),
      ],
  },
);

final _tabs = <({String label, ShellTab tab, Type screen})>[
  (label: _l10n.tabHome, tab: ShellTab.home, screen: HomeScreen),
  (label: _l10n.tabMushaf, tab: ShellTab.mushaf, screen: MushafScreen),
  (label: _l10n.tabListen, tab: ShellTab.listen, screen: ListenScreen),
  (label: _l10n.tabStudy, tab: ShellTab.study, screen: StudyScreen),
  (label: _l10n.tabMore, tab: ShellTab.more, screen: MoreScreen),
];

Finder _tab(String label) =>
    find.descendant(of: find.byType(TabBar), matching: find.text(label));

Future<GoRouter> _pumpApp(
  WidgetTester tester, {
  List<FeatureRoutes>? features,
}) async {
  final router = createRouter(features: features);
  addTearDown(router.dispose);
  await tester.pumpWidget(QuranApp(router: router));
  await tester.pumpAndSettle();
  return router;
}

/// Starts the app as the platform would at [location].
Future<GoRouter> _coldStart(
  WidgetTester tester,
  String location, {
  List<FeatureRoutes>? features,
}) {
  tester.platformDispatcher.defaultRouteNameTestValue = location;
  addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
  return _pumpApp(tester, features: features);
}

void _expectHome(WidgetTester tester, GoRouter router) {
  expect(router.state.uri.path, Routes.home);
  expect(find.byType(HomeScreen), findsOneWidget);
  expect(find.textContaining('Page Not Found'), findsNothing);
  expect(find.textContaining('GoException'), findsNothing);
}

void main() {
  group('every location builder', () {
    testWidgets('round-trips through the route it is built for', (
      tester,
    ) async {
      final router = _patternRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      for (final expected in _cases()) {
        router.go(expected.location);
        await tester.pumpAndSettle();

        final state = router.state;
        final reason = expected.location;
        expect(state.fullPath, expected.pattern, reason: reason);
        expect(state.uri.toString(), expected.location, reason: reason);
        expect(Routes.addressOf(state), expected.address, reason: reason);
        expect(Routes.surahOf(state), expected.surah, reason: reason);
        expect(Routes.packOf(state), expected.pack, reason: reason);
      }
    });

    test('writes ASCII digits only', () {
      for (final expected in _cases()) {
        expect(
          expected.location,
          isNot(contains(_arabicIndicDigits)),
          reason: expected.location,
        );
      }
    });

    test('writes the canonical address', () {
      final address = QuranAddress('hafs', 2, 255, 3);
      expect(Routes.mushafRead(address), '/mushaf/read/hafs:2:255:3');
      expect(
        Routes.reportSheet(address, pack: 'tafsir.synthetic'),
        '/sheet/report/hafs:2:255:3?pack=tafsir.synthetic',
      );
    });

    test('refuses a surah that is not positive', () {
      expect(() => Routes.surahInfoSheet(0), throwsArgumentError);
    });
  });

  group('a location that matches no route', () {
    for (final location in ['/nowhere', '/mushaf/nowhere', '/sheet/nowhere']) {
      testWidgets('$location lands on the home tab', (tester) async {
        final router = await _pumpApp(tester);
        await tester.tap(_tab(_l10n.tabStudy));
        await tester.pumpAndSettle();

        router.go(location);
        await tester.pumpAndSettle();

        _expectHome(tester, router);
      });
    }

    testWidgets('lands on the home tab at a cold start', (tester) async {
      final router = await _coldStart(tester, '/nowhere');

      _expectHome(tester, router);
    });

    testWidgets('a route not built yet lands on the home tab', (tester) async {
      final router = await _pumpApp(tester);

      router.go(Routes.settings);
      await tester.pumpAndSettle();

      _expectHome(tester, router);
    });

    for (final location in [
      '/sheet/synthetic/hafs:0:1',
      '/sheet/synthetic/hafs:٢:٢٥٥',
      '/sheet/synthetic/hafs:2',
    ]) {
      testWidgets('a malformed address in $location lands home', (
        tester,
      ) async {
        final router = await _pumpApp(tester, features: _appAnd());

        router.go(location);
        await tester.pumpAndSettle();

        _expectHome(tester, router);
        expect(find.byKey(_sheetKey), findsNothing);
      });
    }
  });

  group('a sheet', () {
    for (final tab in _tabs) {
      testWidgets('opens over ${tab.tab.name} and closes back to it', (
        tester,
      ) async {
        final router = await _pumpApp(tester, features: _appAnd());
        await tester.tap(_tab(tab.label));
        await tester.pumpAndSettle();
        final address = QuranAddress('hafs', 2, 255);

        final closed = router.push<Object?>(_syntheticSheetAt(address));
        await tester.pumpAndSettle();

        expect(find.byKey(_sheetKey), findsOneWidget);
        expect(
          ModalRoute.of(tester.element(find.byKey(_sheetKey))),
          isA<ModalBottomSheetRoute<Object?>>(),
        );
        expect(find.byType(tab.screen), findsOneWidget);
        expect(find.byType(TabBar), findsOneWidget);

        router.pop('synthetic result');
        await tester.pumpAndSettle();

        expect(await closed, 'synthetic result');
        expect(find.byKey(_sheetKey), findsNothing);
        expect(router.state.uri.path, tab.tab.path);
        expect(find.byType(tab.screen), findsOneWidget);
      });
    }

    testWidgets('a cold start at its path goes to the screen it belongs to', (
      tester,
    ) async {
      final address = QuranAddress('hafs', 2, 255);
      final owned = FeatureRoutes(
        sheets: [
          SheetRoute(
            path: _syntheticSheet,
            builder: (context, state) => const SizedBox(key: _sheetKey),
            owner: (state) => Routes.study,
          ),
        ],
      );

      final router = await _coldStart(
        tester,
        _syntheticSheetAt(address),
        features: [...appFeatures, owned],
      );

      expect(router.state.uri.path, Routes.study);
      expect(find.byType(StudyScreen), findsOneWidget);
      expect(find.byKey(_sheetKey), findsNothing);
    });
  });

  testWidgets('a child screen keeps its branch stack across tab switches', (
    tester,
  ) async {
    final router = await _pumpApp(tester, features: _appAnd());

    for (final tab in _tabs.skip(1)) {
      await tester.tap(_tab(tab.label));
      await tester.pumpAndSettle();
      router.go('${tab.tab.path}/$_syntheticChild');
      await tester.pumpAndSettle();
      expect(find.byKey(_childKey), findsOneWidget, reason: tab.label);

      await tester.tap(_tab(_l10n.tabHome));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, Routes.home, reason: tab.label);
      expect(find.byKey(_childKey), findsNothing, reason: tab.label);

      await tester.tap(_tab(tab.label));
      await tester.pumpAndSettle();
      expect(
        router.state.uri.path,
        '${tab.tab.path}/$_syntheticChild',
        reason: tab.label,
      );
      expect(find.byKey(_childKey), findsOneWidget, reason: tab.label);

      router.pop();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, tab.tab.path, reason: tab.label);
      expect(find.byType(tab.screen), findsOneWidget, reason: tab.label);
    }
  });

  test('every tab has exactly one first screen', () {
    expect(
      () => createRouter(features: [...appFeatures, homeRoutes]),
      throwsStateError,
    );
  });
}

List<FeatureRoutes> _appAnd() => [...appFeatures, _synthetic];
