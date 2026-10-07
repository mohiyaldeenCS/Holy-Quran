import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/gallery/gallery_screen.dart';
import 'package:holyquran/ui/core/tab_shell.dart';
import 'package:holyquran/ui/features/home/views/home_screen.dart';
import 'package:holyquran/ui/features/listen/views/listen_screen.dart';
import 'package:holyquran/ui/features/more/views/more_screen.dart';
import 'package:holyquran/ui/features/mushaf/views/mushaf_screen.dart';
import 'package:holyquran/ui/features/study/views/study_screen.dart';

GoRouter createRouter() => GoRouter(
  initialLocation: Routes.home,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          TabShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.home,
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.mushaf,
              builder: (context, state) => const MushafScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.listen,
              builder: (context, state) => const ListenScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.study,
              builder: (context, state) => const StudyScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.more,
              builder: (context, state) => const MoreScreen(),
            ),
          ],
        ),
      ],
    ),
    // The gallery is a review tool, not part of the product.
    if (kDebugMode)
      GoRoute(
        path: Routes.gallery,
        builder: (context, state) => const GalleryScreen(),
      ),
  ],
);
