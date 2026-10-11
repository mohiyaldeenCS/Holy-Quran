import 'dart:math' as math;
import 'dart:ui';

import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

import '../s1/render/surah_paragraph.dart';
import 'gesture_target.dart';
import 'tap_resolver.dart';
import 'target_geometry.dart';

/// The text sizes a pinch steps through, as text scales (RD-07: 80% to
/// 200%). Provisional: the spike's choice, to be settled with the owner.
const List<double> textSizeSteps = [0.8, 0.9, 1.0, 1.15, 1.3, 1.5, 1.75, 2.0];

/// The step a pinch of [scale] leads to from [current]: the step nearest
/// current times scale on a log scale, held to the ladder. A [current] off
/// the ladder counts as its nearest step.
double stepAfterPinch(double current, double scale) =>
    _nearestStep(_nearestStep(current) * scale);

double _nearestStep(double value) {
  if (value <= textSizeSteps.first) return textSizeSteps.first;
  final log = math.log(value);
  var best = textSizeSteps.first;
  for (final step in textSizeSteps) {
    if ((math.log(step) - log).abs() < (math.log(best) - log).abs()) {
      best = step;
    }
  }
  return best;
}

/// What a pinch keeps in place: an ayah and how far down its shown boxes
/// the focal point lay, 0 at the top of its first line and 1 at the bottom
/// of its last.
typedef FocalAyah = ({QuranAddress ayah, double fraction});

/// The ayah under [point], in block coordinates: the ayah of the target
/// [TapRule.nearestOnLine] finds there. Null off the shown lines.
FocalAyah? focalAyahAt(SurahParagraph paragraph, Offset point) {
  const reach = AppSizes.targetMin;
  final geometry = TargetGeometry.of(
    paragraph,
    within: Rect.fromLTRB(
      0,
      point.dy - reach,
      paragraph.width,
      point.dy + reach,
    ),
  );
  final ayah = switch (resolveTap(point, geometry, TapRule.nearestOnLine)) {
    WordTarget(:final word) => word.ayahAddress,
    WaqfMarkTarget(:final ayah) || MarkerTarget(:final ayah) => ayah,
    MarginTarget() => null,
  };
  if (ayah == null) return null;
  final boxes = paragraph.boxesOf(ayah);
  if (boxes.isEmpty) return null;
  final top = boxes.first.top;
  final height = boxes.last.bottom - top;
  return (
    ayah: ayah,
    fraction: height > 0 ? ((point.dy - top) / height).clamp(0.0, 1.0) : 0,
  );
}

/// Where [focal] lies in [paragraph], laid out at another size, in block
/// coordinates; null when its ayah is not shown there. V1 only: a V2 block
/// would need the plan up to the ayah (S1 finding 3).
double? yOfFocalAyah(SurahParagraph paragraph, FocalAyah focal) {
  final boxes = paragraph.boxesOf(focal.ayah);
  if (boxes.isEmpty) return null;
  final top = boxes.first.top;
  return top + focal.fraction * (boxes.last.bottom - top);
}
