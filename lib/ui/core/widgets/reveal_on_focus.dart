import 'dart:math' as math;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/theme/motion.dart';

/// Scrolls the nearest scrollable just enough to show [child] whole when
/// focus moves into it, so a keyboard user sees each chip or tab of a
/// sideways strip they reach (AX-09; none hides, D-087).
///
/// Focus traversal's own reveal does not do it in a right-to-left strip: on
/// an `AxisDirection.left` axis, `ScrollPosition.ensureVisible` flips the
/// keep-visible policy it is given and leaves the strip where it is. Here
/// the offsets that align [child] to either edge are asked of the viewport,
/// which knows its direction, and the strip moves to the nearer one; it
/// jumps there when the system asks for reduced motion.
class RevealOnFocus extends StatelessWidget {
  const RevealOnFocus({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    includeSemantics: false,
    onFocusChange: (focused) {
      if (focused) _reveal(context);
    },
    child: child,
  );
}

void _reveal(BuildContext context) {
  final target = context.findRenderObject();
  final position = Scrollable.maybeOf(context)?.position;
  if (target == null || position == null) return;
  final viewport = RenderAbstractViewport.maybeOf(target);
  if (viewport == null) return;
  final atLeading = viewport.getOffsetToReveal(target, 0).offset;
  final atTrailing = viewport.getOffsetToReveal(target, 1).offset;
  final pixels = clampDouble(
    clampDouble(
      position.pixels,
      math.min(atLeading, atTrailing),
      math.max(atLeading, atTrailing),
    ),
    position.minScrollExtent,
    position.maxScrollExtent,
  );
  if (pixels == position.pixels) return;
  if (MediaQuery.disableAnimationsOf(context)) {
    position.jumpTo(pixels);
  } else {
    position.animateTo(pixels, duration: motionNormal, curve: motionCurve);
  }
}
