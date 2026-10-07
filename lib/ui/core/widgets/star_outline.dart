import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/theme/theme_context.dart';

/// The quarter star alone: two squares, one turned 45 degrees, outlined.
/// Decorative, so screen readers skip it.
///
/// [stroke] is in the units of the 120 viewBox, as in the reference.
final class StarOutline extends StatelessWidget {
  const StarOutline({
    this.size = _defaultSize,
    this.stroke = _defaultStroke,
    this.color,
    super.key,
  });

  /// Defaults to the theme's `ornament` (`.qk-star`).
  final Color? color;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: StarOutlinePainter(
        color: color ?? context.colors.ornament,
        stroke: stroke,
      ),
    ),
  );
}

/// Paints the two squares of the quarter star scaled to the canvas, which
/// stands for the reference's 120 viewBox. Shared with `Mark`.
final class StarOutlinePainter extends CustomPainter {
  const StarOutlinePainter({
    required this.color,
    required this.stroke,
    this.fill,
  });

  final Color color;
  final double stroke;

  /// When set, each square is filled with it before its outline is drawn, in
  /// the order SVG paints a group's children.
  final Color? fill;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = stroke
      ..color = color;
    final fillPaint = fill == null ? null : (Paint()..color = fill!);
    canvas
      ..save()
      ..scale(size.width / viewBox, size.height / viewBox);
    for (final turned in [false, true]) {
      canvas.save();
      if (turned) {
        canvas
          ..translate(_centre, _centre)
          ..rotate(math.pi / 4)
          ..translate(-_centre, -_centre);
      }
      if (fillPaint != null) canvas.drawRect(_square, fillPaint);
      canvas
        ..drawRect(_square, outline)
        ..restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(StarOutlinePainter oldDelegate) =>
      color != oldDelegate.color ||
      stroke != oldDelegate.stroke ||
      fill != oldDelegate.fill;

  /// `viewBox="0 0 120 120"` of `StarOutline` and `Mark` in index.jsx.
  static const double viewBox = 120;
}

// StarOutline in index.jsx: `size = 28, stroke = 5`.
const double _defaultSize = 28;
const double _defaultStroke = 5;

// StarOutline and Mark in index.jsx: `<rect x="32" y="32" width="56"
// height="56" />`, the second one `rotate(45 60 60)`.
const double _centre = 60;
const Rect _square = Rect.fromLTWH(32, 32, 56, 56);
