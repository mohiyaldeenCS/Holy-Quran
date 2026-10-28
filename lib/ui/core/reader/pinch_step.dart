import 'reader_text_scale.dart';
import 'surah_layout.dart';

/// The ladder index a pinch of [scale] leads to from step [current] of
/// `readerTextSteps`: the step nearest to the current size times [scale]
/// (`RD-07`, D-097).
int stepAfterPinch(int current, double scale) =>
    nearestReaderTextStep(readerTextSteps[current] * scale);

/// What a pinch keeps in place: an ayah, numbered from 1, and how far down
/// its lines the focal point lay, 0 at the top of its first line and 1 at the
/// bottom of its last.
typedef FocalAyah = ({int ayah, double fraction});

/// The ayah at [y], a position in [layout]'s sliver: the ayah of the line
/// there, the one the line continues when it starts inside an ayah. Above the
/// text it is the first ayah, past it the last.
FocalAyah focalAyahAt(SurahLayout layout, double y) {
  final line = ((y - layout.basmalaExtent) / layout.lineHeight).floor().clamp(
    0,
    layout.lines.length - 1,
  );
  final ayah = layout.lines[line].start.ayah + 1;
  final top = _top(layout, ayah);
  final height = _bottom(layout, ayah) - top;
  return (ayah: ayah, fraction: ((y - top) / height).clamp(0.0, 1.0));
}

/// Where [focal] lies in [layout], a plan of the same text at another size,
/// as a position in its sliver: scroll so that this stays under the fingers.
double yOfFocalAyah(SurahLayout layout, FocalAyah focal) {
  final top = _top(layout, focal.ayah);
  return top + focal.fraction * (_bottom(layout, focal.ayah) - top);
}

double _top(SurahLayout layout, int ayah) =>
    layout.basmalaExtent + layout.lineOfAyahText(ayah) * layout.lineHeight;

double _bottom(SurahLayout layout, int ayah) =>
    layout.basmalaExtent + (layout.lineOfAyahEnd(ayah) + 1) * layout.lineHeight;
