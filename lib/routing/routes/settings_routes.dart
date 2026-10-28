import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/ui/features/settings/view_models/settings_view_model.dart';
import 'package:holyquran/ui/features/settings/views/settings_screen.dart';
import 'package:provider/provider.dart';

final settingsRoutes = FeatureRoutes(
  tabChildren: {
    ShellTab.more: [
      GoRoute(
        path: RoutePaths.settings,
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) =>
              SettingsViewModel(context.read<AppSettingsRepository>()),
          child: const SettingsScreen(),
        ),
      ),
    ],
  },
);
