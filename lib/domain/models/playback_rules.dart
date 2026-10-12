import 'playback_plan.dart';
import 'playback_segment.dart';
import 'quran_address.dart';
import 'sleep_timer.dart';
import 'stop_after.dart';

/// What the engine reports to the rules.
sealed class PlaybackInput {
  const PlaybackInput();
}

/// The segment started with [serial] ended; any other serial is stale and
/// ignored, so a late or repeated report never skips a segment.
final class SegmentEnded extends PlaybackInput {
  const SegmentEnded(this.serial);

  final int serial;
}

/// The silence after the segment started with [serial] ended.
final class SilenceEnded extends PlaybackInput {
  const SilenceEnded(this.serial);

  final int serial;
}

/// The engine's timer for a [SleepAfter] went off; the rules check the
/// clock, so a stale timer does nothing.
final class SleepTimerFired extends PlaybackInput {
  const SleepTimerFired();
}

final class UserStopped extends PlaybackInput {
  const UserStopped();
}

/// What the rules tell the engine and the reader.
sealed class PlaybackOutput {
  const PlaybackOutput();
}

final class SegmentStarted extends PlaybackOutput {
  const SegmentStarted(this.segment, this.index, this.serial);

  final PlaybackSegment segment;

  /// Its position in the plan, from 0.
  final int index;

  /// Counts every segment started, across hand-overs, so that the end of a
  /// segment from a replaced plan never matches one of the new plan.
  final int serial;
}

/// The reader follows this ayah (D-112).
final class AyahStarted extends PlaybackOutput {
  const AyahStarted(this.ayah);

  final QuranAddress ayah;
}

final class SilenceStarted extends PlaybackOutput {
  const SilenceStarted(this.duration);

  final Duration duration;
}

enum StopReason { sleepTimer, stopAfter, user, endOfPlan }

final class PlaybackStopped extends PlaybackOutput {
  const PlaybackStopped(this.reason, {this.fade = false});

  final StopReason reason;

  /// Whether the engine fades out first: only when a [SleepAfter] stops
  /// playback in the middle of a segment.
  final bool fade;
}

enum _State { idle, playing, silent, stopped }

/// Runs a [PlaybackPlan]: at the end of each segment the sleep timer comes
/// first, then stop-after, then the plan's next segment, which already holds
/// its repeats before any continuation (`AU-23`).
final class PlaybackRules {
  /// Playback begins at the plan's segment [startAt]; a position past the
  /// plan's end throws a [RangeError].
  PlaybackRules(this.plan, {required this.clock, int startAt = 0})
    : _segments = plan.segments.iterator,
      _index = startAt - 1 {
    RangeError.checkNotNegative(startAt, 'startAt');
    for (var skipped = 0; skipped < startAt; skipped++) {
      if (!_segments.moveNext()) {
        throw RangeError.value(startAt, 'startAt', 'is past the plan end');
      }
    }
    _pull();
    if (_upcoming == null) {
      throw RangeError.value(startAt, 'startAt', 'is past the plan end');
    }
  }

  final PlaybackPlan plan;
  final DateTime Function() clock;
  final Iterator<PlaybackSegment> _segments;

  _State _state = _State.idle;
  PlaybackSegment? _current;
  PlaybackSegment? _upcoming;
  int _index;
  int _serial = 0;
  SleepTimer? _sleepTimer;
  DateTime? _sleepDeadline;
  StopAfter? _stopAfter;

  /// The segment playing, or the one just heard during a silence.
  PlaybackSegment? get current => _current;

  /// The position of [current] in the plan, from 0; null before start.
  int? get index => _current == null ? null : _index;

  /// The segment after [current], for the engine to preload (`AU-12`); null
  /// at the end of the plan and once stopped.
  PlaybackSegment? get upcoming => isStopped ? null : _upcoming;

  bool get isStopped => _state == _State.stopped;

  SleepTimer? get sleepTimer => _sleepTimer;

  StopAfter? get stopAfter => _stopAfter;

  /// Time left on a [SleepAfter], never negative.
  Duration? get sleepRemaining {
    final deadline = _sleepDeadline;
    if (deadline == null) return null;
    final left = deadline.difference(clock());
    return left.isNegative ? Duration.zero : left;
  }

