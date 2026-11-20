import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/domain/models/stop_after.dart';

/// Stop after the ayah, page or surah being heard (`AU-08`). A choice is set
/// on the player at once and carries over the plans the other sheets
/// rebuild; the sleep timer still comes first (`AU-23`).
final class StopAfterSheetViewModel extends ChangeNotifier {
  StopAfterSheetViewModel({required this._player});

  final PlayerRepository _player;

  /// False when nothing is playing.
  bool get available =>
      _player.state.plan != null && _player.state.stopReason == null;

  /// What the plan playing can stop after: a whole surah from a file without
  /// timing data has no ayah or page boundary, so only the surah (D-112).
  List<StopAfter> get options => switch (_player.state.plan) {
    final plan? => [
      for (final option in StopAfter.values)
        if (plan.supportsStopAfter(option)) option,
    ],
    null => const [],
  };

  StopAfter? get chosen => _player.stopAfter;

  /// Null stops nothing early.
  Future<bool> choose(StopAfter? stopAfter) async {
    if (!available || (stopAfter != null && !options.contains(stopAfter))) {
      return false;
    }
    await _player.setStopAfter(stopAfter);
    notifyListeners();
    return true;
  }
}
