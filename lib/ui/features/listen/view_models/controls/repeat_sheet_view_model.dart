import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/domain/models/playback_plan.dart';
import 'package:holyquran/domain/models/playback_plan_builder.dart';
import 'package:holyquran/domain/models/repeat_mode.dart';

import 'current_plan.dart';

/// The repeat count (`AU-09`), from 1 to 99 or without end, opening at the
/// repeat of the plan playing. Its unit stays the plan's. Playing builds the
/// plan playing then again with the repeat and goes on from the segment
/// being heard. Without end, the plan is built on the repeat unit being
/// heard, the only one it plays; a plan without end left without end is not
/// rebuilt.
final class RepeatSheetViewModel extends ChangeNotifier with PlaysOnce {
  RepeatSheetViewModel({required this._player, required this._builder})
    : _unlimited = _player.state.plan?.repeat.isUnlimited ?? false,
      _count = _player.state.plan?.repeat.count ?? RepeatMode.minCount;

  final PlayerRepository _player;
  final PlaybackPlanBuilder _builder;

  bool _unlimited;
  int _count;

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

  int get count => _count;

  int get min => RepeatMode.minCount;

  int get max => RepeatMode.maxCount;

  /// «بلا نهاية»: setting a count turns it off.
  bool get unlimited => _unlimited;

  void setCount(int count) {
    final next = count.clamp(min, max);
    if (next == _count && !_unlimited) return;
    _count = next;
    _unlimited = false;
    notifyListeners();
  }

  void setUnlimited(bool unlimited) {
    if (unlimited == _unlimited) return;
    _unlimited = unlimited;
    notifyListeners();
  }

  Future<bool> play() => playOnce(() async {
    final state = _player.state;
    final plan = state.plan;
    if (plan == null || !available) return false;
    if (_unlimited && plan.repeat.isUnlimited) return true;
    final unit = plan.repeat.unit;
    final heard = heardIn(state);
    final outcome = rebuildPlan(
      _builder,
      plan,
      range: _unlimited && heard != null
          ? _builder.unitHolding(plan, heard)
          : null,
      repeat: _unlimited
          ? RepeatMode.unlimited(unit)
          : RepeatMode(unit, _count),
    );
    if (outcome is! PlanReady) return false;
    await _player.play(outcome.plan, startAt: segmentOf(outcome.plan, heard));
    return true;
  });
}
