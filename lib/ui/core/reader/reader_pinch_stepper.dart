import 'package:flutter/widgets.dart';

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
/// as [layout], from `onLayout`. When a new plan arrives for the same text,
/// whatever changed it, the scroll offset is set so that the ayah at the top
/// of the screen, or the one the pinch kept, is where it was: a turn of the
/// device keeps the first ayah showing.
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
  final SurahLayout? layout;
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

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_scrolled);
    WidgetsBinding.instance.addPostFrameCallback((_) => _recordTop());
  }

  @override
  void didUpdateWidget(ReaderPinchStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_scrolled);
      widget.scrollController.addListener(_scrolled);
    }
    final layout = widget.layout;
    final before = oldWidget.layout;
    if (identical(layout, before)) return;
    final anchor = _pinch ?? _top;
    _pinch = null;
    if (layout == null ||
        before == null ||
        !identical(layout.text, before.text)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _recordTop());
      return;
    }
    // The new plan has been laid out by now, so the scroll extents are its
    // own; the jump waits for the end of the frame because a scroll listener
    // may set state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(widget.layout, layout) && anchor != null) {
        _restore(layout, anchor);
      }
      _recordTop();
    });
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_scrolled);
    super.dispose();
  }

  ScrollPosition? get _position => widget.scrollController.hasClients
      ? widget.scrollController.position
      : null;

  void _scrolled() {
    _pinch = null;
    _recordTop();
  }

  void _recordTop() {
    final layout = widget.layout;
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
    final layout = widget.layout;
    final position = _position;
    if (layout != null && position != null) {
      final local = (context.findRenderObject()! as RenderBox).globalToLocal(
        focalPoint,
      );
      final y = position.pixels - widget.leadingExtent + local.dy;
      _pinch = (focal: focalAyahOfLine(layout, y), viewportY: local.dy);
    }
    widget.onStep(next);
  }

  @override
  Widget build(BuildContext context) =>
      ReaderPinch(onPinchEnd: _pinched, child: widget.child);
}
