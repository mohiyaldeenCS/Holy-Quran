import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:holyquran/data/services/audio_engine_service.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/playback_plan.dart';
import 'package:holyquran/domain/models/playback_rules.dart';
import 'package:holyquran/domain/models/playback_segment.dart';
import 'package:holyquran/domain/models/player_state.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/domain/models/sleep_timer.dart';
import 'package:holyquran/domain/models/stop_after.dart';

/// Where a recitation's file is played from: its verified download, or its
/// address on the network when its rights record allows streaming.
typedef LocatedAudio = ({Uri uri, bool streamed});

/// Finds the file behind a segment of a plan; null when the recitation
/// offers none that may be played.
typedef RecitationFileLocator =
    Future<LocatedAudio?> Function(
      Recitation recitation,
      PlaybackSource source,
    );

/// A surah's name from the base pack, or null when it cannot be read.
typedef SurahNameLookup = Future<PackText?> Function(int surah);

/// The app-wide player (D-111): it runs a [PlaybackPlan] with its rules and
/// holds the state that the mini player, full player and reader read.
/// Listeners hear of every change.
abstract class PlayerRepository extends ChangeNotifier {
  PlayerState get state;

  SleepTimer? get sleepTimer;

  StopAfter? get stopAfter;

  /// Time left on a [SleepAfter].
  Duration? get sleepRemaining;

  /// Plays [plan] from its segment [startAt] in place of what is playing.
  /// The sleep timer and stop-after carry over where [plan] supports them.
  Future<void> play(PlaybackPlan plan, {int startAt = 0});

  Future<void> pause();

  /// Goes on from where playback paused, stopped or lost its connection.
  Future<void> resume();

  Future<void> stop();

  /// Within the current segment.
  Future<void> seek(Duration position);

  Future<void> nextAyah();

  Future<void> previousAyah();

  Future<void> nextSurah();

  Future<void> previousSurah();

  Future<void> setSpeed(PlaybackSpeed speed);

  /// Fails with a [StateError] when nothing is playing and an
  /// [ArgumentError] when the plan has no boundary for [timer].
  Future<void> setSleepTimer(SleepTimer? timer);

  /// Fails as [setSleepTimer] does.
  Future<void> setStopAfter(StopAfter? stopAfter);

  /// Adds [plan] at the end of the queue (`AU-17`).
  void enqueue(PlaybackPlan plan);

  /// Moves the queued plan at [from] to [to]; both are indexes before the
  /// move.
  void moveInQueue(int from, int to);

  void removeFromQueue(int index);
}

/// [PlayerRepository] over an [AudioEngineService].
final class EnginePlayerRepository extends PlayerRepository {
  EnginePlayerRepository({
    required this._engine,
    required this._locate,
    required this._surahName,
    this._now = DateTime.now,
  }) {
    _events = _engine.events.listen(
      (event) => unawaited(_serially(() => _onEngine(event))),
    );
  }

  /// How long the sleep timer fades playback out (`AU-07`); the PRD gives
  /// no length.
  static const sleepFade = Duration(seconds: 8);
  static const _fadeSteps = 16;

  final AudioEngineService _engine;
  final RecitationFileLocator _locate;
  final SurahNameLookup _surahName;
  final DateTime Function() _now;
  late final StreamSubscription<EngineEvent> _events;

  PlayerState _state = PlayerState.idle;
  PlaybackRules? _rules;
  bool _activated = false;
  bool _failed = false;
  int _serial = 0;
  int _trackIds = 0;
  int? _playingTrack;
  _Preload? _preload;
  _Preload? _engineAhead;
  int? _announcedSurah;
  Timer? _silenceTimer;
  DateTime? _silenceEnds;
  Duration? _silenceLeft;
  Timer? _sleepAlarm;
  Timer? _fade;
  int _fadeRun = 0;
  bool _volumeLowered = false;
  Future<void> _tail = Future.value();

  @override
  PlayerState get state => _state;

  @override
  SleepTimer? get sleepTimer => _rules?.sleepTimer;

  @override
  StopAfter? get stopAfter => _rules?.stopAfter;

