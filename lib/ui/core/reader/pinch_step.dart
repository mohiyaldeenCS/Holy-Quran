import 'dart:ui';

import 'block_layout.dart';
import 'gesture_target.dart';
import 'reader_text_scale.dart';
import 'surah_layout.dart';
import 'tap_resolver.dart';

/// The ladder index a pinch of [scale] leads to from step [current] of
/// `readerTextSteps`: the step nearest to the current size times [scale]
/// (`RD-07`, D-097).
int stepAfterPinch(int current, double scale) =>
    nearestReaderTextStep(readerTextSteps[current] * scale);

/// What a pinch keeps in place: an ayah, numbered from 1, and how far down
/// its lines the focal point lay, 0 at the top of its first line and 1 at the
/// bottom of its last.
typedef FocalAyah = ({int ayah, double fraction});

/// The ayah under [point], in [block]'s coordinates: the ayah of the target
/// the tap rule finds there (D-097), not the ayah the line starts with, so a
/// line that ends one ayah and holds the start of the next gives the one
/// touched. Off every target it is the ayah of the line there.
FocalAyah focalAyahAt(BlockLayout block, Offset point) {
  final plan = block.plan;
  final y = _blockTop(block) + point.dy;
  final ayah = switch (targetInBlock(block, point)) {
    WordTarget(:final word) => word.ayah,
    WaqfMarkTarget(:final ayah) || MarkerTarget(:final ayah) => ayah.ayah,
    MarginTarget() => _ayahOfLine(plan, _lineAt(plan, y)),
  };
  return _focal(plan, ayah, y);
}

/// The ayah under [point], in [layout]'s sliver coordinates, taken from the
/// target there: the block holding the point is laid out in [ink] for the
/// moment this takes. Above the text it is the first ayah at its top, past
/// it the last at its bottom.
FocalAyah focalAyahUnder(
  SurahLayout layout,
  Offset point, {
  required Color ink,
}) {
  if (point.dy < layout.basmalaExtent || point.dy >= layout.height) {
    return focalAyahOfLine(layout, point.dy);
  }
  final line = _lineAt(layout, point.dy);
  final block = layout.blocks.indexWhere((b) => line < b.endLine);
  final laid = BlockLayout(layout, block, ink: ink);
  try {
    return focalAyahAt(laid, Offset(point.dx, point.dy - _blockTop(laid)));
  } finally {
    laid.dispose();
  }
}

/// The ayah of the line at [y], a position in [layout]'s sliver: the ayah
/// the line starts in, which a line that starts inside one continues. It is
/// what the top edge of the screen is at; for a finger use [focalAyahAt].
/// Above the text it is the first ayah, past it the last.
FocalAyah focalAyahOfLine(SurahLayout layout, double y) =>
    _focal(layout, _ayahOfLine(layout, _lineAt(layout, y)), y);

/// Where [focal] lies in [layout], a plan of the same text at another size,
/// as a position in its sliver: scroll so that this stays under the fingers.
double yOfFocalAyah(SurahLayout layout, FocalAyah focal) {
  final top = _top(layout, focal.ayah);
  return top + focal.fraction * (_bottom(layout, focal.ayah) - top);
}

FocalAyah _focal(SurahLayout layout, int ayah, double y) {
  final top = _top(layout, ayah);
  final height = _bottom(layout, ayah) - top;
  return (ayah: ayah, fraction: ((y - top) / height).clamp(0.0, 1.0));
}

double _blockTop(BlockLayout block) => block.plan.blockTop(block.index);

int _lineAt(SurahLayout layout, double y) =>
    ((y - layout.basmalaExtent) / layout.lineHeight).floor().clamp(
      0,
      layout.lines.length - 1,
    );

int _ayahOfLine(SurahLayout layout, int line) =>
    layout.lines[line].start.ayah + 1;

double _top(SurahLayout layout, int ayah) =>
    layout.basmalaExtent + layout.lineOfAyahText(ayah) * layout.lineHeight;

double _bottom(SurahLayout layout, int ayah) =>
    layout.basmalaExtent + (layout.lineOfAyahEnd(ayah) + 1) * layout.lineHeight;
