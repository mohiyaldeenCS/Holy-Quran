import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/services/audio_engine_service.dart';
import 'package:holyquran/data/services/audio_handler.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/player_state.dart';
import 'package:holyquran/domain/models/playback_plan.dart';
import 'package:holyquran/domain/models/playback_plan_builder.dart';
import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/playback_rules.dart';
import 'package:holyquran/domain/models/playback_segment.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_range.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/domain/models/repeat_mode.dart';
import 'package:holyquran/domain/models/sleep_timer.dart';
import 'package:holyquran/domain/models/stop_after.dart';

import 'package:just_audio/just_audio.dart' hide PlayerState;

/// One playlist change on its way to the platform: the Dart-side list has
/// changed when it is issued, the platform when it [arrives], and the
/// caller hears of it when it is replied to.
final class _Change {
  _Change(this.kind, this.epoch, this.apply);

  final String kind;

  /// The load the change was issued after; a later load leaves it nothing
  /// to change.
  final int epoch;
  final void Function() apply;
  final reply = Completer<void>();
  bool arrived = false;
}

/// What the platform reported and Dart has not yet seen.
sealed class _Outbound {}

final class _Advanced extends _Outbound {
  _Advanced(this.from, this.to);

  final int from;
  final int to;
}

final class _Completed extends _Outbound {}

/// A player whose events the test sends and whose playlist changes finish
/// only when the test says so, as on a device where a change takes a moment
/// to reach the platform. It follows just_audio 0.10.6: the Dart-side
/// playlist changes when a change is issued, the platform's when the change
/// arrives, and an advance reaches [positionDiscontinuityStream] only if
/// the Dart-side playlist holds the track advanced to (just_audio.dart
/// 287-304).
final class _FakePlayer extends Fake implements AudioPlayer {
  final _states = StreamController<ProcessingState>.broadcast(sync: true);
  final _jumps = StreamController<PositionDiscontinuity>.broadcast(sync: true);
  final _errors = StreamController<PlayerException>.broadcast(sync: true);
  final _playbackEvents = StreamController<PlaybackEvent>.broadcast();
  final _held = <String>{};
  final _pending = <String, List<_Change>>{};

  /// Every command, in the order the player received it.
  final List<String> calls = [];

  /// The Dart-side playlist, as just_audio's `sequence` holds it.
  final List<AudioSource> _sources = [];

  final List<AudioSource> _platform = [];
  final List<_Outbound> _outbox = [];
  int _current = 0;
  bool _completed = false;
  bool _playing = false;
  int _epoch = 0;

  @override
  Stream<ProcessingState> get processingStateStream => _states.stream;

  @override
  Stream<PositionDiscontinuity> get positionDiscontinuityStream =>
      _jumps.stream;

  @override
  Stream<PlayerException> get errorStream => _errors.stream;

  @override
  Stream<PlaybackEvent> get playbackEventStream => _playbackEvents.stream;

  @override
  Stream<Duration?> get durationStream => const Stream.empty();

  @override
  Stream<Duration> createPositionStream({
    int steps = 800,
    Duration minPeriod = const Duration(milliseconds: 200),
    Duration maxPeriod = const Duration(milliseconds: 200),
  }) => const Stream.empty();

  @override
  ProcessingState get processingState => ProcessingState.ready;

  @override
  Duration get position => Duration.zero;

  @override
  Duration get bufferedPosition => Duration.zero;

  @override
  Duration? get duration => null;

  @override
  double get speed => 1;

  @override
  List<AudioSource> get audioSources => List.unmodifiable(_sources);

  /// Makes the next [kind] commands ('load', 'add' or 'remove') wait for
  /// [release], or for [arrive] and then [reply].
  void hold(String kind) => _held.add(kind);

  void unhold(String kind) => _held.remove(kind);

  /// The names of the tracks in the Dart-side playlist, in order.
  List<String> get names => [for (final source in _sources) _name(source)];

  /// The names of the tracks the platform holds, in order.
  List<String> get platformNames => [
    for (final source in _platform) _name(source),
  ];

  /// The track the platform is playing, if it is playing one.
  String? get audible =>
      _playing && hasHead ? _name(_platform[_current]) : null;

  /// Whether the platform has a track that has not ended.
  bool get hasHead => !_completed && _current < _platform.length;

  bool get hasUnseen => _outbox.isNotEmpty;

  int arrivals(String kind) =>
      (_pending[kind] ?? []).where((c) => !c.arrived).length;

  int replies(String kind) =>
      (_pending[kind] ?? []).where((c) => c.arrived).length;

  /// The change reaches the platform, which the caller does not yet hear.
  void arrive(String kind) {
    final change = (_pending[kind] ?? []).firstWhere((c) => !c.arrived);
    change.arrived = true;
    if (change.epoch == _epoch) change.apply();
  }

  /// The caller hears that the oldest change of [kind] is done.
  void reply(String kind, {Object? error}) {
    final change = _pending[kind]!.removeAt(0);
    assert(change.arrived, 'a reply before the change arrived');
    if (error == null) {
      change.reply.complete();
    } else {
      change.reply.completeError(error);
    }
  }

  /// The oldest change of [kind] arrives, if it has not, and is replied to.
  void release(String kind, {Object? error}) {
    if (!_pending[kind]!.first.arrived) arrive(kind);
    reply(kind, error: error);
  }

  void send(ProcessingState state) => _states.add(state);

