import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/widgets/focus_ring.dart';

/// What makes a design-system widget pressable (D-086): a tap anywhere on
/// [child], Enter and Space while it has keyboard focus, the identity's focus
/// ring following [focusRadius] in keyboard mode only, and the click cursor.
/// Disabled when [onPressed] is null: no tap, no focus, the basic cursor.
///
/// It marks itself a button, and disabled when it is, for screen readers.
/// The caller's labelled `Semantics(container: true)` around it takes these
/// flags and the tap and focus actions into one node; that `Semantics` must
/// not set them again, or the node splits in two.
class Pressable extends StatelessWidget {
  const Pressable({
    required this.onPressed,
    required this.focusRadius,
    required this.child,
    super.key,
  });

  final VoidCallback? onPressed;
  final BorderRadius focusRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onPressed = this.onPressed;
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      // Only the disabled state: a caller that announces the enabled state
      // does so itself.
      enabled: enabled ? null : false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: FocusRing(
          radius: focusRadius,
          child: FocusableActionDetector(
            enabled: enabled,
            mouseCursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            actions: {
              if (enabled)
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) => onPressed(),
                ),
            },
            child: child,
          ),
        ),
      ),
    );
  }
}
