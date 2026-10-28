import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/domain/models/playback_plan.dart';
import 'package:holyquran/domain/models/playback_plan_builder.dart';

import 'current_plan.dart';

/// The silence between ayat (`AU-11`), from 0 to 30 seconds, opening at
/// that of the plan playing. Playing builds the plan playing then again with
/// it and goes on from the segment being heard, which a silence does not
/// move.
final class SilenceSheetViewModel extends ChangeNotifier with PlaysOnce {
  SilenceSheetViewModel({required this._player, required this._builder})
    : _seconds = _player.state.plan?.silence.inSeconds ?? 0;

  final PlayerRepository _player;
  final PlaybackPlanBuilder _builder;
  int _seconds;

  /// False before any plan, and for whole surahs from surah files without
  /// timing data, which have no ayat to space out (D-112).
  bool get available => _player.state.plan?.hasAyahBoundaries ?? false;

  int get seconds => _seconds;

  int get min => 0;

  int get max => PlaybackPlanBuilder.maxSilence.inSeconds;

  void setSeconds(int seconds) {
    final next = seconds.clamp(min, max);
    if (next == _seconds) return;
    _seconds = next;
    notifyListeners();
  }

  Future<bool> play() => playOnce(() async {
    final plan = _player.state.plan;
    if (plan == null || !available) return false;
    final outcome = rebuildPlan(
      _builder,
      plan,
      silence: PlaybackPlanBuilder.silenceOf(_seconds),
    );
    if (outcome is! PlanReady) return false;
    await _player.play(outcome.plan, startAt: _player.state.segmentIndex ?? 0);
    return true;
  });
}
