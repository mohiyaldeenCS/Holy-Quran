import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

/// Paints the highlights of `bundle.css` behind the glyphs, from text
/// geometry, so that the string and the layout never change with them:
/// the ayah highlight, the selection over it, and the spoken words on top,
/// as the identity puts word marks above the ayah's span.
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
/// [selected] holds, per selected ayah, its rects in reading order, each
/// as tall as its line, and whether its start and its end are among them:
/// `.qk-hl-select`, `selection` with `radius-sm`, an inset 1.5 px
/// `selection-line` frame (the non-colour signal) and `padding: 0 4px`,
/// painted, not laid out. Across lines it is sliced as CSS slices an
/// inline box: the padding, the frame's sides and the rounded corners only
/// at the ayah's two ends, its start on the right. Where a slice lies on
/// the one below, that one's top line is the only line between them, as
/// the next line's fill covers the bottom line in CSS. Slices are held
/// inside 0 to [width], so that the viewport never clips the frame's sides.
void paintHighlights(
  Canvas canvas,
  Offset offset, {
  required AppColors colors,
  Iterable<List<Rect>> ayat = const [],
  Iterable<Rect> words = const [],
  Iterable<SelectedAyah> selected = const [],
  double width = double.infinity,
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
  _paintSelection(canvas, offset, colors, selected, width);
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
}

/// A selected ayah's shown rects, in reading order, and whether its first
/// character and its marker are among them.
typedef SelectedAyah = ({List<Rect> boxes, bool starts, bool ends});

typedef _Slice = ({Rect rect, bool starts, bool ends});

/// [box] with the padding at the ayah's ends, held inside [left] to
/// [right].
_Slice _sliceOf(
  Rect box, {
  required bool starts,
  required bool ends,
  required double left,
  required double right,
}) => (
  rect: Rect.fromLTRB(
    math.max(ends ? box.left - AppSpacing.space1 : box.left, left),
    box.top,
    math.min(starts ? box.right + AppSpacing.space1 : box.right, right),
    box.bottom,
  ),
  starts: starts,
  ends: ends,
);

void _paintSelection(
  Canvas canvas,
  Offset offset,
  AppColors colors,
  Iterable<SelectedAyah> selected,
  double width,
) {
  const radius = Radius.circular(AppRadius.radiusSm);
  const inner = Radius.circular(AppRadius.radiusSm - _selectLine);
  final fill = Paint()..color = colors.selection;
  final line = Paint()..color = colors.selectionLine;
  final slices = <_Slice>[
    for (final ayah in selected)
      for (final (index, box) in ayah.boxes.indexed)
        _sliceOf(
          box.shift(offset),
          starts: ayah.starts && index == 0,
          ends: ayah.ends && index == ayah.boxes.length - 1,
          left: offset.dx,
          right: offset.dx + width,
        ),
  ];
  for (final (:rect, :starts, :ends) in slices) {
    final shape = RRect.fromRectAndCorners(
      rect,
      topRight: starts ? radius : Radius.zero,
      bottomRight: starts ? radius : Radius.zero,
      topLeft: ends ? radius : Radius.zero,
      bottomLeft: ends ? radius : Radius.zero,
    );
    // An open side's frame runs past the slice and is clipped away.
    final hole = RRect.fromRectAndCorners(
      Rect.fromLTRB(
        ends ? rect.left + _selectLine : rect.left - _selectLine,
        rect.top + _selectLine,
        starts ? rect.right - _selectLine : rect.right + _selectLine,
        rect.bottom - _selectLine,
      ),
      topRight: starts ? inner : Radius.zero,
      bottomRight: starts ? inner : Radius.zero,
      topLeft: ends ? inner : Radius.zero,
      bottomLeft: ends ? inner : Radius.zero,
    );
    var frame = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(shape)
      ..addRRect(hole);
    for (final below in slices) {
      final covered = Rect.fromLTRB(
        math.max(rect.left, below.rect.left),
        rect.bottom - _selectLine,
        math.min(rect.right, below.rect.right),
        rect.bottom,
      );
      if ((below.rect.top - rect.bottom).abs() < _touching &&
          covered.width > 0) {
        frame = Path.combine(
          PathOperation.difference,
          frame,
          Path()..addRect(covered),
        );
      }
    }
    canvas
      ..drawRRect(shape, fill)
      ..save()
      ..clipRRect(shape)
      ..drawPath(frame, line)
      ..restore();
  }
}

// .qk-hl-word: `border-radius: 6px`.
const double _wordRadius = 6;

// .qk-hl-word: `box-shadow: inset 0 -2px 0 var(--highlight-word-line)`.
const double _wordLine = 2;

// .qk-hl-select: `box-shadow: inset 0 0 0 1.5px var(--selection-line)`.
const double _selectLine = 1.5;

// Slices of adjacent lines share an edge, up to float error.
const double _touching = 0.01;
