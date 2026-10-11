import 'dart:math' as math;
import 'dart:ui';

import 'package:holyquran/ui/core/theme/tokens.g.dart';

import 'gesture_target.dart';
import 'target_geometry.dart';

/// How a point in a text block becomes a target (D-095). Every rule ranks
/// equal candidates marker, then mark, then word, and a rect belongs to the
/// band that holds its centre.
enum TapRule {
  /// The target whose rect holds the point, else the margin.
  exact,

  /// Off the shown bands, the margin. On a band, the target horizontally
  /// nearest the point (0 inside it), or the margin if the band has none.
  nearestOnLine,

  /// Markers and marks first, each over a zone: its rect grown about its
  /// centre to at least the minimum target each way; of the zones holding
  /// the point, the one with the nearest centre. Else [nearestOnLine].
  priorityZones,

  /// As [priorityZones], except that a point more than a quarter of the
  /// minimum target inside both side edges of a word's rect, on its band,
  /// is that word.
  priorityZonesWithSlop,
}

/// The target at [p], in block coordinates, under [rule]. [minTarget] is
/// the zone size of [TapRule.priorityZones]: `target-min` (AX-02).
GestureTarget resolveTap(
  Offset p,
  TargetGeometry g,
  TapRule rule, {
  double minTarget = AppSizes.targetMin,
}) => switch (rule) {
  TapRule.exact => _exact(p, g),
  TapRule.nearestOnLine => _nearestOnLine(p, g),
  TapRule.priorityZones => _zoned(p, g, minTarget) ?? _nearestOnLine(p, g),
  TapRule.priorityZonesWithSlop =>
    _slopWord(p, g, minTarget) ??
        _zoned(p, g, minTarget) ??
        _nearestOnLine(p, g),
};

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
  for (final MapEntry(key: word, value: rects) in g.words.entries) {
    for (final rect in rects) {
      yield (target: WordTarget(word), rect: rect, rank: 2);
    }
  }
}

GestureTarget _exact(Offset p, TargetGeometry g) {
  _Candidate? best;
  for (final c in _candidates(g)) {
    if (c.rect.contains(p) && (best == null || c.rank < best.rank)) best = c;
  }
  return best?.target ?? const MarginTarget();
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

GestureTarget? _zoned(Offset p, TargetGeometry g, double minTarget) {
  _Candidate? best;
  var bestDistance = double.infinity;
  for (final c in _candidates(g, words: false)) {
    final zone = Rect.fromCenter(
      center: c.rect.center,
      width: math.max(c.rect.width, minTarget),
      height: math.max(c.rect.height, minTarget),
    );
    if (!zone.contains(p)) continue;
    final distance = (p - c.rect.center).distance;
    if (distance < bestDistance ||
        (distance == bestDistance && c.rank < best!.rank)) {
      best = c;
      bestDistance = distance;
    }
  }
  return best?.target;
}

GestureTarget? _slopWord(Offset p, TargetGeometry g, double minTarget) {
  final band = g.bandAt(p.dy);
  if (band == null) return null;
  final line = g.lineBands[band];
  final slop = minTarget / 4;
  for (final MapEntry(key: word, value: rects) in g.words.entries) {
    for (final rect in rects) {
      final y = rect.center.dy;
      if (y >= line.top &&
          y < line.bottom &&
          p.dx > rect.left + slop &&
          p.dx < rect.right - slop) {
        return WordTarget(word);
      }
    }
  }
  return null;
}

double _horizontalDistance(Rect rect, double x) => x < rect.left
    ? rect.left - x
    : x > rect.right
    ? x - rect.right
    : 0;