  @override
  Duration? get sleepRemaining => _rules?.sleepRemaining;

  @override
  Future<void> play(PlaybackPlan plan, {int startAt = 0}) =>
      _serially(() => _start(plan, startAt));

  @override
  Future<void> pause() => _serially(_pause);

  @override
  Future<void> resume() => _serially(_resume);

  @override
  Future<void> stop() => _serially(() => _handle(const UserStopped()));

  @override
  Future<void> seek(Duration position) => _serially(() => _seek(position));

  @override
  Future<void> nextAyah() => _serially(_nextAyah);

  @override
  Future<void> previousAyah() => _serially(_previousAyah);

  @override
  Future<void> nextSurah() => _serially(
    () => _jumpForward((s, current) => s.address.surah != current.surah),
  );

  @override
  Future<void> previousSurah() =>
      _serially(() => _jumpBack((s) => s.address.surah));

  @override
  Future<void> setSpeed(PlaybackSpeed speed) => _serially(() async {
    await _engine.setSpeed(speed.factor);
    _update(_state.copyWith(speed: speed));
  });

  @override
  Future<void> setSleepTimer(SleepTimer? timer) => _serially(() async {
    _running.sleepTimer = timer;
    _armSleepAlarm();
    notifyListeners();
    await _refreshNext();
  });

  @override
  Future<void> setStopAfter(StopAfter? stopAfter) => _serially(() async {
    _running.stopAfter = stopAfter;
    notifyListeners();
    await _refreshNext();
  });

  @override
  void enqueue(PlaybackPlan plan) =>
      _update(_state.copyWith(queue: [..._state.queue, plan]));

  @override
  void moveInQueue(int from, int to) {
    final queue = [..._state.queue];
    RangeError.checkValidIndex(to, queue, 'to');
    queue.insert(to, queue.removeAt(from));
    _update(_state.copyWith(queue: queue));
  }

  @override
  void removeFromQueue(int index) =>
      _update(_state.copyWith(queue: [..._state.queue]..removeAt(index)));

  @override
  void dispose() {
    _cancelSilence();
    _sleepAlarm?.cancel();
    _fade?.cancel();
    unawaited(_events.cancel());
    super.dispose();
  }

  PlaybackRules get _running => switch (_rules) {
    final rules? when !rules.isStopped => rules,
    _ => throw StateError('nothing is playing'),
  };

  /// Runs [action] after every earlier one, so that engine events and
  /// commands never interleave.
  Future<void> _serially(Future<void> Function() action) {
    final done = _tail.then((_) => action());
    _tail = done.catchError((Object _) {});
    return done;
  }

  void _update(PlayerState next) {
    _state = next;
    notifyListeners();
  }

  Future<void> _start(PlaybackPlan plan, int startAt) async {
    final rules =
        _rules?.handOver(plan, startAt: startAt) ??
        PlaybackRules(plan, clock: _now, startAt: startAt);
    _cancelSilence();
    await _cancelFade();
    _rules = rules;
    _announcedSurah = null;
    _failed = false;
    _preload = null;
    _engineAhead = null;
    _playingTrack = null;
    _armSleepAlarm();
    _update(
      _state.copyWith(
        plan: plan,
        position: Duration.zero,
        inSilence: false,
        stopReason: () => null,
        error: () => null,
      ),
    );
    if (!_activated) {
      try {
        await _engine.activate();
      } on Exception {
        _rules = null;
        _update(
          _state.copyWith(
            playing: false,
            error: () => PlayerError.playbackFailed,
          ),
        );
        return;
      }
      _activated = true;
    }
    await _apply(rules.start());
  }

  Future<void> _handle(PlaybackInput input) async {
    final rules = _rules;
    if (rules == null) return;
    await _apply(rules.handle(input));
  }

  Future<void> _apply(List<PlaybackOutput> outputs) async {
    for (final output in outputs) {
      switch (output) {
        case SegmentStarted(:final segment, :final index, :final serial):
          await _segmentStarted(segment, index, serial);
        case AyahStarted(:final ayah):
          _update(_state.copyWith(ayah: ayah));
        case SilenceStarted(:final duration):
          await _startSilence(duration);
        case PlaybackStopped(:final reason, :final fade):
          await _stopped(reason, fade: fade);
      }
    }
  }