  /// An advance from the first track to the second, as just_audio reports
  /// it: only if the Dart-side playlist has a second track.
  void advance() {
    if (_sources.length < 2) return;
    _jumps.add(
      PositionDiscontinuity(
        PositionDiscontinuityReason.autoAdvance,
        PlaybackEvent(currentIndex: 0),
        PlaybackEvent(currentIndex: 1),
      ),
    );
  }

  void replaced() => _jumps.add(
    PositionDiscontinuity(
      PositionDiscontinuityReason.autoAdvance,
      PlaybackEvent(currentIndex: 0),
      PlaybackEvent(currentIndex: 0),
    ),
  );

  void fail() => _errors.add(PlayerException(0, 'failed', null));

  /// The platform's current track ends: it goes on to the next one it
  /// holds, or completes. Dart hears of it at [deliver].
  void end() {
    assert(hasHead, 'nothing is playing to end');
    if (_current + 1 < _platform.length) {
      _outbox.add(_Advanced(_current, ++_current));
    } else {
      _completed = true;
      _outbox.add(_Completed());
    }
  }

  /// Dart hears of the oldest thing the platform reported.
  void deliver() {
    switch (_outbox.removeAt(0)) {
      case _Advanced(:final from, :final to):
        if (_sources.length > to) {
          _jumps.add(
            PositionDiscontinuity(
              PositionDiscontinuityReason.autoAdvance,
              PlaybackEvent(currentIndex: from),
              PlaybackEvent(currentIndex: to),
            ),
          );
        }
      case _Completed():
        _states.add(ProcessingState.completed);
    }
  }

  Future<void> _change(String kind, String call, void Function() apply) {
    calls.add(call);
    final change = _Change(kind, _epoch, apply);
    if (!_held.contains(kind)) {
      change.arrived = true;
      apply();
      return Future.value();
    }
    (_pending[kind] ??= []).add(change);
    return change.reply.future;
  }

  String _name(AudioSource source) => switch (source) {
    ProgressiveAudioSource(:final uri) => uri.pathSegments.last,
    ClippingAudioSource(:final child) => _name(child),
    _ => 'unknown',
  };

  @override
  Future<Duration?> setAudioSources(
    List<AudioSource> audioSources, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    ShuffleOrder? shuffleOrder,
  }) async {
    _sources
      ..clear()
      ..addAll(audioSources);
    _epoch++;
    await _change('load', 'load ${audioSources.map(_name).join(',')}', () {
      // What the platform reported before it loaded reaches Dart before the
      // load's reply, while the engine is still loading and ignores it.
      _outbox.clear();
      _platform
        ..clear()
        ..addAll(audioSources);
      _current = initialIndex ?? 0;
      _completed = false;
    });
    return null;
  }

  @override
  Future<void> addAudioSource(AudioSource audioSource) {
    _sources.add(audioSource);
    return _change(
      'add',
      'add ${_name(audioSource)}',
      () => _platform.add(audioSource),
    );
  }

  @override
  Future<void> removeAudioSourceAt(int index) {
    final removed = _sources.removeAt(index);
    return _change('remove', 'remove $index', () {
      final at = _platform.indexOf(removed);
      if (at < 0) return;
      _platform.removeAt(at);
      if (at < _current) {
        _current--;
      } else if (at == _current && _current >= _platform.length) {
        _completed = true;
        _states.add(ProcessingState.completed);
      }
    });
  }

  @override
  Future<void> play() async {
    calls.add('play');
    _playing = true;
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    _playing = false;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    _playing = false;
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    calls.add('seek ${index ?? '-'}');
    if (index != null && index >= 0 && index < _platform.length) {
      _current = index;
    }
    _completed = false;
  }

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {
    await _states.close();
    await _jumps.close();
    await _errors.close();
    await _playbackEvents.close();
  }
}

EngineTrack _track(int id, {bool streamed = true}) => EngineTrack(
  id: id,
  uri: Uri.parse('https://audio.test/$id'),
  streamed: streamed,
);

final class _Engine {
  final player = _FakePlayer();
  final events = <EngineEvent>[];
  late final PluginAudioEngineService engine;

  Future<void> start() async {
    engine = PluginAudioEngineService(
      createHandler: (onCommand) async =>
          AppAudioHandler(onCommand, player: player, watchSession: false),
    );
    engine.events.listen(events.add);
    await engine.activate();
  }

  /// The ids of the tracks the engine reported as ended.
  List<int> get ended => [
    for (final event in events)
      if (event case TrackEnded(:final id)) id,
  ];

  List<EngineFailure> get failures => [
    for (final event in events)
      if (event case EngineFailed(:final failure)) failure,
  ];

  /// Plays [track] and lets its load finish; the commands so far are
  /// forgotten.
  Future<void> playing(EngineTrack track, {EngineTrack? next}) async {
    await engine.play(track, next: next);
    await pumpEventQueue();
    player.calls.clear();
  }

  /// Each of these lets the engine's events reach [events].
  Future<void> send(ProcessingState state) async {
    player.send(state);
    await pumpEventQueue();
  }

  Future<void> advance() async {
    player.advance();
    await pumpEventQueue();
  }

  Future<void> replaced() async {
    player.replaced();
    await pumpEventQueue();
  }

  Future<void> fail() async {
    player.fail();
    await pumpEventQueue();
  }

