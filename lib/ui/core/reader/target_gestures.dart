import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'gesture_target.dart';

/// The gestures of one surah-mode text block (PRD §7.4, D-095): a tap and a
/// long press of [kLongPressTimeout], each turned by [targetAt] into the
/// [GestureTarget] under the point, given in the block's own coordinates.
/// No double tap: its recogniser would hold every tap for 300 ms (`NF-05`
/// allows 200).
///
/// It sits in the scroll view, one per block, or around the scroll view for
/// the margin and what lies between blocks; either way the scroll view's drag
/// wins past the touch slop. A block's is inside the scroll view, which
/// ignores a touch that stops a fling; one around it must be left unarmed
/// while the text scrolls, by passing no [onTap].
/// The target is resolved from the block's own geometry near the point,
/// never the whole surah's. Words, marks and markers stay out of semantics
/// here.
final class TargetGestures extends StatelessWidget {
  const TargetGestures({
    required this.targetAt,
    required this.child,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final GestureTarget Function(Offset point) targetAt;
  final ValueChanged<GestureTarget>? onTap;
  final ValueChanged<GestureTarget>? onLongPress;
  final Widget child;

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    behavior: HitTestBehavior.opaque,
    excludeFromSemantics: true,
    gestures: {
      if (onTap case final onTap?)
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              () => TapGestureRecognizer(debugOwner: this),
              (recognizer) =>
                  recognizer.onTapUp = (details) =>
                      onTap(targetAt(details.localPosition)),
            ),
      if (onLongPress case final onLongPress?)
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(
                duration: kLongPressTimeout,
                debugOwner: this,
              ),
              (recognizer) =>
                  recognizer.onLongPressStart = (details) =>
                      onLongPress(targetAt(details.localPosition)),
            ),
    },
    child: child,
  );
}
