import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/ui/features/listen/view_models/recitation_picker_view_model.dart';
import 'package:holyquran/ui/features/listen/views/listen_screen.dart';
import 'package:holyquran/ui/features/listen/views/recitation_picker_screen.dart';
import 'package:provider/provider.dart';

final listenRoutes = FeatureRoutes(
  tabRoot: TabRoot(ShellTab.listen, (context, state) => const ListenScreen()),
  tabChildren: {
    ShellTab.listen: [
      GoRoute(
        path: RoutePaths.recitations,
        builder: (context, state) =>
            ChangeNotifierProvider<RecitationPickerViewModel>(
              create: createRecitationPickerViewModel,
              child: Builder(
                builder: (context) => RecitationPickerScreen(
                  viewModel: context.read<RecitationPickerViewModel>(),
                ),
              ),
            ),
      ),
    ],
  },
);
