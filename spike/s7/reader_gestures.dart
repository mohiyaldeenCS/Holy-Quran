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
/// down and the global focal point between the two fingers then. The text
/// does not follow the fingers; the caller steps the size
/// (`text_size_ladder.dart`). A pinch whose span never changes by the
/// scale slop is not reported. One rule ends it: once a pinch has ended,
/// by a finger lifting or a third coming down, nothing is reported until
/// every finger is up.
///
/// It sits around the scroll view, so its recogniser joins each pointer's
/// arena after the scroll view's drag and the block's tap. It accepts on
/// the second finger's down and so claims both pointers then: waiting for
/// the span to pass the scale slop lets the drag win any pinch whose
/// fingers move unevenly, as the drag counts the fingers' summed vertical
/// travel against the same slop. A single finger never reports.
final class ReaderPinch extends StatelessWidget {
  const ReaderPinch({required this.child, required this.onPinchEnd, super.key});

  final Widget child;
  final void Function(double scale, Offset focalPoint) onPinchEnd;

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    excludeFromSemantics: true,
    gestures: {
      _PinchRecognizer: GestureRecognizerFactoryWithHandlers<_PinchRecognizer>(
        () => _PinchRecognizer(debugOwner: this),
        (recognizer) => recognizer.onPinchEnd = onPinchEnd,
      ),
    },
    child: child,
  );
}

/// A scale recogniser that wins the arena when a second finger comes down
/// and reports each pinch once, as [ReaderPinch] describes.
final class _PinchRecognizer extends ScaleGestureRecognizer {
  _PinchRecognizer({super.debugOwner}) {
    onStart = _start;
    onUpdate = _update;
    onEnd = _end;
  }

  void Function(double scale, Offset focalPoint)? onPinchEnd;

  final _points = <int, Offset>{};
  PointerDeviceKind _kind = PointerDeviceKind.touch;
  double _startSpan = 0;
  bool _pastSlop = false;
  double? _scale;
  Offset? _focal;
  bool _ended = false;

  /// The fingers' mean distance from their centroid, as the scale is.
  double get _span {
    if (_points.isEmpty) return 0;
    final centroid =
        _points.values.reduce((a, b) => a + b) / _points.length.toDouble();
    return _points.values
            .map((point) => (point - centroid).distance)
            .reduce((a, b) => a + b) /
        _points.length;
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerDownEvent || event is PointerMoveEvent) {
      _points[event.pointer] = event.position;
      _kind = event.kind;
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _points.remove(event.pointer);
    }
    super.handleEvent(event);
    // The down is routed here before its arena closes, so the new pointer
    // is won eagerly and the earlier ones at once.
    if (event is PointerDownEvent && pointerCount >= 2) {
      resolve(GestureDisposition.accepted);
    }
  }

  void _start(ScaleStartDetails details) {
    if (_ended || details.pointerCount < 2) return;
    _focal = details.focalPoint;
    _startSpan = _span;
  }

  void _update(ScaleUpdateDetails details) {
    if (_ended || _focal == null || details.pointerCount < 2) return;
    _pastSlop |= (_span - _startSpan).abs() > computeScaleSlop(_kind);
    if (_pastSlop) _scale = details.scale;
  }

  void _end(ScaleEndDetails details) {
    final focal = _focal;
    if (_ended || focal == null) return;
    _ended = true;
    if (_scale case final scale?) onPinchEnd?.call(scale, focal);
  }

  @override
  void rejectGesture(int pointer) {
    _points.remove(pointer);
    super.rejectGesture(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    super.didStopTrackingLastPointer(pointer);
    _points.clear();
    _pastSlop = _ended = false;
    _scale = _focal = null;
  }
}
