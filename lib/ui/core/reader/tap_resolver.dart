import 'dart:math' as math;
import 'dart:ui';

import 'package:holyquran/ui/core/theme/tokens.g.dart';

import 'block_layout.dart';
import 'gesture_target.dart';
import 'target_geometry.dart';

/// The one tap rule (D-097): S7's `priorityZonesWithSlop`.
///
/// Markers and marks come first, each over a [tapZone]; of the zones holding
/// the point, the one with the nearest centre wins, a marker before a mark
/// on a tie. A point more than a quarter of the minimum target inside both
/// side edges of a word, on its band, is that word, ahead of the zones.
/// Anywhere else on a band the target horizontally nearest the point (0
/// inside it); off the bands, or on one with no target, the margin.
///
/// S7 measured it on the real text at 1.0x: words 99.0, 98.1, 96.6 and 90.0%
/// at 0, 6, 12 and 18 px from the target, marks 100, 99.98, 99.98 and 91.4%,
/// markers 100, 100, 100 and 99.4%. A rect belongs to the band that holds
/// its centre.
GestureTarget resolveTap(Offset p, TargetGeometry g) =>
    _slopWord(p, g) ?? _zoned(p, g) ?? _nearestOnLine(p, g);

/// The target at [p], in block coordinates, with geometry taken only near it.
GestureTarget targetInBlock(BlockLayout layout, Offset p) {
  const reach = AppSizes.targetMin;
  final geometry = TargetGeometry.of(
    layout,
    within: Rect.fromLTRB(0, p.dy - reach, layout.width, p.dy + reach),
  );
  return resolveTap(p, geometry);
}

/// [rect] grown about its centre to at least `target-min` each way (`AX-02`).
Rect tapZone(Rect rect) => Rect.fromCenter(
  center: rect.center,
  width: math.max(rect.width, AppSizes.targetMin),
  height: math.max(rect.height, AppSizes.targetMin),
);

// S7's `priorityZonesWithSlop`: a quarter of the minimum target.
const double _wordSlop = AppSizes.targetMin / 4;

typedef _Candidate = ({GestureTarget target, Rect rect, int rank});

/// Markers, then marks, then words: the order ties are settled in.
Iterable<_Candidate> _candidates(TargetGeometry g, {bool words = true}) sync* {
  for (final MapEntry(key: ayah, value: rect) in g.markers.entries) {
    yield (target: MarkerTarget(ayah), rect: rect, rank: 0);
  }
  for (final MapEntry(key: (ayah, mark), value: rect) in g.marks.entries) {
    yield (target: WaqfMarkTarget(ayah, mark), rect: rect, rank: 1);
  }
  if (!words) return;
  for (final MapEntry(key: word, value: rect) in g.words.entries) {
    yield (target: WordTarget(word), rect: rect, rank: 2);
  }
}

GestureTarget? _slopWord(Offset p, TargetGeometry g) {
  final band = g.bandAt(p.dy);
  if (band == null) return null;
  final line = g.lineBands[band];
  for (final MapEntry(key: word, value: rect) in g.words.entries) {
    final y = rect.center.dy;
    if (y >= line.top &&
        y < line.bottom &&
        p.dx > rect.left + _wordSlop &&
        p.dx < rect.right - _wordSlop) {
      return WordTarget(word);
    }
  }
  return null;
}

GestureTarget? _zoned(Offset p, TargetGeometry g) {
  _Candidate? best;
  var bestDistance = double.infinity;
  for (final c in _candidates(g, words: false)) {
    if (!tapZone(c.rect).contains(p)) continue;
    final distance = (p - c.rect.center).distance;
    if (distance < bestDistance ||
        (distance == bestDistance && c.rank < best!.rank)) {
      best = c;
      bestDistance = distance;
    }
  }
  return best?.target;
}

GestureTarget _nearestOnLine(Offset p, TargetGeometry g) {
  final band = g.bandAt(p.dy);
  if (band == null) return const MarginTarget();
  final line = g.lineBands[band];
  _Candidate? best;
  var bestDistance = double.infinity;
  for (final c in _candidates(g)) {
    final y = c.rect.center.dy;
    if (y < line.top || y >= line.bottom) continue;
    final distance = _horizontalDistance(c.rect, p.dx);
    if (distance < bestDistance ||
        (distance == bestDistance && c.rank < best!.rank)) {
      best = c;
      bestDistance = distance;
    }
  }
  return best?.target ?? const MarginTarget();
}

double _horizontalDistance(Rect rect, double x) => x < rect.left
    ? rect.left - x
    : x > rect.right
    ? x - rect.right
    : 0;
