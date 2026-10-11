import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

import '../s1/render/surah_text_block.dart';
import 'gesture_target.dart';
import 'tap_resolver.dart';
import 'target_geometry.dart';

/// The gestures of one surah-mode text block (PRD §7.4, D-095): a tap and
/// a long press of [kLongPressTimeout], each resolved by [rule] to a
/// [GestureTarget] from the block's own geometry near the point, never the
/// whole surah's. No double tap: its recogniser would hold every tap for
/// 300 ms (NF-05 allows 200).
///
/// It sits inside the scroll view, one per block, so the scroll view's
/// drag wins past the touch slop, and a tap that stops a fling never
/// reaches it (the scroll view ignores pointers while it flings). Words,
/// marks and markers stay out of semantics here (M1.2, M1.6).
final class BlockGestures extends StatefulWidget {
  const BlockGestures({
    required this.child,
    required this.rule,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final SurahTextBlock child;
  final TapRule rule;
  final ValueChanged<GestureTarget>? onTap;
  final ValueChanged<GestureTarget>? onLongPress;

  @override
  State<BlockGestures> createState() => _BlockGesturesState();
}

final class _BlockGesturesState extends State<BlockGestures> {
  final _block = GlobalKey();

  void _report(Offset global, ValueChanged<GestureTarget>? callback) {
    final block = _block.currentContext?.findRenderObject();
    if (callback == null || block is! RenderSurahTextBlock || !block.hasSize) {
      return;
    }
    final p = block.globalToLocal(global);
    final paragraph = block.paragraph;
    const reach = AppSizes.targetMin;
    final geometry = TargetGeometry.of(
      paragraph,
      within: Rect.fromLTRB(0, p.dy - reach, paragraph.width, p.dy + reach),
    );
    callback(resolveTap(p, geometry, widget.rule));
  }

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    excludeFromSemantics: true,
    gestures: {
      if (widget.onTap != null)
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              () => TapGestureRecognizer(debugOwner: this),
              (recognizer) =>
                  recognizer.onTapUp = (details) =>
                      _report(details.globalPosition, widget.onTap),
            ),
      if (widget.onLongPress != null)
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(
                duration: kLongPressTimeout,
                debugOwner: this,
              ),
              (recognizer) =>
                  recognizer.onLongPressStart = (details) =>
                      _report(details.globalPosition, widget.onLongPress),
            ),
    },
    child: KeyedSubtree(key: _block, child: widget.child),
  );
}

/// A two-finger pinch over the reader (RD-07), reported once, when it
/// ends: [onPinchEnd] gets the span's scale since the second finger came
/// down and the global focal point where the pinch was recognised, past
/// the scale slop. The text does not follow the fingers; the caller steps
/// the size (`text_size_ladder.dart`). A third finger ends one pinch and
/// starts no other.
///
/// It sits around the scroll view, so its recogniser joins each pointer's
/// arena after the scroll view's drag: a one-finger drag scrolls, and a
/// symmetric pinch, whose movements cancel in the drag's sum, is won by the
/// pinch once its span has changed by the scale slop.
final class ReaderPinch extends StatefulWidget {
  const ReaderPinch({required this.child, required this.onPinchEnd, super.key});

  final Widget child;
  final void Function(double scale, Offset focalPoint) onPinchEnd;

  @override
  State<ReaderPinch> createState() => _ReaderPinchState();
}

final class _ReaderPinchState extends State<ReaderPinch> {
  double? _scale;
  Offset? _focal;

  void _update(ScaleUpdateDetails details) {
    if (details.pointerCount < 2) return;
    _focal ??= details.focalPoint;
    _scale = details.scale;
  }

  void _end(ScaleEndDetails details) {
    final scale = _scale;
    final focal = _focal;
    _scale = _focal = null;
    if (scale != null && focal != null) widget.onPinchEnd(scale, focal);
  }

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    excludeFromSemantics: true,
    gestures: {
      ScaleGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
            () => ScaleGestureRecognizer(debugOwner: this),
            (recognizer) => recognizer
              ..onUpdate = _update
              ..onEnd = _end,
          ),
    },
    child: widget.child,
  );
}
