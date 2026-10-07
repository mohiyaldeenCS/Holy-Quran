import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/theme/theme_context.dart';

// :focus-visible: outline 2px solid var(--focus).
const double _ringWidth = 2;
// :focus-visible: outline-offset 2px, the gap left transparent.
const double _ringGap = 2;

/// The identity's keyboard focus ring (`:focus-visible`, `AX-09`): a 2 px
/// `focus` outline 2 px outside [child], drawn while a focusable inside
/// [child] has focus and focus is being moved by keyboard. It follows
/// [radius], as an outline follows `border-radius`, and takes no layout space.
class FocusRing extends StatefulWidget {
  const FocusRing({required this.child, required this.radius, super.key});

  final Widget child;
  final BorderRadius radius;

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
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _focused && _keyboard
        ? _RingPainter(context.colors.focus, widget.radius)
        : null,
    child: Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: _onFocusChange,
      child: widget.child,
    ),
  );
}

final class _RingPainter extends CustomPainter {
  _RingPainter(this.color, this.radius);

  final Color color;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final ring = radius
        .toRRect(Offset.zero & size)
        .inflate(_ringGap + _ringWidth / 2);
    canvas.drawRRect(
      ring,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _ringWidth,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
