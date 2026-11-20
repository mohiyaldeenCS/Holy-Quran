import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/recitation_repository.dart';
import 'package:holyquran/domain/models/catalogue_entry.dart';
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
      builder: (context, state) => ChangeNotifierProvider(
        create: (context) {
          final settings = context.read<AppSettingsRepository>();
          final recitations = readyRecitations(context);
          return OnboardingViewModel(
            settings: settings,
            steps: setupSteps(settings, recitations: recitations),
            recitations: recitations,
          );
        },
        child: const OnboardingScreen(),
      ),
    ),
  ],
);

/// The recitations the setup offers: the `Ready` ones of the app's
/// catalogue, none when the app provides no recitations.
List<CatalogueRecitation> readyRecitations(BuildContext context) =>
    context.read<RecitationRepository?>()?.recitations ?? const [];
