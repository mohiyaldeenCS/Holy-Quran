import 'dart:async';

import '../models/listening_position.dart';
import '../models/playback_rules.dart';
import '../models/playback_segment.dart';
import '../models/player_state.dart';

/// Keeps the listening position (`AU-16`, D-106) from the player's states:
/// it is saved when playback pauses or stops, and every [interval] while it
/// plays, so that a killed app loses at most that much.
///
/// The offset is the time within the segment heard, which is what the player
/// seeks to when listening goes on. It is zero in a basmala or isti'adha,
/// whose ayah is the one after them, in a silence, whose segment has been
/// heard to its end, and after the plan has ended.
final class RecordListeningPosition {
  RecordListeningPosition({
    required this._save,
    this.interval = const Duration(seconds: 10),
  });

  final Duration interval;
  final Future<void> Function(ListeningPosition position) _save;
  PlayerState? _latest;
  Timer? _timer;

  /// Tells of the player's state after each change.
  void update(PlayerState state) {
    final wasPlaying = _latest?.playing ?? false;
    _latest = state;
    if (state.playing) {
      _timer ??= Timer.periodic(interval, (_) => _record());
    } else if (wasPlaying) {
      _timer?.cancel();
      _timer = null;
      _record();
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  void _record() {
    final state = _latest;
    final plan = state?.plan;
    final segment = state?.segment;
    if (state == null || plan == null || segment == null) return;
    final heard =
        (segment.kind == SegmentKind.ayah ||
            segment.kind == SegmentKind.surah) &&
        !state.inSilence &&
        state.stopReason != StopReason.endOfPlan;
    unawaited(
      _save(
        ListeningPosition(
          address: segment.address,
          recitationId: plan.recitation.id,
          offset: heard ? state.position : Duration.zero,
        ),
      ),
    );
  }
}
