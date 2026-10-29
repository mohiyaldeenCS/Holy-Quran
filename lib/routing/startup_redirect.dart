import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/domain/use_cases/is_ayah_of_pack.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/features/onboarding/view_models/setup_step.dart';
import 'package:provider/provider.dart';

// Off until the setup's step names, prompts and continue button have their
// wording (docs/plans/PHASE1.md, Appendix B and C): without a continue
// button a new user could not leave the setup.
const bool _firstRunSetupEnabled = false;

/// Where the app goes instead of the location it is opened at: the first-run
/// setup (O-17), then the reader at the last position when the user asked
/// for it (`RD-13`). Only the first location of a run, the router's, is looked
/// at: going home later stays home, so a router holds one of these.
final class StartupRedirect {
  bool _entered = false;

  /// The location to go to instead of [state]'s, or null to keep it.
  FutureOr<String?> call(BuildContext context, GoRouterState state) {
    final starting = !_entered;
    _entered = true;
    final settings = context.read<AppSettingsRepository?>();
    if (settings == null) return null;
    if (_firstRunSetupEnabled) {
      final setup = firstRunRedirect(context, state);
      if (setup != null) return setup;
    }
    if (!starting || state.uri.path != Routes.home) return null;
    return _lastPosition(context, settings);
  }
}

/// The first-run setup for a user who has not finished it (O-17, D-127).
String? firstRunRedirect(BuildContext context, GoRouterState state) {
  if (state.uri.path == Routes.onboarding) return null;
  return setupFinished(setupSteps(context.read<AppSettingsRepository>()))
      ? null
      : Routes.onboarding;
}

// A pack that does not serve its text has no index, and the app then stays
// on home, which says why (PRD §9.5).
String? _lastPosition(BuildContext context, AppSettingsRepository settings) {
  if (!settings.openAtLastPosition) return null;
  final last = context.read<ReadingPositionRepository?>()?.last;
  final index = context.read<QuranIndexRepository?>();
  if (last == null ||
      index == null ||
      !isAyahOfPack(last, riwaya: index.riwaya, surahs: index.surahs)) {
    return null;
  }
  return Routes.mushafRead(last);
}