  /// A [SleepAfter] counts from now. Throws an [ArgumentError] when the plan
  /// has no boundary for [timer].
  set sleepTimer(SleepTimer? timer) {
    if (timer != null && !plan.supportsSleepTimer(timer)) {
      throw ArgumentError.value(timer, 'timer', 'needs ayah boundaries');
    }
    _sleepTimer = timer;
    _sleepDeadline = timer is SleepAfter ? clock().add(timer.duration) : null;
  }

  /// Throws an [ArgumentError] when the plan has no boundary for [stopAfter].
  set stopAfter(StopAfter? stopAfter) {
    if (stopAfter != null && !plan.supportsStopAfter(stopAfter)) {
      throw ArgumentError.value(
        stopAfter,
        'stopAfter',
        'needs ayah boundaries',
      );
    }
    _stopAfter = stopAfter;
  }

  /// Rules for [plan] from its segment [startAt], as when the user moves to
  /// another ayah or surah: the sleep timer keeps its deadline and the
  /// stop-after carries over where [plan] supports them; a stopped run has
  /// no sleep timer left, since a stop ends it. Serials go on from this
  /// run's, so hand over from the current run only: this one is finished.
  PlaybackRules handOver(PlaybackPlan plan, {int startAt = 0}) {
    final next = PlaybackRules(plan, clock: clock, startAt: startAt)
      .._serial = _serial;
    if (_sleepTimer case final timer? when plan.supportsSleepTimer(timer)) {
      next
        .._sleepTimer = timer
        .._sleepDeadline = _sleepDeadline;
    }
    if (_stopAfter case final stopAfter?
        when plan.supportsStopAfter(stopAfter)) {
      next._stopAfter = stopAfter;
    }
    return next;
  }

  List<PlaybackOutput> start() {
    if (_state != _State.idle) {
      throw StateError('playback has already started');
    }
    return _next();
  }

  List<PlaybackOutput> handle(PlaybackInput input) => switch ((input, _state)) {
    (_, _State.stopped || _State.idle) => const [],
    (UserStopped(), _) => _stop(StopReason.user),
    (SleepTimerFired(), final state) =>
      _sleepTimeUp
          ? _stop(StopReason.sleepTimer, fade: state == _State.playing)
          : const [],
    (SegmentEnded(:final serial), _State.playing) when serial == _serial =>
      _afterSegment(),
    (SilenceEnded(:final serial), _State.silent) when serial == _serial =>
      _sleepTimeUp ? _stop(StopReason.sleepTimer) : _next(),
    (SegmentEnded() || SilenceEnded(), _) => const [],
  };

  bool get _sleepTimeUp {
    final deadline = _sleepDeadline;
    return deadline != null && !clock().isBefore(deadline);
  }

  List<PlaybackOutput> _afterSegment() {
    final ended = _current!;
    if (_sleepsAfter(ended)) return _stop(StopReason.sleepTimer);
    if (_stopsAfter(ended)) return _stop(StopReason.stopAfter);
    if (ended.silenceAfter > Duration.zero) {
      _state = _State.silent;
      return [SilenceStarted(ended.silenceAfter)];
    }
    return _next();
  }

  bool _sleepsAfter(PlaybackSegment ended) =>
      _sleepTimeUp ||
      switch (_sleepTimer) {
        SleepAtEndOfAyah() => ended.kind == SegmentKind.ayah,
        SleepAtEndOfSurah() => ended.endsSurah,
        SleepAfter() || null => false,
      };

  bool _stopsAfter(PlaybackSegment ended) => switch (_stopAfter) {
    StopAfter.ayah => ended.kind == SegmentKind.ayah,
    StopAfter.page => ended.endsPage,
    StopAfter.surah => ended.endsSurah,
    null => false,
  };

  void _pull() => _upcoming = _segments.moveNext() ? _segments.current : null;

  List<PlaybackOutput> _next() {
    final segment = _upcoming;
    if (segment == null) return _stop(StopReason.endOfPlan);
    _current = segment;
    _index++;
    _serial++;
    _pull();
    _state = _State.playing;
    return [
      SegmentStarted(segment, _index, _serial),
      if (segment.kind == SegmentKind.ayah) AyahStarted(segment.address),
    ];
  }

  List<PlaybackOutput> _stop(StopReason reason, {bool fade = false}) {
    _state = _State.stopped;
    _sleepTimer = null;
    _sleepDeadline = null;
    return [PlaybackStopped(reason, fade: fade)];
  }
}
