import 'package:flutter/material.dart' hide TabBar;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/ui/core/shell_chrome.dart';
import 'package:holyquran/ui/core/tab_shell.dart';
import 'package:holyquran/ui/core/widgets/icon.dart' as ds;
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/tab_bar.dart';
import 'package:holyquran/ui/features/home/views/home_screen.dart';
import 'package:provider/provider.dart';

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

void main() {
  testWidgets('the shell shows the identity tab bar, not Material', (
    tester,
  ) async {
    await tester.pumpWidget(QuranApp(router: createRouter()));
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
      await tester.pumpWidget(QuranApp(router: createRouter()));
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
      await tester.pumpWidget(QuranApp(router: createRouter()));
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('the selected tab follows the branch', (tester) async {
    await tester.pumpWidget(QuranApp(router: createRouter()));
    await tester.pumpAndSettle();

    await tester.tap(_tab(_l10n.tabStudy));
    await tester.pumpAndSettle();

    expect(tester.widget<TabBar>(find.byType(TabBar)).currentIndex, 3);
  });

  testWidgets('tapping the current tab returns to its first screen', (
    tester,
  ) async {
    final router = _nestedRouter();
    await tester.pumpWidget(QuranApp(router: router));
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
    await tester.pumpWidget(QuranApp(router: router));
    await tester.pumpAndSettle();
    await tester.tap(_tab(_l10n.tabListen));
    await tester.pumpAndSettle();
    final chrome = Provider.of<ShellChrome>(
      tester.element(find.byType(TabShell)),
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
    await tester.pumpWidget(QuranApp(router: createRouter()));
    await tester.pumpAndSettle();
    final withBar = tester.getSize(find.byType(HomeScreen)).height;

    Provider.of<ShellChrome>(
      tester.element(find.byType(TabShell)),
      listen: false,
    ).tabBarVisible = false;
    await tester.pump();

    expect(
      tester.getSize(find.byType(HomeScreen)).height,
      greaterThan(withBar),
    );
  });
}
