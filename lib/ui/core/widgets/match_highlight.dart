import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/search_match.dart';
import 'package:holyquran/ui/core/reader/highlight_painter.dart';
import 'package:holyquran/ui/core/reader/highlight_shapes.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

/// The search matches of a paragraph (`Match`, `.qk-hl-search`): a tint with
/// a line under it, painted behind the glyphs of [paragraph] at [matches],
/// offsets into the text it draws. The text is not split into spans, so its
/// shaping and its string are exactly what they would be without a match.
/// The line is the second cue besides the colour (`AX-05`).
///
/// [paragraph] must be a [RichText], which this widget lays out as its only
/// child.
final class MatchHighlight extends SingleChildRenderObjectWidget {
  const MatchHighlight({
    required this.matches,
    required Widget paragraph,
    super.key,
  }) : super(child: paragraph);

  final List<SearchMatch> matches;

  @override
  RenderMatchHighlight createRenderObject(BuildContext context) =>
      RenderMatchHighlight(matches, context.colors);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderMatchHighlight renderObject,
  ) {
    renderObject
      ..matches = matches
      ..colors = context.colors;
  }
}

class RenderMatchHighlight extends RenderProxyBox {
  RenderMatchHighlight(this._matches, this._colors);

  List<SearchMatch> _matches;
  set matches(List<SearchMatch> value) {
    if (listEquals(value, _matches)) return;
    _matches = value;
    _shapes = null;
    markNeedsPaint();
  }

  AppColors _colors;
  set colors(AppColors value) {
    if (value == _colors) return;
    _colors = value;
    markNeedsPaint();
  }

  List<HighlightShape>? _shapes;
  double _fontHeight = 0;

  /// The rects the matches fill, one for each line they cover; for tests.
  List<Rect> get rects => [for (final shape in _shapesOf()) shape.rect];

  @override
  void performLayout() {
    super.performLayout();
    _shapes = null;
    if (child case final RenderParagraph paragraph) {
      _fontHeight = _fontHeightOf(paragraph);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final shapes = _shapesOf();
    if (shapes.isNotEmpty) {
      context.canvas
        ..save()
        ..translate(offset.dx, offset.dy);
      HighlightPainter(shapes, _colors).paint(context.canvas, size);
      context.canvas.restore();
    }
    super.paint(context, offset);
  }

  List<HighlightShape> _shapesOf() {
    final cached = _shapes;
    if (cached != null) return cached;
    final paragraph = child;
    if (paragraph is! RenderParagraph || !paragraph.hasSize) return const [];
    return _shapes = [
      for (final match in _matches)
        for (final box in paragraph.getBoxesForSelection(
          TextSelection(baseOffset: match.start, extentOffset: match.end),
          boxHeightStyle: BoxHeightStyle.max,
        ))
          (
            kind: HighlightKind.searchMatch,
            rect: _fontBox(box).intersect(Offset.zero & size),
          ),
    ];
  }

  // The board's inline background is as tall as the font's own box, not the
  // line, and the style spreads its leading evenly, so the box sits in the
  // middle of the line.
  Rect _fontBox(TextBox line) {
    final height = _fontHeight.clamp(0.0, line.bottom - line.top);
    final top = (line.top + line.bottom - height) / 2;
    return Rect.fromLTRB(line.left, top, line.right, top + height);
  }

  double _fontHeightOf(RenderParagraph paragraph) {
    final style = paragraph.text.style;
    final painter = TextPainter(
      text: TextSpan(
        text: ' ',
        style: TextStyle(
          fontFamily: style?.fontFamily,
          fontSize: style?.fontSize,
        ),
      ),
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
      locale: paragraph.locale,
    )..layout();
    final metrics = painter.computeLineMetrics().first;
    painter.dispose();
    return metrics.ascent + metrics.descent;
  }
}
