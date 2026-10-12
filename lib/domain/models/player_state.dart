import 'playback_plan.dart';
import 'playback_rules.dart';
import 'playback_segment.dart';
import 'quran_address.dart';

/// Playback speed, from 0.5 to 2.0 in steps of 0.25 (`AU-06`).
final class PlaybackSpeed {
  const PlaybackSpeed._(this._quarters);

  static const _minQuarters = 2;
  static const _maxQuarters = 8;

  static const normal = PlaybackSpeed._(4);

  static const List<PlaybackSpeed> all = [
    PlaybackSpeed._(2),
    PlaybackSpeed._(3),
    normal,
    PlaybackSpeed._(5),
    PlaybackSpeed._(6),
    PlaybackSpeed._(7),
    PlaybackSpeed._(_maxQuarters),
  ];

  final int _quarters;

  double get factor => _quarters / 4;

  bool get isSlowest => _quarters == _minQuarters;

  bool get isFastest => _quarters == _maxQuarters;

  /// One step faster; the fastest stays as it is.
  PlaybackSpeed get faster => isFastest ? this : PlaybackSpeed._(_quarters + 1);

  /// One step slower; the slowest stays as it is.
  PlaybackSpeed get slower => isSlowest ? this : PlaybackSpeed._(_quarters - 1);

  @override
  bool operator ==(Object other) =>
      other is PlaybackSpeed && other._quarters == _quarters;

  @override
  int get hashCode => _quarters.hashCode;

  @override
  String toString() => 'PlaybackSpeed($factor)';
}

/// Why playback cannot go on.
enum PlayerError {
  /// The network was lost while streaming; the position is kept.
  connectionFailed,

  /// The recitation has no file for the segment.
  fileMissing,

  /// The player could not decode or play the file.
  playbackFailed,
}

/// The app-wide player, as the mini player, full player and reader read it
/// (D-111).
final class PlayerState {
  const PlayerState({
    this.plan,
    this.segment,
    this.segmentIndex,
    this.ayah,
    this.position = Duration.zero,
    this.playing = false,
    this.buffering = false,
    this.inSilence = false,
    this.speed = PlaybackSpeed.normal,
    this.queue = const [],
    this.stopReason,
    this.error,
  });

  static const idle = PlayerState();

  /// The plan being played, or the last one played; null before any.
  final PlaybackPlan? plan;

  /// The segment heard, or the one just heard during a silence.
  final PlaybackSegment? segment;

  /// Its position in [plan], from 0.
  final int? segmentIndex;

  /// The ayah the reader follows (D-112).
  final QuranAddress? ayah;

  /// Within [segment].
  final Duration position;
  final bool playing;
  final bool buffering;
  final bool inSilence;
  final PlaybackSpeed speed;

  /// Plans waiting to be played after [plan], in order (`AU-17`).
  final List<PlaybackPlan> queue;

  /// Why the last plan stopped; null while it runs.
  final StopReason? stopReason;
  final PlayerError? error;

  /// Which hearing of its repeat unit [segment] is, from 1 (`AU-09`).
  int? get repeat => segment?.repeat;

  PlayerState copyWith({
    PlaybackPlan? plan,
    PlaybackSegment? segment,
    int? segmentIndex,
    QuranAddress? ayah,
    Duration? position,
    bool? playing,
    bool? buffering,
    bool? inSilence,
    PlaybackSpeed? speed,
    List<PlaybackPlan>? queue,
    StopReason? Function()? stopReason,
    PlayerError? Function()? error,
  }) => PlayerState(
    plan: plan ?? this.plan,
    segment: segment ?? this.segment,
    segmentIndex: segmentIndex ?? this.segmentIndex,
    ayah: ayah ?? this.ayah,
    position: position ?? this.position,
    playing: playing ?? this.playing,
    buffering: buffering ?? this.buffering,
    inSilence: inSilence ?? this.inSilence,
    speed: speed ?? this.speed,
    queue: queue == null ? this.queue : List.unmodifiable(queue),
    stopReason: stopReason == null ? this.stopReason : stopReason(),
    error: error == null ? this.error : error(),
  );
}
