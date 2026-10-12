import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/features/onboarding/view_models/setup_step.dart';
import 'package:provider/provider.dart';

// Off until the setup's step names, prompts and continue button have their
// wording (docs/plans/PHASE1.md, Appendix B and C): without a continue
// button a new user could not leave the setup.
const bool _firstRunSetupEnabled = false;

/// Where the app goes instead of [state]'s location on its way in: the
/// first-run setup (O-17) and opening at the last position. Null keeps the
/// location.
FutureOr<String?> startupRedirect(BuildContext context, GoRouterState state) =>
    _firstRunSetupEnabled ? firstRunRedirect(context, state) : null;

/// The first-run setup for a user who has not finished it (O-17, D-127).
String? firstRunRedirect(BuildContext context, GoRouterState state) {
  if (state.uri.path == Routes.onboarding) return null;
  final settings = context.read<AppSettingsRepository?>();
  if (settings == null || setupFinished(setupSteps(settings))) return null;
  return Routes.onboarding;
}
