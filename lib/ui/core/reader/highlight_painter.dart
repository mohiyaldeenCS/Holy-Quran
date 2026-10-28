import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/theme/tokens.g.dart';

import 'highlight_shapes.dart';

// The inline highlights of the Mushaf board (`.qk-hl-*` in `bundle.css`,
// «التمييز داخل النص»).

// `.qk-hl-word` and `.qk-hl-search`: `border-radius: 6px`.
const double _wordRadius = 6;

// `.qk-hl-word` and `.qk-hl-search`: `box-shadow: inset 0 -2px 0`.
const double _underline = 2;

// `.qk-hl-select`: `box-shadow: inset 0 0 0 1.5px`.
const double _frame = 1.5;

/// Paints [shapes] behind the glyphs of a block, in the theme's tokens. Each
/// state has a line or a shape besides its colour (`AX-05`): the selected
/// ayah a thin frame, the spoken word and a search match an underline. The
/// recited ayah's own cue, its filled marker, is drawn by the block.
final class HighlightPainter extends CustomPainter {
  const HighlightPainter(this.shapes, this.colors);

  final List<HighlightShape> shapes;
  final AppColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    for (final kind in HighlightKind.values) {
      for (final shape in shapes) {
        if (shape.kind == kind) _paint(canvas, kind, shape.rect);
      }
    }
  }

  void _paint(Canvas canvas, HighlightKind kind, Rect rect) {
    switch (kind) {
      case HighlightKind.recitedAyah:
        canvas.drawRRect(
          _rounded(rect, AppRadius.radiusSm),
          Paint()..color = colors.highlightAyah,
        );
      case HighlightKind.selectedAyah:
        final outer = _rounded(rect, AppRadius.radiusSm);
        canvas
          ..drawRRect(outer, Paint()..color = colors.selection)
          ..drawDRRect(
            outer,
            outer.deflate(_frame),
            Paint()..color = colors.selectionLine,
          );
      case HighlightKind.searchMatch:
        _underlined(canvas, rect, colors.searchMatch, colors.info);
      case HighlightKind.spokenWord:
        _underlined(
          canvas,
          rect,
          colors.highlightWord,
          colors.highlightWordLine,
        );
    }
  }

  void _underlined(Canvas canvas, Rect rect, Color fill, Color line) {
    canvas
      ..save()
      ..clipRRect(_rounded(rect, _wordRadius))
      ..drawRect(rect, Paint()..color = fill)
      ..drawRect(
        Rect.fromLTRB(
          rect.left,
          rect.bottom - _underline,
          rect.right,
          rect.bottom,
        ),
        Paint()..color = line,
      )
      ..restore();
  }

  RRect _rounded(Rect rect, double radius) =>
      RRect.fromRectAndRadius(rect, Radius.circular(radius));

  @override
  bool shouldRepaint(HighlightPainter oldDelegate) =>
      oldDelegate.colors != colors || !listEquals(oldDelegate.shapes, shapes);
}
