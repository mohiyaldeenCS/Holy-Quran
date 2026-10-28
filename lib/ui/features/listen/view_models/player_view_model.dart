import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/playback_segment.dart';
import 'package:holyquran/domain/models/player_state.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/surah_info.dart';

/// The app-wide player as the full player and the mini player show it
/// (`AU-05`, `AU-06`). The repository runs every action in turn, so the
/// actions are plain calls rather than commands that drop a second tap; a
/// failure is reported, and the player's state says what the listener
/// sees.
final class PlayerViewModel extends ChangeNotifier {
  PlayerViewModel({required this._player, required this._index}) {
    _player.addListener(notifyListeners);
  }

  final PlayerRepository _player;
  final QuranIndexRepository _index;

  PlayerState get _state => _player.state;

  /// A plan is loaded and has not stopped, playing or paused: the only time
  /// the mini player shows (PRD §8.21, the acceptance criterion of `LV`).
  bool get active => _state.plan != null && _state.stopReason == null;

  bool get hasPlan => _state.plan != null;

  bool get playing => _state.playing;

  String? get reciter => _state.plan?.recitation.reciter;

  String? get style => _state.plan?.recitation.style;

  // The segment, not PlayerState.ayah: that keeps the last plan's ayah until
  // the new plan reaches an ayah of its own, as a plan of whole surahs never
  // does, and would name the wrong surah. The player sets an ayah only after
  // the segment that holds it, so there is none without a segment.
  QuranAddress? get _ayah => _state.segment?.address;

  SurahInfo? get surah => switch (_ayah) {
    final ayah? =>
      _index.surahs.where((info) => info.number == ayah.surah).firstOrNull,
    null => null,
  };

  /// The ayah heard, when the plan knows its ayat; a recitation served as
  /// whole surahs without timing data does not (D-112).
  int? get ayah => _state.plan?.hasAyahBoundaries ?? false ? _ayah?.ayah : null;

  int? get page => switch ((_ayah, surah)) {
    (final ayah?, _?) => _index.positionOf(ayah).page,
    _ => null,
  };

  /// The network was lost while streaming; the position is kept. The other
  /// errors have no wording yet.
  bool get connectionFailed => _state.error == PlayerError.connectionFailed;

  PlaybackSpeed get speed => _state.speed;

  /// How far the segment has played, from 0 to 1; null when its length is
  /// not known, which is so for every segment but a clip of a surah file.
  double? get progress => switch (_length) {
    final length? =>
      (_state.position.inMicroseconds / length.inMicroseconds).clamp(0.0, 1.0),
    null => null,
  };

  Duration? get _length => switch (_state.segment?.source) {
    SurahClip(:final start, :final end) => end - start,
    _ => null,
  };

  /// Where a play from the ayah tools ends (`AU-03`); null for any other
  /// range, which has no label.
  AyahToolEnd? get rangeEnd => switch (_state.plan?.range) {
    FromAyahTool(:final until) => until,
    SingleAyah() => AyahToolEnd.ayah,
    _ => null,
  };

  /// The repeat count when each unit is heard more than once.
  int? get repeatCount => switch (_state.plan?.repeat.count) {
    final count? when count > 1 => count,
    _ => null,
  };

  /// The silence after each ayah in whole seconds, when there is one.
  int? get silenceSeconds => switch (_state.plan?.silence.inSeconds) {
    final seconds? when seconds > 0 => seconds,
    _ => null,
  };

  Future<void> playPause() => _run(playing ? _player.pause : _player.resume);

  Future<void> nextAyah() => _run(_player.nextAyah);

  Future<void> previousAyah() => _run(_player.previousAyah);

  /// Moves to [fraction] of the segment, from 0 to 1.
  Future<void> seekTo(double fraction) async {
    final length = _length;
    if (length == null) return;
    await _run(() => _player.seek(length * fraction.clamp(0.0, 1.0)));
  }

  /// Moves by [step], forward or, when negative, back, within the segment.
  Future<void> seekBy(Duration step) async {
    final length = _length;
    if (length == null) return;
    final target = _state.position + step;
    await _run(
      () => _player.seek(
        target.isNegative ? Duration.zero : (target > length ? length : target),
      ),
    );
  }

  /// One step faster, and from the fastest back to the slowest (`AU-06`).
  Future<void> nextSpeed() => _run(
    () => _player.setSpeed(
      speed.isFastest ? PlaybackSpeed.all.first : speed.faster,
    ),
  );

  // The views call these without awaiting them.
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on Exception catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack, library: 'player'),
      );
    }
  }

  @override
  void dispose() {
    _player.removeListener(notifyListeners);
    super.dispose();
  }
}
