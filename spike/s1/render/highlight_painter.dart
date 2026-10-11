import 'package:flutter/widgets.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

/// Paints the highlights of `bundle.css` behind the glyphs, from text
/// geometry, so that the string and the layout never change with them.
///
/// [ayat] holds, per highlighted ayah, its rects in reading order, one per
/// line: `.qk-hl-ayah`, `highlight-ayah` with `radius-sm`. Its inline
/// padding (`padding: 0 4px`) is painted, not laid out, and only at the
/// ayah's two ends, as CSS slices an inline box across lines.
///
/// [words] holds the rects of spoken words: `.qk-hl-word`, `highlight-word`
/// with a 6 px radius and an inset 2 px `highlight-word-line` along the
/// bottom, the line being the state's non-colour signal.
///
/// [selected] holds, per selected ayah, its rects in reading order:
/// `.qk-hl-select`, `selection` with `radius-sm`, an inset 1.5 px
/// `selection-line` frame (the non-colour signal) and `padding: 0 4px`,
/// painted over the recitation highlights. Across lines it is sliced as
/// CSS slices an inline box: the padding, the frame's sides and the
/// rounded corners only at the ayah's two ends, its start on the right.
void paintHighlights(
  Canvas canvas,
  Offset offset, {
  required AppColors colors,
  Iterable<List<Rect>> ayat = const [],
  Iterable<Rect> words = const [],
  Iterable<List<Rect>> selected = const [],
}) {
  final ayahPaint = Paint()..color = colors.highlightAyah;
  for (final boxes in ayat) {
    for (final (index, box) in boxes.indexed) {
      final padded = Rect.fromLTRB(
        index == boxes.length - 1 ? box.left - AppSpacing.space1 : box.left,
        box.top,
        index == 0 ? box.right + AppSpacing.space1 : box.right,
        box.bottom,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          padded.shift(offset),
          const Radius.circular(AppRadius.radiusSm),
        ),
        ayahPaint,
      );
    }
  }
  final wordPaint = Paint()..color = colors.highlightWord;
  final linePaint = Paint()..color = colors.highlightWordLine;
  for (final box in words) {
    final shape = RRect.fromRectAndRadius(
      box.shift(offset),
      const Radius.circular(_wordRadius),
    );
    canvas
      ..drawRRect(shape, wordPaint)
      ..save()
      ..clipRRect(shape)
      ..drawRect(
        Rect.fromLTRB(
          shape.left,
          shape.bottom - _wordLine,
          shape.right,
          shape.bottom,
        ),
        linePaint,
      )
      ..restore();
  }
  _paintSelection(canvas, offset, colors, selected);
}

void _paintSelection(
  Canvas canvas,
  Offset offset,
  AppColors colors,
  Iterable<List<Rect>> selected,
) {
  const radius = Radius.circular(AppRadius.radiusSm);
  const inner = Radius.circular(AppRadius.radiusSm - _selectLine);
  final fill = Paint()..color = colors.selection;
  final line = Paint()..color = colors.selectionLine;
  for (final boxes in selected) {
    for (final (index, box) in boxes.indexed) {
      final starts = index == 0;
      final ends = index == boxes.length - 1;
      final slice = Rect.fromLTRB(
        ends ? box.left - AppSpacing.space1 : box.left,
        box.top,
        starts ? box.right + AppSpacing.space1 : box.right,
        box.bottom,
      ).shift(offset);
      final shape = RRect.fromRectAndCorners(
        slice,
        topRight: starts ? radius : Radius.zero,
        bottomRight: starts ? radius : Radius.zero,
        topLeft: ends ? radius : Radius.zero,
        bottomLeft: ends ? radius : Radius.zero,
      );
      // An open side's frame runs past the slice and is clipped away.
      final hole = RRect.fromRectAndCorners(
        Rect.fromLTRB(
          ends ? slice.left + _selectLine : slice.left - _selectLine,
          slice.top + _selectLine,
          starts ? slice.right - _selectLine : slice.right + _selectLine,
          slice.bottom - _selectLine,
        ),
        topRight: starts ? inner : Radius.zero,
        bottomRight: starts ? inner : Radius.zero,
        topLeft: ends ? inner : Radius.zero,
        bottomLeft: ends ? inner : Radius.zero,
      );
      canvas
        ..drawRRect(shape, fill)
        ..save()
        ..clipRRect(shape)
        ..drawPath(
          Path()
            ..fillType = PathFillType.evenOdd
            ..addRRect(shape)
            ..addRRect(hole),
          line,
        )
        ..restore();
    }
  }
}

// .qk-hl-word: `border-radius: 6px`.
const double _wordRadius = 6;

// .qk-hl-word: `box-shadow: inset 0 -2px 0 var(--highlight-word-line)`.
const double _wordLine = 2;

// .qk-hl-select: `box-shadow: inset 0 0 0 1.5px var(--selection-line)`.
const double _selectLine = 1.5;