  Future<void> _segmentStarted(
    PlaybackSegment segment,
    int index,
    int serial,
  ) async {
    _serial = serial;
    _cancelSilence();
    _update(
      _state.copyWith(
        segment: segment,
        segmentIndex: index,
        position: Duration.zero,
        playing: true,
        inSilence: false,
      ),
    );
    final ahead = _engineAhead;
    _engineAhead = null;
    _preload = null;
    if (ahead != null && identical(ahead.segment, segment)) {
      _playingTrack = ahead.track.id;
      if (ahead.held) await _engine.resume();
      await _refreshNext();
    } else {
      final track = await _trackFor(segment);
      if (track == null) return;
      _playingTrack = track.id;
      await _engine.play(track, next: await _nextTrack());
    }
    await _announce(segment.address.surah);
  }

  /// Sets the engine's next track to the plan's next segment when it
  /// follows the current one directly, so that it plays with no gap; with a
  /// silence or a stop due in between, the engine holds instead.
  Future<void> _refreshNext() async {
    if (_rules == null || _failed || _playingTrack == null) return;
    final before = _preload;
    final next = await _nextTrack();
    if (next?.id == before?.track.id) return;
    await _engine.setNext(next);
  }

  Future<EngineTrack?> _nextTrack() async {
    final rules = _rules!;
    final current = rules.current;
    final upcoming = rules.upcoming;
    if (current == null || upcoming == null || !_followsDirectly(current)) {
      _preload = null;
      return null;
    }
    if (_preload case final preload?
        when identical(preload.segment, upcoming)) {
      return preload.track;
    }
    final located = await _locate(_state.plan!.recitation, upcoming.source);
    if (located == null) {
      _preload = null;
      return null;
    }
    final track = _track(upcoming, located);
    _preload = _Preload(upcoming, track);
    return track;
  }

  // Mirrors the end-of-segment checks of PlaybackRules, which keep them
  // private; the rules still decide, this only chooses what to preload.
  bool _followsDirectly(PlaybackSegment current) {
    final rules = _rules!;
    if (current.silenceAfter > Duration.zero) return false;
    final stops = switch (rules.stopAfter) {
      StopAfter.ayah => current.kind == SegmentKind.ayah,
      StopAfter.page => current.endsPage,
      StopAfter.surah => current.endsSurah,
      null => false,
    };
    final sleeps = switch (rules.sleepTimer) {
      SleepAtEndOfAyah() => current.kind == SegmentKind.ayah,
      SleepAtEndOfSurah() => current.endsSurah,
      SleepAfter() || null => false,
    };
    return !stops && !sleeps;
  }

  Future<EngineTrack?> _trackFor(PlaybackSegment segment) async {
    final located = await _locate(_state.plan!.recitation, segment.source);
    if (located == null) {
      await _fail(PlayerError.fileMissing);
      return null;
    }
    return _track(segment, located);
  }

  EngineTrack _track(PlaybackSegment segment, LocatedAudio located) {
    final clip = segment.source;
    return EngineTrack(
      id: ++_trackIds,
      uri: located.uri,
      streamed: located.streamed,
      start: clip is SurahClip ? clip.start : null,
      end: clip is SurahClip ? clip.end : null,
    );
  }

  Future<void> _announce(int surah) async {
    if (_announcedSurah == surah) return;
    _announcedSurah = surah;
    await _engine.setMediaInfo(
      MediaInfo(
        surahName: await _surahName(surah),
        reciter: _state.plan!.recitation.reciter,
      ),
    );
  }

  Future<void> _startSilence(Duration duration) async {
    _update(_state.copyWith(inSilence: true));
    if (_state.playing) {
      _runSilence(duration);
    } else {
      _silenceLeft = duration;
    }
    final upcoming = _rules!.upcoming;
    if (upcoming == null) return;
    final located = await _locate(_state.plan!.recitation, upcoming.source);
    if (located == null) return;
    final track = _track(upcoming, located);
    _playingTrack = null;
    await _engine.load(track);
    _engineAhead = _Preload(upcoming, track, held: true);
  }

