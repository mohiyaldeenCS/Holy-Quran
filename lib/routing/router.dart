import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/bookmarks_routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/routing/routes/home_routes.dart';
import 'package:holyquran/routing/routes/index_routes.dart';
import 'package:holyquran/routing/routes/listen_controls_routes.dart';
import 'package:holyquran/routing/routes/listen_routes.dart';
import 'package:holyquran/routing/routes/more_routes.dart';
import 'package:holyquran/routing/routes/mushaf_routes.dart';
import 'package:holyquran/routing/routes/onboarding_routes.dart';
import 'package:holyquran/routing/routes/report_routes.dart';
import 'package:holyquran/routing/routes/resources_routes.dart';
import 'package:holyquran/routing/routes/search_routes.dart';
import 'package:holyquran/routing/routes/settings_routes.dart';
import 'package:holyquran/routing/routes/share_routes.dart';
import 'package:holyquran/routing/routes/sheet_page.dart';
import 'package:holyquran/routing/routes/sheets_routes.dart';
import 'package:holyquran/routing/routes/sources_routes.dart';
import 'package:holyquran/routing/routes/study_routes.dart';
import 'package:holyquran/routing/routes/tafsir_routes.dart';
import 'package:holyquran/routing/startup_redirect.dart';
import 'package:holyquran/ui/core/shell_chrome.dart';
import 'package:holyquran/ui/core/tab_shell.dart';
import 'package:provider/provider.dart';

/// Every feature's routes (D-101, D-102).
final List<FeatureRoutes> appFeatures = [
  onboardingRoutes,
  homeRoutes,
  mushafRoutes,
  indexRoutes,
  listenRoutes,
  listenControlsRoutes,
  studyRoutes,
  searchRoutes,
  tafsirRoutes,
  sheetsRoutes,
  shareRoutes,
  moreRoutes,
  bookmarksRoutes,
  resourcesRoutes,
  settingsRoutes,
  sourcesRoutes,
  reportRoutes,
];

/// The app's router. Tests pass their own [features] to add routes.
GoRouter createRouter({List<FeatureRoutes>? features}) {
  final all = features ?? appFeatures;
  late final GoRouter router;
  router = GoRouter(
    initialLocation: Routes.home,
    redirect: _redirect,
    // No route matches: go home rather than show go_router's English page.
    onException: (context, state, router) => router.go(Routes.home),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => ChangeNotifierProvider(
          create: (context) => ShellChrome(),
          child: TabShell(navigationShell: navigationShell),
        ),
        branches: [
          for (final tab in ShellTab.values)
            StatefulShellBranch(routes: [_tabRoute(tab, all)]),
        ],
      ),
      for (final feature in all)
        for (final sheet in feature.sheets)
          GoRoute(
            path: sheet.path,
            // Before any screen is shown this is a cold start, not a push.
            redirect: (context, state) =>
                router.routerDelegate.currentConfiguration.isEmpty
                ? sheet.owner(state)
                : null,
            pageBuilder: (context, state) => SheetPage<Object?>(
              key: state.pageKey,
              name: state.uri.toString(),
              child: sheet.builder(context, state),
            ),
          ),
      for (final feature in all) ...feature.topLevel,
    ],
  );
  return router;
}

GoRoute _tabRoute(ShellTab tab, List<FeatureRoutes> features) {
  final roots = [
    for (final feature in features)
      if (feature.tabRoot case final root? when root.tab == tab) root,
  ];
  if (roots.length != 1) {
    throw StateError('${tab.name} needs one root, found ${roots.length}');
  }
  return GoRoute(
    path: tab.path,
    builder: roots.single.builder,
    routes: [for (final feature in features) ...?feature.tabChildren[tab]],
  );
}

/// A location whose address or surah is malformed is treated as unknown.
FutureOr<String?> _redirect(BuildContext context, GoRouterState state) {
  final parameters = state.pathParameters;
  if ((parameters.containsKey(Routes.addressParameter) &&
          Routes.addressOf(state) == null) ||
      (parameters.containsKey(Routes.surahParameter) &&
          Routes.surahOf(state) == null)) {
    return Routes.home;
  }
  return startupRedirect(context, state);
}
