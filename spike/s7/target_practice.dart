import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';

import 'gesture_log.dart';
import 'target_geometry.dart';

// :focus-visible: outline 2px solid var(--focus), as `FocusRing` draws it.
const double _ringWidth = 2;
// :focus-visible: outline-offset 2px.
const double _ringGap = 2;

/// A target the participant is asked to tap, in block coordinates.
typedef PracticeTarget = ({
  LoggedTarget kind,
  QuranAddress address,
  int? mark,
  Rect box,
});

/// A target of [geometry] whose box has a positive size and lies wholly
/// inside [visible]: first a kind at random among the kinds that have one,
/// then one of that kind at random. Words drawn on two lines are left out.
/// Null when none qualifies.
PracticeTarget? pickPracticeTarget(
  TargetGeometry geometry,
  Rect visible,
  Random random,
) {
  bool fits(Rect box) =>
      box.width > 0 &&
      box.height > 0 &&
      visible.contains(box.topLeft) &&
      visible.contains(box.bottomRight);
  final byKind = <LoggedTarget, List<PracticeTarget>>{
    LoggedTarget.word: [
      for (final MapEntry(key: word, value: rects) in geometry.words.entries)
        if (rects.length == 1 && fits(rects.single))
          (
            kind: LoggedTarget.word,
            address: word,
            mark: null,
            box: rects.single,
          ),
    ],
    LoggedTarget.waqfMark: [
      for (final MapEntry(key: (ayah, mark), value: box)
          in geometry.marks.entries)
        if (fits(box))
          (kind: LoggedTarget.waqfMark, address: ayah, mark: mark, box: box),
    ],
    LoggedTarget.marker: [
      for (final MapEntry(key: ayah, value: box) in geometry.markers.entries)
        if (fits(box))
          (kind: LoggedTarget.marker, address: ayah, mark: null, box: box),
    ],
  }..removeWhere((_, targets) => targets.isEmpty);
  if (byKind.isEmpty) return null;
  final kinds = byKind.keys.toList();
  final targets = byKind[kinds[random.nextInt(kinds.length)]]!;
  return targets[random.nextInt(targets.length)];
}

typedef HitRate = ({int trials, int hits});

/// The practice trials of [entries] and their hits, by expected kind.
Map<LoggedTarget, HitRate> hitRatesByKind(Iterable<GestureLogEntry> entries) =>
    _rates(entries, (entry) => entry.expectedTarget!);

/// The practice trials of [entries] and their hits, by tap rule.
Map<String, HitRate> hitRatesByRule(Iterable<GestureLogEntry> entries) =>
    _rates(entries, (entry) => entry.rule ?? 'none');

Map<K, HitRate> _rates<K>(
  Iterable<GestureLogEntry> entries,
  K Function(GestureLogEntry) key,
) {
  final rates = <K, HitRate>{};
  for (final entry in entries.where((entry) => entry.isTrial)) {
    final last = rates[key(entry)] ?? (trials: 0, hits: 0);
    rates[key(entry)] = (
      trials: last.trials + 1,
      hits: last.hits + (entry.isHit ? 1 : 0),
    );
  }
  return rates;
}

Map<String, Object> hitRatesJson(Map<String, HitRate> rates) => {
  for (final MapEntry(:key, :value) in rates.entries)
    key: {'trials': value.trials, 'hits': value.hits},
};

/// The ring around the practice target: the identity's focus outline, 2 px
/// of `focus` 2 px outside [box]. It takes no touches.
final class PracticeRing extends StatelessWidget {
  const PracticeRing({required this.box, super.key});

  final Rect box;

  @override
  Widget build(BuildContext context) => Positioned.fromRect(
    rect: box.inflate(_ringGap + _ringWidth),
    child: IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: context.colors.focus, width: _ringWidth),
        ),
      ),
    ),
  );
}