  Future<void> dispose() => engine.dispose();
}

Future<_Engine> _started() async {
  final engine = _Engine();
  await engine.start();
  addTearDown(engine.dispose);
  return engine;
}

/// The engine's callers' view of the engine, to tell what the repository
/// asked for.
final class _SpyEngine implements AudioEngineService {
  _SpyEngine(this._inner);

  final PluginAudioEngineService _inner;

  /// The name of every track given to the engine, by id.
  final given = <int, String>{};

  /// The track the engine was last told to play after the current one.
  EngineTrack? wanted;

  EngineTrack _note(EngineTrack track) {
    given[track.id] = track.uri.pathSegments.last;
    return track;
  }

  @override
  Stream<EngineEvent> get events => _inner.events;

  @override
  Future<void> activate() => _inner.activate();

  @override
  Future<void> play(
    EngineTrack track, {
    EngineTrack? next,
    Duration from = Duration.zero,
  }) {
    _note(track);
    wanted = next == null ? null : _note(next);
    return _inner.play(track, next: next, from: from);
  }

  @override
  Future<void> load(EngineTrack track) {
    wanted = null;
    return _inner.load(_note(track));
  }

  @override
  Future<void> setNext(EngineTrack? next) {
    wanted = next == null ? null : _note(next);
    return _inner.setNext(next);
  }

  @override
  Future<void> pause() => _inner.pause();

  @override
  Future<void> resume() => _inner.resume();

  @override
  Future<void> setSessionPlaying(bool playing) =>
      _inner.setSessionPlaying(playing);

  @override
  Future<void> stop() {
    wanted = null;
    return _inner.stop();
  }

  @override
  Future<void> setVolume(double volume) => _inner.setVolume(volume);

  @override
  Future<void> seek(Duration position) => _inner.seek(position);

  @override
  Future<void> setSpeed(double factor) => _inner.setSpeed(factor);

  @override
  Future<void> setMediaInfo(MediaInfo info) => _inner.setMediaInfo(info);

  @override
  Future<void> dispose() => _inner.dispose();
}

/// What a test of the race may do, each with the state in which it can
/// happen; an ordering that asks for one where it cannot is no ordering.
const _steps = {
  'end', // the platform's current track ends
  'see', // Dart hears of what the platform reported
  'arriveAdd',
  'replyAdd',
  'arriveRemove',
  'replyRemove',
  'stopOn',
  'stopOff',
  'sleepOn',
  'sleepOff',
  'pause',
  'resume',
  'seek',
  'play',
};

/// Plays three ayat of a synthetic surah through the real repository over
/// the real engine and a fake player whose changes and reports the test
/// orders, and checks what the listener would hear.
final class _Race {
  _Race._(this.engine, this.spy, this.repository);

  final _Engine engine;
  final _SpyEngine spy;
  final EnginePlayerRepository repository;
  final indices = <int>[];
  final endedIds = <int>[];
  final problems = <String>[];
  var _replayed = false;

  _FakePlayer get player => engine.player;

  PlayerState get state => repository.state;

  static QuranAddress _a(String source) => QuranAddress.parse('x:$source');

  static final _builder = PlaybackPlanBuilder(
    edition: EditionMap(
      edition: 'synthetic',
      starts: {
        Division.page: [_a('1:1'), _a('2:1')],
        Division.juz: [_a('1:1')],
        Division.hizb: [_a('1:1')],
      },
      sajdas: const {},
    ),
    ayahCounts: const [3, 5],
    basmalaSurahs: const {2},
  );

  static final PlaybackPlan plan = switch (_builder.build(
    Recitation(
      id: 'synthetic',
      reciter: 'Reciter A',
      riwaya: 'x',
      style: 'Style A',
      unit: RecitationUnit.ayah,
      hasWordTiming: false,
      rightsComplete: true,
      hasBasmalaFile: true,
    ),
    AyahSpan(QuranRange(_a('1:1'), _a('1:3'))),
    repeat: RepeatMode.once,
  )) {
    PlanReady(:final plan) => plan,
    PlanRefused(:final reason) => throw StateError('refused: $reason'),
  };

  /// The first ayah playing with the second queued behind it, and every
  /// later add and removal held until the ordering lets it through.
  static Future<_Race> start() async {
    final engine = _Engine();
    await engine.start();
    final spy = _SpyEngine(engine.engine);
    final repository = EnginePlayerRepository(
      engine: spy,
      locate: (recitation, source) async =>
          (uri: Uri.parse('https://audio.test/$source'), streamed: true),
      surahName: (surah) async => null,
    );
    final race = _Race._(engine, spy, repository);
    engine.engine.events.listen(race._onEngine);
    repository.addListener(race._onState);
    await repository.play(plan);
    await _flush();
    engine.player.hold('add');
    engine.player.hold('remove');
    return race;
  }

  /// Everything the engine and the repository do in answer to a step is
  /// microtasks, so it has all happened when none is waiting. Only the
  /// zone of [_interleave] counts them.
  static Future<void> _flush() async {
    do {
      await Future<void>.value();
    } while (_queued > 0);
  }

  static int _queued = 0;

  String? get _segmentName => state.segment?.source.toString();

  bool get _running => state.plan != null && state.stopReason == null;

  void _onState() {
    final index = state.segmentIndex;
    if (index != null && index != indices.lastOrNull) indices.add(index);
  }

