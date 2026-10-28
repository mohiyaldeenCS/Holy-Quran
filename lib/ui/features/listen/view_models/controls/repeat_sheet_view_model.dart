import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/domain/models/playback_plan.dart';
import 'package:holyquran/domain/models/playback_plan_builder.dart';
import 'package:holyquran/domain/models/repeat_mode.dart';

import 'current_plan.dart';

/// The repeat count (`AU-09`), from 1 to 99, opening at the count of the
/// plan playing. Its unit stays the plan's. Playing builds the plan playing
/// then again with the count and goes on from the ayah being heard.
final class RepeatSheetViewModel extends ChangeNotifier with PlaysOnce {
  RepeatSheetViewModel({required this._player, required this._builder})
    : _count = _player.state.plan?.repeat.count ?? RepeatMode.minCount;

  final PlayerRepository _player;
  final PlaybackPlanBuilder _builder;
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

  void setCount(int count) {
    final next = count.clamp(min, max);
    if (next == _count) return;
    _count = next;
    notifyListeners();
  }

  Future<bool> play() => playOnce(() async {
    if (_outcome() case PlanReady(:final plan)) {
      await _player.play(plan, startAt: segmentOf(plan, _player.state.ayah));
      return true;
    }
    return false;
  });

  PlanOutcome? _outcome() => switch (_player.state.plan) {
    final plan? when available => rebuildPlan(
      _builder,
      plan,
      repeat: RepeatMode(plan.repeat.unit, _count),
    ),
    _ => null,
  };
}
