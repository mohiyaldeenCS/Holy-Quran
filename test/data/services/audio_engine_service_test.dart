import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/services/audio_engine_service.dart';
import 'package:holyquran/data/services/audio_handler.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/playback_plan.dart';
import 'package:holyquran/domain/models/playback_plan_builder.dart';
import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/playback_rules.dart';
import 'package:holyquran/domain/models/playback_segment.dart';
import 'package:holyquran/domain/models/player_state.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_range.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/domain/models/repeat_mode.dart';

/// A player whose events the test sends and whose playlist changes finish
/// only when the test says so, as on a device where a change takes a moment
/// to reach the platform.
final class _FakePlayer extends Fake implements AudioPlayer {
  final _states = StreamController<ProcessingState>.broadcast(sync: true);
  final _jumps = StreamController<PositionDiscontinuity>.broadcast(sync: true);
  final _errors = StreamController<PlayerException>.broadcast(sync: true);
  final _playbackEvents = StreamController<PlaybackEvent>.broadcast();
  final _held = <String>{};
  final _pending = <String, List<Completer<void>>>{};

  /// Every command, in the order the player received it.
  final List<String> calls = [];
  final List<AudioSource> _sources = [];

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
  /// [release].
  void hold(String kind) => _held.add(kind);

  void release(String kind, {Object? error}) {
    final change = _pending[kind]!.removeAt(0);
    if (error == null) {
      change.complete();
    } else {
      change.completeError(error);
    }
  }

  void send(ProcessingState state) => _states.add(state);

  void advance() => _jumps.add(
    PositionDiscontinuity(
      PositionDiscontinuityReason.autoAdvance,
      PlaybackEvent(currentIndex: 0),
      PlaybackEvent(currentIndex: 1),
    ),
  );

  void replaced() => _jumps.add(
    PositionDiscontinuity(
      PositionDiscontinuityReason.autoAdvance,
      PlaybackEvent(currentIndex: 0),
      PlaybackEvent(currentIndex: 0),
    ),
  );

  void fail() => _errors.add(PlayerException(0, 'failed', null));

  Future<void> _change(String kind, String call) {
    calls.add(call);
    if (!_held.contains(kind)) return Future.value();
    final change = Completer<void>();
    (_pending[kind] ??= []).add(change);
    return change.future;
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
    await _change('load', 'load ${audioSources.map(_name).join(',')}');
    return null;
  }

  @override
  Future<void> addAudioSource(AudioSource audioSource) {
    _sources.add(audioSource);
    return _change('add', 'add ${_name(audioSource)}');
  }

  @override
  Future<void> removeAudioSourceAt(int index) {
    _sources.removeAt(index);
    return _change('remove', 'remove $index');
  }

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> seek(Duration? position, {int? index}) async =>
      calls.add('seek ${index ?? '-'}');

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {}
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
      expect(e.player.calls, containsAllInOrder(['add', 'seek 1', 'play']));

      await e.send(ProcessingState.completed);
      await pumpEventQueue();
      expect(repository.state.stopReason, StopReason.endOfPlan);
    }

    test('an ayah range goes on when an ayah ends early', () async {
      final started = <PlaybackSegment>[];
      await playThroughTheRace(
        plan(AyahSpan(QuranRange(a('1:1'), a('1:3')))),
        started,
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
      );
      expect(started, hasLength(3));
    });
  });
}
