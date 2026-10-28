import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/theme/theme_context.dart';

import 'pinch_step.dart';
import 'reader_pinch.dart';
import 'surah_layout.dart';

/// The reader's one pinch handler (`RD-07`, D-097) and the place it keeps:
/// around the scroll view that holds a surah sliver, it steps the text size
/// through `readerTextSteps` when a pinch ends and then scrolls so that the
/// ayah under the fingers is where it was, within a line.
///
/// The screen owns the step ([step], an index into the ladder) and sets the
/// sliver's size from it: [onStep] is called with the step a pinch leads to,
/// which is never [step]. The screen also hands back the sliver's latest plan
/// through [layout], which its `onLayout` sets. When a new plan arrives for
/// the same text, whatever changed it, the scroll offset is set at once, in
/// the callback that reported the plan, so that the ayah at the top of the
/// screen, or the one the pinch kept, is where it was: the new size shows for
/// one frame at the old offset and not longer. A turn of the device keeps the
/// first ayah showing.
///
/// This widget's box is the scroll view's viewport, so [child] fills it. The
/// sliver is as wide as that box and starts [leadingExtent] below the top of
/// the scroll content.
final class ReaderPinchStepper extends StatefulWidget {
  const ReaderPinchStepper({
    required this.scrollController,
    required this.layout,
    required this.step,
    required this.onStep,
    required this.child,
    this.leadingExtent = 0,
    super.key,
  });

  final ScrollController scrollController;
  final ValueListenable<SurahLayout?> layout;
  final int step;
  final ValueChanged<int> onStep;
  final double leadingExtent;
  final Widget child;

  @override
  State<ReaderPinchStepper> createState() => _ReaderPinchStepperState();
}

/// An ayah, and where in the viewport it is to stay: [viewportY] below the
/// top edge.
typedef _Anchor = ({FocalAyah focal, double viewportY});

final class _ReaderPinchStepperState extends State<ReaderPinchStepper> {
  _Anchor? _top;
  _Anchor? _pinch;
  SurahLayout? _known;

  @override
  void initState() {
    super.initState();
    _known = widget.layout.value;
    widget.scrollController.addListener(_scrolled);
    widget.layout.addListener(_planned);
    WidgetsBinding.instance.addPostFrameCallback((_) => _recordTop());
  }

  @override
  void didUpdateWidget(ReaderPinchStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_scrolled);
      widget.scrollController.addListener(_scrolled);
    }
    if (oldWidget.layout != widget.layout) {
      oldWidget.layout.removeListener(_planned);
      widget.layout.addListener(_planned);
      _known = widget.layout.value;
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_scrolled);
    widget.layout.removeListener(_planned);
    super.dispose();
  }

  ScrollPosition? get _position => widget.scrollController.hasClients
      ? widget.scrollController.position
      : null;

  // Runs in the callback after the frame that laid the plan out, so the scroll
  // extents are the plan's own and a scroll listener may set state.
  void _planned() {
    final layout = widget.layout.value;
    final before = _known;
    if (identical(layout, before)) return;
    _known = layout;
    final anchor = _pinch ?? _top;
    _pinch = null;
    if (layout != null &&
        before != null &&
        identical(layout.text, before.text) &&
        anchor != null) {
      _restore(layout, anchor);
    }
    _recordTop();
  }

  void _scrolled() {
    _pinch = null;
    _recordTop();
  }

  void _recordTop() {
    final layout = widget.layout.value;
    final position = _position;
    if (!mounted || layout == null || position == null) return;
    final y = position.pixels - widget.leadingExtent;
    _top = y < layout.basmalaExtent
        ? null
        : (focal: focalAyahOfLine(layout, y), viewportY: 0);
  }

  void _restore(SurahLayout layout, _Anchor anchor) {
    final position = _position;
    if (position == null) return;
    final y = yOfFocalAyah(layout, anchor.focal);
    final target = widget.leadingExtent + y - anchor.viewportY;
    position.jumpTo(
      target.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  void _pinched(double scale, Offset focalPoint) {
    final next = stepAfterPinch(widget.step, scale);
    if (next == widget.step) return;
    final layout = widget.layout.value;
    final position = _position;
    if (layout != null && position != null) {
      final local = (context.findRenderObject()! as RenderBox).globalToLocal(
        focalPoint,
      );
      final y = position.pixels - widget.leadingExtent + local.dy;
      final focal = focalAyahUnder(
        layout,
        Offset(local.dx, y),
        ink: context.colors.quranInk,
      );
      // Fingers above the text (on the basmala, the header or the leading
      // space) keep what is above them where it is, as the top edge does.
      _pinch = y < layout.basmalaExtent
          ? null
          : (focal: focal, viewportY: local.dy);
    }
    widget.onStep(next);
  }

  @override
  Widget build(BuildContext context) =>
      ReaderPinch(onPinchEnd: _pinched, child: widget.child);
}