  void _onEngine(EngineEvent event) {
    if (event is! TrackEnded) return;
    endedIds.add(event.id);
    final name = spy.given[event.id];
    if (name == null) {
      problems.add('TrackEnded(${event.id}) is no track the repository gave');
    } else if (name != _segmentName) {
      problems.add(
        'TrackEnded(${event.id}) is $name while the repository is at '
        '$_segmentName',
      );
    }
  }

  bool can(String step) => switch (step) {
    'end' => player.audible != null,
    'see' => player.hasUnseen,
    'arriveAdd' => player.arrivals('add') > 0,
    'replyAdd' => player.replies('add') > 0,
    'arriveRemove' => player.arrivals('remove') > 0,
    'replyRemove' => player.replies('remove') > 0,
    'stopOn' => _running && repository.stopAfter == null,
    'stopOff' => _running && repository.stopAfter != null,
    'sleepOn' => _running && repository.sleepTimer == null,
    'sleepOff' => _running && repository.sleepTimer != null,
    'pause' => _running && state.playing,
    'resume' => _running && !state.playing,
    'seek' => _running && state.playing,
    'play' => true,
    _ => throw ArgumentError(step),
  };

  Future<void> run(String step) async {
    final endedBefore = endedIds.length;
    final indexBefore = state.segmentIndex;
    switch (step) {
      case 'end':
        player.end();
      case 'see':
        player.deliver();
      case 'arriveAdd':
        player.arrive('add');
      case 'replyAdd':
        player.reply('add');
      case 'arriveRemove':
        player.arrive('remove');
      case 'replyRemove':
        player.reply('remove');
      case 'stopOn':
        unawaited(repository.setStopAfter(StopAfter.ayah));
      case 'stopOff':
        unawaited(repository.setStopAfter(null));
      case 'sleepOn':
        unawaited(repository.setSleepTimer(SleepAtEndOfAyah()));
      case 'sleepOff':
        unawaited(repository.setSleepTimer(null));
      case 'pause':
        unawaited(repository.pause());
      case 'resume':
        unawaited(repository.resume());
      case 'seek':
        unawaited(repository.seek(const Duration(seconds: 1)));
      case 'play':
        _replayed = true;
        unawaited(repository.play(plan));
    }
    await _flush();
    if (step != 'play' && endedIds.length > endedBefore) {
      final advanced = (state.segmentIndex ?? 0) - (indexBefore ?? 0);
      if (state.stopReason == null && advanced != 1) {
        problems.add(
          'after $step the repository ignored the end of '
          '${endedIds.skip(endedBefore).join(',')}',
        );
      }
    }
  }

  /// Lets every change through and every report be heard.
  Future<void> drain() async {
    for (var round = 0; round < 40; round++) {
      var moved = false;
      if (player.hasUnseen) {
        player.deliver();
        moved = true;
      }
      for (final kind in ['remove', 'add']) {
        if (player.arrivals(kind) > 0) {
          player.arrive(kind);
          moved = true;
        } else if (player.replies(kind) > 0) {
          player.reply(kind);
          moved = true;
        }
      }
      await _flush();
      if (!moved) return;
    }
    problems.add('the player never settled');
  }

  /// What must hold once every change is through: the player plays the
  /// repository's segment, and a track it still wants is in the player.
  void checkSettled(String when) {
    if (!_running) {
      if (player.audible != null) {
        problems.add('$when: stopped, but ${player.audible} is playing');
      }
      return;
    }
    if (!state.playing) return;
    if (player.audible != _segmentName) {
      problems.add(
        '$when: the repository plays $_segmentName, the player '
        '${player.audible} (holds ${player.platformNames})',
      );
    }
    final wanted = spy.wanted;
    if (wanted != null &&
        !endedIds.contains(wanted.id) &&
        !player.platformNames.contains(spy.given[wanted.id])) {
      problems.add(
        '$when: wanted ${spy.given[wanted.id]} is not in the player '
        '${player.platformNames}',
      );
    }
  }

  /// Plays on to the end of the plan, checking after every ayah.
  Future<void> playOn() async {
    if (_running && !state.playing) {
      await repository.resume();
      await _flush();
      await drain();
    }
    for (var ayah = 0; ayah < 6 && _running && problems.isEmpty; ayah++) {
      checkSettled('while playing on');
      if (problems.isNotEmpty || player.audible == null) break;
      await run('end');
      await run('see');
      await drain();
    }
    checkSettled('at the end');
    if (_running) problems.add('the plan did not end');
  }

  /// No ayah is skipped: each move goes to the next segment, or back to
  /// the start after a new play.
  void checkOrder() {
    for (var i = 1; i < indices.length; i++) {
      final jump = indices[i] - indices[i - 1];
      if (jump != 1 && !(_replayed && indices[i] == 0)) {
        problems.add('the segments ${indices.join(' > ')} skip or repeat one');
        return;
      }
    }
  }

  Future<void> dispose() async {
    repository.dispose();
    await engine.dispose();
  }
}

/// Every distinct ordering of [steps], in lexicographic order.
Iterable<List<String>> _orderings(List<String> steps) sync* {
  final order = [...steps]..sort();
  while (true) {
    yield [...order];
    var i = order.length - 2;
    while (i >= 0 && order[i].compareTo(order[i + 1]) >= 0) {
      i--;
    }
    if (i < 0) return;
    var j = order.length - 1;
    while (order[j].compareTo(order[i]) <= 0) {
      j--;
    }
    final swapped = order[i];
    order[i] = order[j];
    order[j] = swapped;
    order.replaceRange(i + 1, order.length, order.sublist(i + 1).reversed);
  }
}

