import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// A two-finger pinch over the reader (`RD-07`), reported once, when it
/// ends: [onPinchEnd] gets the span's scale since the second finger came
/// down and the global focal point between the two fingers then. The text
/// does not follow the fingers; the caller steps the size (`pinch_step.dart`).
/// A pinch whose span never changes by the scale slop is not reported. Once
/// a pinch has ended, by a finger lifting or a third coming down, nothing is
/// reported until every finger is up.
///
/// It sits around the scroll view, one per reader, so its recogniser joins
/// each pointer's arena after the scroll view's drag and the block's tap. It
/// accepts on the second finger's down and so claims both pointers then:
/// waiting for the span to pass the scale slop would let the drag win any
/// pinch whose fingers move unevenly, as the drag counts the fingers' summed
/// vertical travel against the same slop. A single finger never reports.
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
