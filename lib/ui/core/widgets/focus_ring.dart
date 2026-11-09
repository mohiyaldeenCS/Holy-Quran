import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/theme/theme_context.dart';

// :focus-visible: outline 2px solid var(--focus).
const double _ringWidth = 2;
// :focus-visible: outline-offset 2px. bundle.css leaves the gap transparent;
// tokens.md (`focus`) draws it in `ground`, so the ring reads on every
// surface (D-171).
const double _ringGap = 2;

/// How far the ring reaches past what it surrounds: its gap and its stroke.
const double focusRingReach = _ringGap + _ringWidth;

/// The identity's keyboard focus ring (`:focus-visible`, `AX-09`): a 2 px
/// `focus` outline after a 2 px gap in `ground`, round [child], drawn while a
/// focusable inside [child] has focus and focus is being moved by keyboard.
/// It follows [radius], as an outline follows `border-radius`, and takes no
/// layout space.
///
/// [FocusRing.lines] draws one ring round each rect [lines] gives instead of
/// one round [child]: the rects, in [child]'s coordinates, of what a focused
/// element covers line by line (D-171). They are asked for only while the
/// ring shows. With [behind] the ring is painted under
/// [child] instead of over it, for a [child] whose own paint it must never
/// cover, as the Quran text is never covered.
class FocusRing extends StatefulWidget {
  const FocusRing({required this.child, required this.radius, super.key})
    : lines = null,
      behind = false;

  const FocusRing.lines({
    required this.child,
    required ValueGetter<List<Rect>> this.lines,
    this.behind = false,
    super.key,
  }) : radius = BorderRadius.zero;

  final Widget child;
  final BorderRadius radius;
  final ValueGetter<List<Rect>>? lines;
  final bool behind;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  bool _focused = false;
  bool _keyboard = _isKeyboard(FocusManager.instance.highlightMode);

  static bool _isKeyboard(FocusHighlightMode mode) =>
      mode == FocusHighlightMode.traditional;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightMode);
    super.dispose();
  }

  void _onHighlightMode(FocusHighlightMode mode) {
    final keyboard = _isKeyboard(mode);
    if (keyboard != _keyboard) setState(() => _keyboard = keyboard);
  }

  void _onFocusChange(bool focused) {
    if (focused != _focused) setState(() => _focused = focused);
  }

  @override
  Widget build(BuildContext context) {
    final ring = _focused && _keyboard
        ? FocusRingPainter(
            focus: context.colors.focus,
            ground: context.colors.ground,
            radius: widget.radius,
            lines: widget.lines?.call(),
          )
        : null;
    return CustomPaint(
      painter: widget.behind ? ring : null,
      foregroundPainter: widget.behind ? null : ring,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onFocusChange: _onFocusChange,
        child: widget.child,
      ),
    );
  }
}

/// Paints the ring: the gap in `ground`, then the stroke in `focus`.
final class FocusRingPainter extends CustomPainter {
  FocusRingPainter({
    required this.focus,
    required this.ground,
    required this.radius,
    required this.lines,
  });

  final Color focus;
  final Color ground;
  final BorderRadius radius;
  final List<Rect>? lines;

  @override
  void paint(Canvas canvas, Size size) {
    final shapes = [
      for (final rect in lines ?? [Offset.zero & size]) radius.toRRect(rect),
    ];
    final gap = Paint()
      ..color = ground
      ..style = PaintingStyle.stroke
      ..strokeWidth = _ringGap;
    final ring = Paint()
      ..color = focus
      ..style = PaintingStyle.stroke
      ..strokeWidth = _ringWidth;
    for (final shape in shapes) {
      canvas.drawRRect(shape.inflate(_ringGap / 2), gap);
    }
    for (final shape in shapes) {
      canvas.drawRRect(shape.inflate(_ringGap + _ringWidth / 2), ring);
    }
  }

  @override
  bool shouldRepaint(FocusRingPainter oldDelegate) =>
      oldDelegate.focus != focus ||
      oldDelegate.ground != ground ||
      oldDelegate.radius != radius ||
      !listEquals(oldDelegate.lines, lines);
}
