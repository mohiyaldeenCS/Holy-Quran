import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/domain/models/sleep_timer.dart';

import 'current_plan.dart';

/// The sleep timer (`AU-07`): after 5 to 120 minutes, which the player fades
/// out, or at the end of the ayah or surah being heard. The minutes open at
/// the timer set, else at the least; a choice is set on the player at once
/// and carries over the plans the other sheets rebuild.
final class SleepSheetViewModel extends ChangeNotifier {
  SleepSheetViewModel({required this._player})
    : _minutes = switch (_player.sleepTimer) {
        SleepAfter(:final minutes) => minutes,
        _ => SleepAfter.minMinutes,
      };

  final PlayerRepository _player;
  int _minutes;

  /// False when nothing is playing: a stop ends the timer with the run.
  bool get available => runsIn(_player.state);

  /// False for a whole surah from a file without timing data, which has no
  /// ayah to end at (D-112).
  bool get offersEndOfAyah =>
      _player.state.plan?.supportsSleepTimer(const SleepAtEndOfAyah()) ?? false;

  SleepTimer? get timer => _player.sleepTimer;

  int get minutes => _minutes;

  int get min => SleepAfter.minMinutes;

  int get max => SleepAfter.maxMinutes;

  void setMinutes(int minutes) {
    final next = minutes.clamp(min, max);
    if (next == _minutes) return;
    _minutes = next;
    notifyListeners();
  }

  /// Sleeps after [minutes] from now.
  Future<bool> startMinutes() => _set(SleepAfter(_minutes));

  Future<bool> endOfAyah() => _set(const SleepAtEndOfAyah());

  Future<bool> endOfSurah() => _set(const SleepAtEndOfSurah());

  Future<bool> cancel() => _set(null);

  Future<bool> _set(SleepTimer? timer) async {
    final plan = _player.state.plan;
    if (!available || (timer != null && !plan!.supportsSleepTimer(timer))) {
      return false;
    }
    await _player.setSleepTimer(timer);
    notifyListeners();
    return true;
  }
}
