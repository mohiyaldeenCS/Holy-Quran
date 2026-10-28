import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/domain/models/playback_plan.dart';
import 'package:holyquran/domain/models/playback_plan_builder.dart';
import 'package:holyquran/domain/models/repeat_mode.dart';

import 'current_plan.dart';

/// The repeat count (`AU-09`), from 1 to 99, opening at the count of the
/// plan playing. Its unit stays the plan's. Playing builds the plan playing
/// then again with the count and goes on from the segment being heard.
///
/// A plan without end opens at 1 and stays without end until the count is
/// changed: the sheet has no choice for it yet, so playing then changes
/// nothing.
final class RepeatSheetViewModel extends ChangeNotifier with PlaysOnce {
  RepeatSheetViewModel({required this._player, required this._builder})
    : _count = switch (_player.state.plan) {
        final plan? => plan.repeat.count,
        null => RepeatMode.minCount,
      };

  final PlayerRepository _player;
  final PlaybackPlanBuilder _builder;

  /// Null while a plan without end is left as it is.
  int? _count;

  /// False before any plan, and when the plan repeats ayat or pages of
  /// surah files without timing data, which repeat whole surahs only
  /// (D-112).
  bool get available => switch (_player.state.plan) {
    final plan? =>
      plan.hasAyahBoundaries ||
          plan.repeat.unit == RepeatUnit.range ||
          plan.repeat.unit == RepeatUnit.surah,
    null => false,
  };

  int get count => _count ?? min;

  int get min => RepeatMode.minCount;

  int get max => RepeatMode.maxCount;

  void setCount(int count) {
    final next = count.clamp(min, max);
    if (next == _count) return;
    _count = next;
    notifyListeners();
  }

  Future<bool> play() => playOnce(() async {
    final state = _player.state;
    final plan = state.plan;
    if (plan == null || !available) return false;
    final count = _count;
    if (count == null && plan.repeat.isUnlimited) return true;
    final outcome = rebuildPlan(
      _builder,
      plan,
      repeat: count == null ? plan.repeat : RepeatMode(plan.repeat.unit, count),
    );
    if (outcome is! PlanReady) return false;
    await _player.play(
      outcome.plan,
      startAt: segmentOf(outcome.plan, heardIn(state)),
    );
    return true;
  });
}
