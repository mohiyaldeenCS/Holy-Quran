import 'package:flutter/material.dart' hide RepeatMode, TabBar;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/domain/models/playback_plan.dart';
import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/playback_rules.dart';
import 'package:holyquran/domain/models/playback_segment.dart';
import 'package:holyquran/domain/models/player_state.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/domain/models/repeat_mode.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/shell_chrome.dart';
import 'package:holyquran/ui/core/tab_shell.dart';
import 'package:holyquran/ui/core/widgets/icon.dart' as ds;
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/mini_player.dart';
import 'package:holyquran/ui/core/widgets/tab_bar.dart';
import 'package:holyquran/ui/features/home/views/home_screen.dart';
import 'package:holyquran/ui/features/listen/views/listen_screen.dart';
import 'package:provider/provider.dart';
import '../../../testing/test_app.dart';

import '../../../testing/fakes/fake_player_repository.dart';
import '../../../testing/fakes/fake_quran_index_repository.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

final _labels = [
  _l10n.tabHome,
  _l10n.tabMushaf,
  _l10n.tabListen,
  _l10n.tabStudy,
  _l10n.tabMore,
];

Finder _tab(String label) =>
    find.descendant(of: find.byType(TabBar), matching: find.text(label));

/// Five branches `/b0` … `/b4`, each with a `sub` screen under it.
GoRouter _nestedRouter() => GoRouter(
  initialLocation: '/b0',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => ChangeNotifierProvider(
        create: (context) => ShellChrome(),
        child: TabShell(navigationShell: navigationShell),
      ),
      branches: [
        for (var i = 0; i < 5; i++)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/b$i',
                builder: (context, state) => const SizedBox.expand(),
                routes: [
                  GoRoute(
                    path: 'sub',
                    builder: (context, state) => const SizedBox.expand(),
                  ),
                ],
              ),
            ],
          ),
      ],
    ),
  ],
);

QuranAddress _at(int surah, int ayah) => QuranAddress('hafs', surah, ayah);

final _plan = PlaybackPlan(
  recitation: Recitation(
    id: 'synthetic-recitation',
    reciter: 'Synthetic reciter',
    riwaya: 'hafs',
    style: 'Synthetic style',
    unit: RecitationUnit.ayah,
    hasWordTiming: false,
    rightsComplete: true,
  ),
  range: FromAyahTool(_at(1, 1), AyahToolEnd.surah),
  repeat: RepeatMode(RepeatUnit.ayah, 3),
  silence: Duration.zero,
  continuesToNextSurah: false,
  hasAyahBoundaries: true,
  segments: const [],
);

final _playing = PlayerState(
  plan: _plan,
  segment: PlaybackSegment(
    kind: SegmentKind.ayah,
    address: _at(1, 2),
    source: AyahFile(_at(1, 2)),
    repeat: 1,
  ),
  segmentIndex: 0,
  ayah: _at(1, 2),
  playing: true,
);

