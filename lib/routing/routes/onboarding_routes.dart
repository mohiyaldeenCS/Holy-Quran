import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/ui/features/onboarding/view_models/onboarding_view_model.dart';
import 'package:holyquran/ui/features/onboarding/view_models/setup_step.dart';
import 'package:holyquran/ui/features/onboarding/views/onboarding_screen.dart';
import 'package:provider/provider.dart';

final onboardingRoutes = FeatureRoutes(
  topLevel: [
    GoRoute(
      path: Routes.onboarding,
      // The setup stores its choices in the settings; without them there is
      // nothing to ask.
      redirect: (context, state) =>
          context.read<AppSettingsRepository?>() == null ? Routes.home : null,
      builder: (context, state) => ChangeNotifierProvider(
        create: (context) {
          final settings = context.read<AppSettingsRepository>();
          return OnboardingViewModel(
            settings: settings,
            steps: setupSteps(settings),
          );
        },
        child: const OnboardingScreen(),
      ),
    ),
  ],
);