  void _runSilence(Duration duration) {
    final serial = _serial;
    _silenceEnds = _now().add(duration);
    _silenceTimer = Timer(
      duration,
      () => unawaited(_serially(() => _handle(SilenceEnded(serial)))),
    );
  }

  void _cancelSilence() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _silenceEnds = null;
    _silenceLeft = null;
  }

  void _armSleepAlarm() {
    _sleepAlarm?.cancel();
    _sleepAlarm = null;
    final left = _rules?.sleepRemaining;
    if (left == null) return;
    _sleepAlarm = Timer(
      left,
      () => unawaited(_serially(() => _handle(const SleepTimerFired()))),
    );
  }

  Future<void> _stopped(StopReason reason, {required bool fade}) async {
    _cancelSilence();
    _sleepAlarm?.cancel();
    _preload = null;
    _engineAhead = null;
    _playingTrack = null;
    _update(
      _state.copyWith(
        playing: false,
        inSilence: false,
        stopReason: () => reason,
      ),
    );
    // The next queued plan replaces the engine's tracks without a stop, so
    // the media session stays in front.
    if (reason == StopReason.endOfPlan && _state.queue.isNotEmpty) {
      final [next, ...rest] = _state.queue;
      _update(_state.copyWith(queue: rest));
      return _start(next, 0);
    }
    if (fade) {
      await _engine.setNext(null);
      _fadeOut();
    } else {
      await _engine.stop();
    }
  }

  /// Steps the volume down over [sleepFade], then stops. Playing again
  /// before the end cancels it.
  void _fadeOut() {
    final run = ++_fadeRun;
    var step = 0;
    _volumeLowered = true;
    _fade = Timer.periodic(sleepFade ~/ _fadeSteps, (timer) {
      step++;
      if (step < _fadeSteps) {
        unawaited(_engine.setVolume(1 - step / _fadeSteps));
        return;
      }
      timer.cancel();
      _fade = null;
      unawaited(
        _serially(() async {
          if (run == _fadeRun) await _restoreVolume();
        }),
      );
    });
  }

  Future<void> _cancelFade() async {
    _fadeRun++;
    _fade?.cancel();
    _fade = null;
    if (_volumeLowered) await _restoreVolume();
  }

  Future<void> _restoreVolume() async {
    _volumeLowered = false;
    await _engine.stop();
    await _engine.setVolume(1);
  }

  Future<void> _seek(Duration position) async {
    if (_playingTrack == null || _state.inSilence || _failed) return;
    await _engine.seek(position);
    _update(_state.copyWith(position: position));
  }

  Future<void> _pause() async {
    final rules = _rules;
    if (rules == null || rules.isStopped || !_state.playing) return;
    if (_silenceEnds case final ends?) {
      final left = ends.difference(_now());
      _cancelSilence();
      _silenceLeft = left.isNegative ? Duration.zero : left;
    }
    if (_state.inSilence) {
      await _engine.setSessionPlaying(false);
    } else {
      await _engine.pause();
    }
    _update(_state.copyWith(playing: false));
  }

  Future<void> _resume() async {
    final rules = _rules;
    final plan = _state.plan;
    if (rules == null || plan == null) return;
    if (rules.isStopped) {
      return _start(plan, _state.segmentIndex ?? 0);
    }
    if (_state.playing) return;
    _update(_state.copyWith(playing: true, error: () => null));
    if (_failed) return _reload();
    if (_state.inSilence) {
      _runSilence(_silenceLeft ?? Duration.zero);
      _silenceLeft = null;
      return _engine.setSessionPlaying(true);
    }
    await _engine.resume();
  }

  /// Plays the current segment again from the position kept when the
  /// connection was lost.
  Future<void> _reload() async {
    final segment = _rules!.current!;
    _failed = false;
    _preload = null;
    final track = await _trackFor(segment);
    if (track == null) return;
    _playingTrack = track.id;
    await _engine.play(track, next: await _nextTrack(), from: _state.position);
  }

  Future<void> _fail(PlayerError error) async {
    _failed = true;
    _cancelSilence();
    _preload = null;
    _engineAhead = null;
    _playingTrack = null;
    await _engine.stop();
    _update(_state.copyWith(playing: false, error: () => error));
  }

  Future<void> _nextAyah() => _jumpForward(
    (segment, current) =>
        segment.address.surah != current.surah ||
        segment.address.ayah != current.ayah,
  );

  Future<void> _previousAyah() =>
      _jumpBack((segment) => (segment.address.surah, segment.address.ayah));

  Future<void> _jumpForward(
    bool Function(PlaybackSegment segment, ({int surah, int ayah}) current)
    wanted,
  ) async {
    final (plan, index, current) = _position() ?? (null, 0, null);
    if (plan == null || current == null) return;
    final here = (surah: current.address.surah, ayah: current.address.ayah);
    var at = 0;
    for (final segment in plan.segments) {
      if (at > index) {
        if (wanted(segment, here)) return _start(plan, at);
        // A plan repeating without end never reaches another ayah once it
        // comes back to this one.
        if (plan.repeat.isUnlimited &&
            segment.kind == current.kind &&
            segment.address == current.address) {
          return;
        }
      }
      at++;
    }
  }

  /// Goes to the start of the run of segments, grouped by [key], before
  /// the current run; from the first run, to its start.
  Future<void> _jumpBack(Object Function(PlaybackSegment segment) key) async {
    final (plan, index, current) = _position() ?? (null, 0, null);
    if (plan == null || current == null) return;
    var previousRun = 0;
    var currentRun = 0;
    Object? runKey;
    var at = 0;
    for (final segment in plan.segments.take(index + 1)) {
      final segmentKey = key(segment);
      if (at == 0 || segmentKey != runKey) {
        previousRun = currentRun;
        currentRun = at;
        runKey = segmentKey;
      }
      at++;
    }
    await _start(plan, currentRun == 0 ? 0 : previousRun);
  }

  (PlaybackPlan, int, PlaybackSegment)? _position() {
    final plan = _state.plan;
    final index = _state.segmentIndex;
    final segment = _state.segment;
    if (_rules == null || plan == null || index == null || segment == null) {
      return null;
    }
    return (plan, index, segment);
  }

  Future<void> _onEngine(EngineEvent event) async {
    switch (event) {
      case TrackEnded(:final id) when id == _playingTrack:
        _engineAhead = _preload;
        _preload = null;
        _playingTrack = _engineAhead?.track.id;
        await _handle(SegmentEnded(_serial));
      case TrackEnded():
        break;
      case PositionChanged(:final position):
        if (!_state.inSilence && !_failed && _playingTrack != null) {
          _update(_state.copyWith(position: position));
        }
      case BufferingChanged(:final buffering):
        _update(_state.copyWith(buffering: buffering));
      case EngineFailed(:final failure):
        if (_rules == null || _rules!.isStopped) return;
        // Only the next ayah's preload failed; it is fetched again when
        // the silence ends.
        if (_state.inSilence) {
          _engineAhead = null;
          return;
        }
        await _fail(switch (failure) {
          EngineFailure.connection => PlayerError.connectionFailed,
          EngineFailure.playback => PlayerError.playbackFailed,
        });
      case RemoteCommandReceived(:final command):
        await switch (command) {
          RemotePlay() => _resume(),
          RemotePause() => _pause(),
          RemoteStop() => _handle(const UserStopped()),
          RemoteNext() => _nextAyah(),
          RemotePrevious() => _previousAyah(),
          RemoteSeek(:final position) => _seek(position),
        };
    }
  }
}

final class _Preload {
  const _Preload(this.segment, this.track, {this.held = false});

  final PlaybackSegment segment;
  final EngineTrack track;

  /// Loaded and paused at its start, rather than queued after the current
  /// track.
  final bool held;
}
