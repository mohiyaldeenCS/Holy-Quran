import 'package:flutter/material.dart';

import 'package:holyquran/ui/core/theme/motion.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';

/// The one route every sheet of the app is shown in: a modal bottom sheet
/// over the `scrim` (tokens.css: «ستارة خلف الأوراق المنزلقة»), sliding at
/// the normal pace and not at all when the system reduces motion. The
/// sheet's content draws its own surface, corners and handle, so the route
/// adds none.
ModalBottomSheetRoute<T> sheetRoute<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  RouteSettings? settings,
}) {
  final colors = context.colors;
  final localizations = MaterialLocalizations.of(context);
  return ModalBottomSheetRoute<T>(
    settings: settings,
    builder: builder,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: colors.surface.withValues(alpha: 0),
    elevation: 0,
    modalBarrierColor: colors.scrim,
    // What showModalBottomSheet gives screen readers for the barrier.
    barrierLabel: localizations.scrimLabel,
    barrierOnTapHint: localizations.scrimOnTapHint(
      localizations.bottomSheetLabel,
    ),
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            curve: motionCurve,
            reverseCurve: motionCurve,
            duration: motionNormal,
            reverseDuration: motionNormal,
          ),
  );
}