/// Runs every causal ordering of the [steps] a scenario allows, each at most
/// as often as its count says, and returns how many there were and what went
/// wrong in each that failed. An ordering ends when no step can be taken.
Future<({int orderings, List<String> failures})> _interleave(
  Map<String, int> steps,
) {
  assert(steps.keys.every(_steps.contains));
  var orderings = 0;
  final failures = <String>[];

  Future<void> visit(List<String> order) async {
    final race = await _Race.start();
    List<String> next;
    try {
      for (final step in order) {
        await race.run(step);
      }
      next = [
        for (final step in steps.keys)
          if (order.where((s) => s == step).length < steps[step]! &&
              race.can(step))
            step,
      ];
      if (next.isEmpty) {
        orderings++;
        await race.drain();
        race.checkSettled('after ${order.join(' > ')}');
        await race.playOn();
        race.checkOrder();
        if (race.problems.isNotEmpty) {
          failures.add('${order.join(' > ')}: ${race.problems.first}');
        }
      }
    } finally {
      await race.dispose();
    }
    for (final step in next) {
      await visit([...order, step]);
    }
  }

  return runZoned(
    () async {
      await visit([]);
      return (orderings: orderings, failures: failures);
    },
    zoneSpecification: ZoneSpecification(
      scheduleMicrotask: (self, parent, zone, task) {
        _Race._queued++;
        parent.scheduleMicrotask(zone, () {
          _Race._queued--;
          task();
        });
      },
    ),
  );
}

