import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';

// .qk-icon / ICONS: the paths are drawn on a 24 by 24 viewBox.
const double _grid = 24;

/// One icon of the identity's set (`Icon`, `.qk-icon`). Stroked in the
/// current icon colour, or filled for play and pause. The set is drawn for
/// right-to-left reading, so it is never mirrored. Decorative unless
/// [semanticLabel] is given.
class Icon extends StatelessWidget {
  const Icon(
    this.name, {
    this.size = AppSizes.iconSize,
    this.semanticLabel,
    this.color,
    super.key,
  });

  final IconName name;
  final double size;
  final String? semanticLabel;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final paint = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _IconPainter(name, color ?? IconTheme.of(context).color!),
      ),
    );
    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: paint);
    return Semantics(
      container: true,
      image: true,
      label: label,
      child: ExcludeSemantics(child: paint),
    );
  }
}

final class _IconPainter extends CustomPainter {
  _IconPainter(this.name, this.color);

  final IconName name;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final filled = isIconFilled(name);
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = AppSizes.iconStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..save()
      ..scale(size.width / _grid, size.height / _grid)
      ..drawPath(buildIconPath(name), paint)
      ..restore();
  }

  @override
  bool shouldRepaint(_IconPainter oldDelegate) =>
      oldDelegate.name != name || oldDelegate.color != color;
}