/// The app with a player and the synthetic index, as the areas provide them
/// over a verified base pack.
Future<GoRouter> _pumpWithPlayer(
  WidgetTester tester,
  FakePlayerRepository player, {
  ReadingTheme theme = ReadingTheme.paper,
}) async {
  final router = createRouter();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ListenableProvider<PlayerRepository>.value(value: player),
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

Finder _playerButton(IconName icon) => find.descendant(
  of: find.byType(MiniPlayer),
  matching: find.byWidgetPredicate(
    (widget) => widget is PlayerButton && widget.icon == icon,
  ),
);

void main() {
  testWidgets('the shell shows the identity tab bar, not Material', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(createRouter()));
    await tester.pumpAndSettle();

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    final bar = tester.widget<TabBar>(find.byType(TabBar));
    expect(
      [for (final item in bar.items) item.icon],
      [
        IconName.home,
        IconName.mushaf,
        IconName.listen,
        IconName.study,
        IconName.more,
      ],
    );
    expect([for (final item in bar.items) item.label], _labels);
    expect(bar.currentIndex, 0);
    expect(
      find.descendant(of: find.byType(TabBar), matching: find.byType(ds.Icon)),
      findsNWidgets(5),
    );
  });

  testWidgets('the tab bar is named for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(testApp(createRouter()));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(_l10n.mainNavigationLabel), findsOneWidget);
      for (final (index, label) in _labels.indexed) {
        expect(
          tester.getSemantics(_tab(label)),
          matchesSemantics(
            label: label,
            isButton: true,
            hasSelectedState: true,
            isSelected: index == 0,
            isInMutuallyExclusiveGroup: true,
            isFocusable: true,
            hasTapAction: true,
            hasFocusAction: true,
          ),
          reason: label,
        );
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('every tab has a labelled hit area of at least 48', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(testApp(createRouter()));
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('the selected tab follows the branch', (tester) async {
    await tester.pumpWidget(testApp(createRouter()));
    await tester.pumpAndSettle();

    await tester.tap(_tab(_l10n.tabStudy));
    await tester.pumpAndSettle();

    expect(tester.widget<TabBar>(find.byType(TabBar)).currentIndex, 3);
  });

  testWidgets('tapping the current tab returns to its first screen', (
    tester,
  ) async {
    final router = _nestedRouter();
    await tester.pumpWidget(testApp(router));
    await tester.pumpAndSettle();

    router.go('/b1/sub');
    await tester.pumpAndSettle();
    await tester.tap(_tab(_l10n.tabHome));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/b0');

    await tester.tap(_tab(_l10n.tabMushaf));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/b1/sub');

    await tester.tap(_tab(_l10n.tabMushaf));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/b1');
  });

  testWidgets('hides the tab bar while the shell chrome says so', (
    tester,
  ) async {
    final router = createRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(testApp(router));
    await tester.pumpAndSettle();
    await tester.tap(_tab(_l10n.tabListen));
    await tester.pumpAndSettle();
    final chrome = Provider.of<ShellChrome>(
      tester.element(find.byType(ListenScreen)),
      listen: false,
    );

    chrome.tabBarVisible = false;
    await tester.pump();
    expect(find.byType(TabBar), findsNothing);
    expect(router.state.uri.path, Routes.listen);

    chrome.tabBarVisible = true;
    await tester.pump();
    expect(tester.widget<TabBar>(find.byType(TabBar)).currentIndex, 2);
  });

  testWidgets('a hidden tab bar leaves the screen the whole height', (
    tester,
  ) async {
    final router = createRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(testApp(router));
    await tester.pumpAndSettle();
    final withBar = tester.getSize(find.byType(HomeScreen)).height;

    Provider.of<ShellChrome>(
      tester.element(find.byType(HomeScreen)),
      listen: false,
    ).tabBarVisible = false;
    await tester.pump();

    expect(
      tester.getSize(find.byType(HomeScreen)).height,
      greaterThan(withBar),
    );
  });

  testWidgets('a hidden tab bar leaves the body its bottom inset', (
    tester,
  ) async {
    tester.view
      ..padding = const FakeViewPadding(bottom: 34)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pumpWithPlayer(tester, FakePlayerRepository());

    Provider.of<ShellChrome>(
      tester.element(find.byType(HomeScreen)),
      listen: false,
    ).tabBarVisible = false;
    await tester.pump();

    expect(
      MediaQuery.paddingOf(tester.element(find.byType(HomeScreen))).bottom,
      34,
    );
  });

  group('the mini player', () {
    testWidgets('is absent when the app has no player', (tester) async {
      await tester.pumpWidget(QuranApp(router: createRouter()));
      await tester.pumpAndSettle();

      expect(find.byType(MiniPlayer), findsNothing);
    });

    testWidgets('shows only while a recitation plays or is paused (LV-03)', (
      tester,
    ) async {
      final player = FakePlayerRepository();
      await _pumpWithPlayer(tester, player);
      expect(find.byType(MiniPlayer), findsNothing);

      player.state = _playing;
      await tester.pump();
      expect(find.byType(MiniPlayer), findsOneWidget);
      final mini = tester.widget<MiniPlayer>(find.byType(MiniPlayer));
      expect(mini.surah.verbatim, 'Synthetic surah 1');
      expect(mini.ayah, 2);
      expect(mini.reciter, 'Synthetic reciter');
      expect(mini.speed, '١٫٠×');
      expect(mini.repeat, 3);

      await player.pause();
      await tester.pump();
      expect(find.byType(MiniPlayer), findsOneWidget);

      await player.stop();
      await tester.pump();
      expect(find.byType(MiniPlayer), findsNothing);

      player.state = _playing.copyWith(stopReason: () => StopReason.endOfPlan);
      await tester.pump();
      expect(find.byType(MiniPlayer), findsNothing);
    });

    testWidgets('sits above the tab bar, and not on the listen tab', (
      tester,
    ) async {
      await _pumpWithPlayer(tester, FakePlayerRepository(state: _playing));
      expect(
        tester.getRect(find.byType(MiniPlayer)).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(TabBar)).top),
      );

      await tester.tap(_tab(_l10n.tabListen));
      await tester.pumpAndSettle();
      expect(find.byType(MiniPlayer), findsNothing);
    });

    testWidgets('stays while the tab bar is hidden', (tester) async {
      await _pumpWithPlayer(tester, FakePlayerRepository(state: _playing));

      Provider.of<ShellChrome>(
        tester.element(find.byType(HomeScreen)),
        listen: false,
      ).tabBarVisible = false;
      await tester.pump();

      expect(find.byType(TabBar), findsNothing);
      expect(find.byType(MiniPlayer), findsOneWidget);
    });

    testWidgets('its buttons call the player', (tester) async {
      final player = FakePlayerRepository(state: _playing);
      await _pumpWithPlayer(tester, player);

      await tester.tap(_playerButton(IconName.pause));
      await tester.pump();
      await tester.tap(_playerButton(IconName.play));
      await tester.tap(_playerButton(IconName.next));
      await tester.tap(_playerButton(IconName.previous));
      await tester.pump();

      expect(player.commands, ['pause', 'resume', 'nextAyah', 'previousAyah']);
    });

    testWidgets('lays out at 200% text without overflow', (tester) async {
      tester.view
        ..physicalSize = const Size(360, 740)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await _pumpWithPlayer(tester, FakePlayerRepository(state: _playing));

      expect(find.byType(MiniPlayer), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'matches the shell with the mini player in the four themes',
      tags: 'golden',
      (tester) async {
        tester.view
          ..physicalSize = const Size(390, 844)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        for (final theme in ReadingTheme.values) {
          await _pumpWithPlayer(
            tester,
            FakePlayerRepository(state: _playing),
            theme: theme,
          );
          await expectLater(
            find.byType(TabShell),
            matchesGoldenFile(
              'goldens/tab_shell_mini_player_${theme.name}.png',
            ),
          );
        }
      },
    );
  });
}