void main() {
  group('a track that ends before its successor is queued', () {
    test('is reported as itself, and the successor then plays', () async {
      final e = await _started();
      await e.playing(_track(1));
      e.player.hold('add');
      await e.engine.setNext(_track(2));
      await pumpEventQueue();

      await e.send(ProcessingState.completed);

      expect(e.ended, [1]);
      e.player.release('add');
      await pumpEventQueue();
      expect(e.player.calls, ['add 2', 'seek 1', 'play', 'remove 0']);
    });

    test('is not followed by a successor the user paused before', () async {
      final e = await _started();
      await e.playing(_track(1));
      e.player.hold('add');
      await e.engine.setNext(_track(2));
      await e.send(ProcessingState.completed);
      await e.engine.pause();

      e.player.release('add');
      await pumpEventQueue();

      expect(e.ended, [1]);
      expect(e.player.calls, ['add 2', 'pause', 'seek 1', 'remove 0']);
    });

    test('lets a later next track queue behind the successor', () async {
      final e = await _started();
      await e.playing(_track(1));
      e.player.hold('add');
      await e.engine.setNext(_track(2));
      await e.send(ProcessingState.completed);
      await e.engine.setNext(_track(3));

      e.player.release('add');
      await pumpEventQueue();
      expect(e.player.calls, ['add 2', 'seek 1', 'play', 'remove 0', 'add 3']);

      e.player.release('add');
      await e.advance();
      expect(e.ended, [1, 2]);
    });

    test('is also reported when its successor lands as it advances', () async {
      final e = await _started();
      await e.playing(_track(1));
      e.player.hold('add');
      await e.engine.setNext(_track(2));

      await e.advance();

      expect(e.ended, [1]);
      e.player.release('add');
      await pumpEventQueue();
      expect(e.player.calls, ['add 2', 'seek 1', 'play', 'remove 0']);
    });

    test('keeps the successor\'s connection for a later failure', () async {
      final e = await _started();
      await e.playing(_track(1, streamed: false));
      e.player.hold('add');
      await e.engine.setNext(_track(2));
      await e.send(ProcessingState.completed);

      await e.fail();

      expect(e.failures, [EngineFailure.connection]);
    });
  });

  group('the ends of tracks that were queued in time', () {
    test('advancing reports the track that ended and drops it', () async {
      final e = await _started();
      await e.playing(_track(1), next: _track(2));

      await e.advance();
      await pumpEventQueue();
      expect(e.ended, [1]);
      expect(e.player.calls, ['remove 0']);

      await e.send(ProcessingState.completed);
      expect(e.ended, [1, 2]);
    });

    test('a completion with nothing queued ends the playlist', () async {
      final e = await _started();
      await e.playing(_track(1));

      await e.send(ProcessingState.completed);
      await e.engine.setNext(_track(2));
      await pumpEventQueue();

      expect(e.ended, [1]);
      expect(e.player.calls, isEmpty);
    });

    test('removing the queued track holds at the end of the current', () async {
      final e = await _started();
      await e.playing(_track(1), next: _track(2));

      await e.engine.setNext(null);
      await pumpEventQueue();
      await e.send(ProcessingState.completed);

      expect(e.player.calls, ['remove 1']);
      expect(e.ended, [1]);
    });

    test(
      'the discontinuity of a replaced playlist is not an advance',
      () async {
        final e = await _started();
        await e.playing(_track(1), next: _track(2));

        await e.replaced();

        expect(e.ended, isEmpty);
      },
    );
  });

  group('a removal of the queued track that is still in flight', () {
    test('a completion is reported as the track that ended', () async {
      final e = await _started();
      await e.playing(_track(1), next: _track(2));
      e.player.hold('remove');
      await e.engine.setNext(null);
      await pumpEventQueue();

      await e.send(ProcessingState.completed);

      expect(e.ended, [1]);
    });

    test('a completion ends the playlist whatever the removal does', () async {
      final e = await _started();
      await e.playing(_track(1));
      await e.engine.setNext(_track(2));
      await pumpEventQueue();
      e.player.hold('remove');
      await e.engine.setNext(null);
      await pumpEventQueue();

      await e.send(ProcessingState.completed);
      e.player.release('remove');
      await pumpEventQueue();
      await e.engine.setNext(_track(3));
      await pumpEventQueue();

      expect(e.ended, [1]);
      expect(e.player.calls, ['add 2', 'remove 1']);
    });
  });

  group('a successor replaced while the head ends', () {
    test('only the successor wanted at the end is started', () async {
      final e = await _started();
      await e.playing(_track(1));
      e.player.hold('add');
      await e.engine.setNext(_track(2));
      await pumpEventQueue();
      await e.engine.setNext(null);
      await e.engine.setNext(_track(3));
      await e.send(ProcessingState.completed);

      e.player.release('add');
      await pumpEventQueue();
      expect(e.player.calls, ['add 2', 'remove 1', 'add 3']);

      e.player.release('add');
      await pumpEventQueue();
      expect(e.ended, [1]);
      expect(e.player.calls, [
        'add 2',
        'remove 1',
        'add 3',
        'seek 1',
        'play',
        'remove 0',
      ]);
    });
  });

  group('a replacement successor wanted while a removal is in flight', () {
    test('the head ending starts the replacement', () async {
      final e = await _started();
      await e.playing(_track(1), next: _track(2));
      e.player.hold('remove');
      await e.engine.setNext(null);
      await e.engine.setNext(_track(3));
      await pumpEventQueue();

      await e.send(ProcessingState.completed);
      e.player.unhold('remove');
      e.player.release('remove');
      await pumpEventQueue();

      expect(e.ended, [1]);
      expect(e.player.calls, [
        'remove 1',
        'add 3',
        'seek 1',
        'play',
        'remove 0',
      ]);
      expect(e.player.names, ['3']);
    });

    test('the player advancing into the removed track and ending it starts '
        'the replacement and keeps it', () async {
      final e = await _started();
      await e.playing(_track(1), next: _track(2));
      e.player.hold('remove');
      await e.engine.setNext(null);
      await e.engine.setNext(_track(3));
      await pumpEventQueue();

      await e.advance();
      await e.send(ProcessingState.completed);
      e.player.unhold('remove');
      e.player.release('remove');
      await pumpEventQueue();

      expect(e.ended, [1]);
      expect(e.player.calls, [
        'remove 1',
        'add 3',
        'seek 1',
        'play',
        'remove 0',
      ]);
      expect(e.player.names, ['3']);

      await e.engine.setNext(_track(4));
      await pumpEventQueue();
      await e.advance();
      expect(e.ended, [1, 3]);
    });
  });

  group('the end reaches Dart after the changes around it', () {
    test('the playlist ending while the successor is already held plays the '
        'successor', () async {
      final e = await _started();
      await e.playing(_track(1));
      e.player.hold('add');
      await e.engine.setNext(_track(2));
      await pumpEventQueue();

      e.player.end();
      e.player.arrive('add');
      e.player.reply('add');
      await pumpEventQueue();
      e.player.deliver();
      await pumpEventQueue();

      expect(e.ended, [1]);
      expect(e.player.calls, ['add 2', 'seek 1', 'play', 'remove 0']);
      expect(e.player.audible, '2');
      expect(e.player.platformNames, ['2']);
    });

    test('the end of the held successor is the next end', () async {
      final e = await _started();
      await e.playing(_track(1));
      e.player.hold('add');
      await e.engine.setNext(_track(2));
      await pumpEventQueue();
      e.player.end();
      e.player.arrive('add');
      e.player.reply('add');
      e.player.deliver();
      await pumpEventQueue();

      e.player.end();
      e.player.deliver();
      await pumpEventQueue();

      expect(e.ended, [1, 2]);
    });

    test('a failing add of the successor wanted at the end is a failure, '
        'not silence', () async {
      final e = await _started();
      await e.playing(_track(1, streamed: false));
      e.player.hold('add');
      await e.engine.setNext(_track(2));
      await pumpEventQueue();
      e.player.end();
      e.player.deliver();
      await pumpEventQueue();

      e.player.arrive('add');
      e.player.reply('add', error: PlayerException(0, 'no file', null));
      await pumpEventQueue();

      expect(e.ended, [1]);
      expect(e.failures, [EngineFailure.connection]);
    });

    test('a next track set while the head has ended queues behind the '
        'successor', () async {
      final e = await _started();
      await e.playing(_track(1));
      e.player.hold('add');
      await e.engine.setNext(_track(2));
      await pumpEventQueue();
      e.player.end();
      e.player.deliver();
      await pumpEventQueue();
      await e.engine.setNext(_track(3));

      e.player.release('add');
      await pumpEventQueue();
      e.player.release('add');
      await pumpEventQueue();

      expect(e.ended, [1]);
      expect(e.player.audible, '2');
      expect(e.player.platformNames, ['2', '3']);
    });
  });

  group('events of a playlist that is being replaced', () {
    Future<_Engine> replacing() async {
      final e = await _started();
      await e.playing(_track(1), next: _track(2));
      e.player.hold('load');
      await e.engine.play(_track(3), next: _track(4));
      return e;
    }

    test('an advance of the old playlist is no end of the new one', () async {
      final e = await replacing();

      await e.advance();
      e.player.release('load');
      await pumpEventQueue();

      expect(e.ended, isEmpty);
      expect(e.player.calls, ['load 3,4', 'play']);
    });

    test('the completion of the old playlist ends nothing', () async {
      final e = await replacing();

      await e.send(ProcessingState.completed);

      expect(e.ended, isEmpty);
    });

    test('an error of the old playlist fails nothing', () async {
      final e = await replacing();

      await e.fail();

      expect(e.failures, isEmpty);
    });

    test('a change of the old playlist that fails fails nothing', () async {
      final e = await _started();
      await e.playing(_track(1));
      e.player.hold('add');
      await e.engine.setNext(_track(2));
      await pumpEventQueue();
      await e.engine.play(_track(3));

      e.player.release('add', error: StateError('the old player is gone'));
      await pumpEventQueue();

      expect(e.failures, isEmpty);
    });

    test('the new playlist still ends and fails once it has loaded', () async {
      final e = await replacing();
      e.player.release('load');
      await pumpEventQueue();

      await e.advance();
      expect(e.ended, [3]);

      await e.fail();
      expect(e.failures, [EngineFailure.connection]);
    });

    test('changes queued for the old playlist are dropped', () async {
      final e = await _started();
      e.player.hold('load');
      await e.engine.play(_track(1));
      await e.engine.setNext(_track(2));
      await e.engine.play(_track(3));

      e.player.release('load');
      e.player.release('load');
      await pumpEventQueue();

      expect(e.player.calls, ['load 1', 'load 3', 'play']);
    });
  });

  group('a load that does not finish', () {
    test('holds back no command', () async {
      final e = await _started();
      e.player.hold('load');

      await e.engine.play(_track(1), next: _track(2));
      await e.engine.pause();
      await e.engine.setSpeed(1.5);
      await e.engine.setVolume(0.5);
      await e.engine.setNext(_track(3));
      await pumpEventQueue();

      expect(e.player.calls, ['load 1,2', 'pause']);
    });

    test('a load that fails is reported once', () async {
      final e = await _started();
      e.player.hold('load');
      await e.engine.play(_track(1, streamed: false));

      e.player.release('load', error: PlayerException(0, 'no file', null));
      await pumpEventQueue();

      expect(e.failures, [EngineFailure.playback]);
    });
  });

  group('the player repository over the engine', () {
    QuranAddress a(String source) => QuranAddress.parse('x:$source');

    final builder = PlaybackPlanBuilder(
      edition: EditionMap(
        edition: 'synthetic',
        starts: {
          Division.page: [a('1:1'), a('2:1')],
          Division.juz: [a('1:1')],
          Division.hizb: [a('1:1')],
        },
        sajdas: const {},
      ),
      ayahCounts: const [3, 5],
      basmalaSurahs: const {2},
    );

    PlaybackPlan plan(PlaybackRange range, {RepeatMode? repeat}) =>
        switch (builder.build(
          Recitation(
            id: 'synthetic',
            reciter: 'Reciter A',
            riwaya: 'x',
            style: 'Style A',
            unit: RecitationUnit.ayah,
            hasWordTiming: false,
            rightsComplete: true,
            hasBasmalaFile: true,
          ),
          range,
          repeat: repeat ?? RepeatMode.once,
        )) {
          PlanReady(:final plan) => plan,
          PlanRefused(:final reason) => fail('refused: $reason'),
        };

    /// Plays the first of three segments, lets the second end before the
    /// third is queued, then lets the third finish.
    Future<void> playThroughTheRace(
      PlaybackPlan plan,
      List<PlaybackSegment> started,
      String third,
    ) async {
      final e = await _started();
      final repository = EnginePlayerRepository(
        engine: e.engine,
        locate: (recitation, source) async =>
            (uri: Uri.parse('https://audio.test/$source'), streamed: true),
        surahName: (surah) async => null,
      );
      addTearDown(repository.dispose);
      repository.addListener(() {
        final segment = repository.state.segment;
        if (segment != null && !identical(segment, started.lastOrNull)) {
          started.add(segment);
        }
      });
      await repository.play(plan);
      await pumpEventQueue();
      e.player.hold('add');

      await e.advance();
      await pumpEventQueue();
      await e.send(ProcessingState.completed);
      await pumpEventQueue();
      expect(started, hasLength(3), reason: 'the third segment is started');

      e.player.release('add');
      await pumpEventQueue();
      expect(
        e.player.calls,
        containsAllInOrder(['add $third', 'seek 1', 'play']),
      );

      await e.send(ProcessingState.completed);
      await pumpEventQueue();
      expect(repository.state.stopReason, StopReason.endOfPlan);
    }

    /// Plays three ayat with the second queued, then turns stop-after on and
    /// off while the removal that the first of those causes is in flight, so
    /// that a located track 3 replaces the queued track 2 for the same ayah.
    Future<(_Engine, EnginePlayerRepository)> toggling() async {
      final e = await _started();
      final repository = EnginePlayerRepository(
        engine: e.engine,
        locate: (recitation, source) async =>
            (uri: Uri.parse('https://audio.test/$source'), streamed: true),
        surahName: (surah) async => null,
      );
      addTearDown(repository.dispose);
      await repository.play(plan(AyahSpan(QuranRange(a('1:1'), a('1:3')))));
      await pumpEventQueue();
      e.player.calls.clear();
      e.player.hold('remove');
      await repository.setStopAfter(StopAfter.ayah);
      await repository.setStopAfter(null);
      await pumpEventQueue();
      return (e, repository);
    }

    test('an ayah whose successor was replaced by a stop-after toggle '
        'plays when the head ends during the removal', () async {
      final (e, repository) = await toggling();

      await e.send(ProcessingState.completed);
      e.player.release('remove');
      await pumpEventQueue();

      expect(e.ended, [1]);
      expect(repository.state.segment?.address, a('1:2'));
      expect(e.player.calls, [
        'remove 1',
        'add AyahFile(x:1:2)',
        'seek 1',
        'play',
        'remove 0',
      ]);
    });

    test('stop-after toggled while a removal is in flight, the head and the '
        'removed track both end at the platform', () async {
      final (e, repository) = await toggling();

      e.player.end();
      e.player.deliver();
      await pumpEventQueue();
      expect(e.ended, isEmpty, reason: 'the Dart side no longer has track 2');
      e.player.end();
      e.player.deliver();
      await pumpEventQueue();
      expect(e.ended, [1]);
      expect(repository.state.segment?.address, a('1:2'));

      e.player.unhold('remove');
      e.player.release('remove');
      await pumpEventQueue();

      expect(e.player.audible, 'AyahFile(x:1:2)');
      expect(e.player.platformNames, ['AyahFile(x:1:2)', 'AyahFile(x:1:3)']);
      e.player.end();
      e.player.deliver();
      await pumpEventQueue();
      expect(e.ended, hasLength(2));
      expect(repository.state.segment?.address, a('1:3'));
      expect(e.player.audible, 'AyahFile(x:1:3)');
    });

    test('stop-after toggled while the next ayah is being added, the head '
        'advances into the track that was added', () async {
      final e = await _started();
      final repository = EnginePlayerRepository(
        engine: e.engine,
        locate: (recitation, source) async =>
            (uri: Uri.parse('https://audio.test/$source'), streamed: true),
        surahName: (surah) async => null,
      );
      addTearDown(repository.dispose);
      await repository.play(plan(AyahSpan(QuranRange(a('1:1'), a('1:3')))));
      await pumpEventQueue();
      e.player.hold('add');
      e.player.end();
      e.player.deliver();
      await pumpEventQueue();
      expect(e.ended, [1]);
      expect(e.player.names, ['AyahFile(x:1:2)', 'AyahFile(x:1:3)']);
      await repository.setStopAfter(StopAfter.ayah);
      await repository.setStopAfter(null);
      await pumpEventQueue();

      e.player.arrive('add');
      e.player.end();
      e.player.deliver();
      await pumpEventQueue();
      e.player.unhold('add');
      e.player.reply('add');
      await pumpEventQueue();

      expect(repository.state.segment?.address, a('1:3'));
      expect(e.player.audible, 'AyahFile(x:1:3)');
    });

    test('an ayah range goes on when an ayah ends early', () async {
      final started = <PlaybackSegment>[];
      await playThroughTheRace(
        plan(AyahSpan(QuranRange(a('1:1'), a('1:3')))),
        started,
        'AyahFile(x:1:3)',
      );
      expect(
        [for (final s in started) s.address],
        [a('1:1'), a('1:2'), a('1:3')],
      );
    });

    test('a repeated ayah counts every repeat when one ends early', () async {
      final started = <PlaybackSegment>[];
      await playThroughTheRace(
        plan(SingleAyah(a('1:2')), repeat: RepeatMode(RepeatUnit.ayah, 3)),
        started,
        'AyahFile(x:1:2)',
      );
      expect(started, hasLength(3));
    });
  });

  group(
    'every interleaving of the end of a track and the changes around it',
    () {
      Future<void> check(String name, Map<String, int> steps) async {
        final watch = Stopwatch()..start();
        final (:orderings, :failures) = await _interleave(steps);
        // ignore: avoid_print
        print(
          '$name: $orderings orderings, ${failures.length} failed, '
          '${watch.elapsedMilliseconds} ms',
        );
        expect(orderings, greaterThan(0));
        expect(failures.take(40).join('\n'), isEmpty);
      }

      test('a track ends while its successor is being added', () async {
        await check('end while adding', {
          'end': 2,
          'see': 2,
          'arriveAdd': 1,
          'replyAdd': 1,
          'arriveRemove': 2,
          'replyRemove': 2,
        });
      });

      test('stop-after turned on and off across an ayah boundary', () async {
        await check('stop-after toggled', {
          'stopOn': 1,
          'stopOff': 1,
          'end': 2,
          'see': 2,
          'arriveAdd': 1,
          'replyAdd': 1,
          'arriveRemove': 1,
          'replyRemove': 1,
        });
      });

      test('a pause, a seek and a new play inside the window', () async {
        await check('pause, seek, play', {
          'end': 1,
          'see': 1,
          'pause': 1,
          'resume': 1,
          'seek': 1,
          'play': 1,
          'arriveAdd': 1,
          'replyAdd': 1,
          'arriveRemove': 1,
          'replyRemove': 1,
        });
      });
    },
  );
}
