import 'package:flutter/material.dart';

import 'package:holyquran/ui/core/theme/motion.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';

/// A sheet route's page: a modal bottom sheet over the `scrim` (tokens.css:
/// «ستارة خلف الأوراق المنزلقة»). The sheet's content draws its own
/// surface, corners and handle, so the route adds none.
final class SheetPage<T> extends Page<T> {
  const SheetPage({required this.child, super.key, super.name});

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) {
    final colors = context.colors;
    return ModalBottomSheetRoute<T>(
      settings: this,
      builder: (context) => child,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colors.surface.withValues(alpha: 0),
      elevation: 0,
      modalBarrierColor: colors.scrim,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              curve: motionCurve,
              duration: motionNormal,
              reverseDuration: motionNormal,
            ),
    );
  }
}
