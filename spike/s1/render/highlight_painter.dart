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
void paintHighlights(
  Canvas canvas,
  Offset offset, {
  required AppColors colors,
  Iterable<List<Rect>> ayat = const [],
  Iterable<Rect> words = const [],
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
}

// .qk-hl-word: `border-radius: 6px`.
const double _wordRadius = 6;

// .qk-hl-word: `box-shadow: inset 0 -2px 0 var(--highlight-word-line)`.
const double _wordLine = 2;
