import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/ui/core/gallery/gallery_screen.dart';
import 'package:holyquran/ui/features/more/views/more_screen.dart';

final moreRoutes = FeatureRoutes(
  tabRoot: TabRoot(ShellTab.more, (context, state) => const MoreScreen()),
  topLevel: [
    // The gallery is a review tool, not part of the product.
    if (kDebugMode)
      GoRoute(
        path: Routes.gallery,
        builder: (context, state) => const GalleryScreen(),
      ),
  ],
);
