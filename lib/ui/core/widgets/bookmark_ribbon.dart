import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/widgets/tag.dart';

// Mushaf.dc.html, «علامة مرجعية»: `<svg width="30" height="40" viewBox="0 0 30
// 40">`; its path `M3 2h24v35l-12-8-12 8z` is the ribbon.
const Size _size = Size(30, 40);
const double _left = 3;
const double _right = 27;
const double _top = 2;
const double _shoulder = 37;
const double _notch = 29;
const double _middle = 15;

// The same svg's inner diamond, `M15 9.5 19.5 14 15 18.5 10.5 14z`: centre
// (15, 14), half a diagonal of 4.5. The other three shapes of a category
// (`.qk-tag-dot-*`, 10 px) are drawn at this mark's size, 0.9 of the dot's.
const double _markCentreY = 14;
const double _markReach = 4.5;
const double _squareSide = 7;
const double _squareRadius = 1.8;
const double _ringStroke = 1.8;

/// The bookmark ribbon the margin shows beside a bookmarked ayah (`UD-05`),
/// as the Mushaf board draws it: an emerald ribbon in `primary` with the
/// bookmark's category inside it as the shape the category has in [Tag]
/// (`AX-05`: never the colour alone). The board gives the inner mark the
/// category's colour; the category colours are open (O-14), and `primary`
/// is itself the gold in night, so every mark is `on-primary` here, which
/// stands out of the ribbon in every theme, and the shape tells the
/// categories apart.
///
/// [label] and [category] are what a screen reader hears: the word for a
/// bookmark and the category's name.
final class BookmarkRibbon extends StatelessWidget {
  const BookmarkRibbon({
    required this.shape,
    required this.label,
    required this.category,
    super.key,
  });

  final TagShape shape;
  final String label;
  final String category;

  /// The drawn size, which the margin positions it by.
  static const Size size = _size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      image: true,
      label: label,
      value: category,
      child: ExcludeSemantics(
        child: CustomPaint(
          size: _size,
          painter: _RibbonPainter(
            shape: shape,
            body: colors.primary,
            mark: colors.onPrimary,
          ),
        ),
      ),
    );
  }
}

final class _RibbonPainter extends CustomPainter {
  const _RibbonPainter({
    required this.shape,
    required this.body,
    required this.mark,
  });

  final TagShape shape;
  final Color body;
  final Color mark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / _size.width, size.height / _size.height)
      ..drawPath(
        Path()
          ..moveTo(_left, _top)
          ..lineTo(_right, _top)
          ..lineTo(_right, _shoulder)
          ..lineTo(_middle, _notch)
          ..lineTo(_left, _shoulder)
          ..close(),
        Paint()..color = body,
      );
    final fill = Paint()..color = mark;
    const centre = Offset(_middle, _markCentreY);
    switch (shape) {
      case TagShape.diamond:
        canvas.drawPath(
          Path()
            ..moveTo(_middle, _markCentreY - _markReach)
            ..lineTo(_middle + _markReach, _markCentreY)
            ..lineTo(_middle, _markCentreY + _markReach)
            ..lineTo(_middle - _markReach, _markCentreY)
            ..close(),
          fill,
        );
      case TagShape.circle:
        canvas.drawCircle(centre, _markReach, fill);
      case TagShape.square:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: centre,
              width: _squareSide,
              height: _squareSide,
            ),
            const Radius.circular(_squareRadius),
          ),
          fill,
        );
      case TagShape.ring:
        canvas.drawCircle(
          centre,
          _markReach - _ringStroke / 2,
          Paint()
            ..color = mark
            ..style = PaintingStyle.stroke
            ..strokeWidth = _ringStroke,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RibbonPainter oldDelegate) =>
      oldDelegate.shape != shape ||
      oldDelegate.body != body ||
      oldDelegate.mark != mark;
}
