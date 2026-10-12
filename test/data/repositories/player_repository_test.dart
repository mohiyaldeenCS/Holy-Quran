import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/services/audio_engine_service.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/pack_text.dart';
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
import 'package:holyquran/domain/models/sleep_timer.dart';
import 'package:holyquran/domain/models/stop_after.dart';

QuranAddress _a(String source) => QuranAddress.parse('x:$source');

/// A synthetic edition of three surahs of 3, 5 and 2 ayat; page 2 runs
/// from 1:3 to 2:2.
final _builder = PlaybackPlanBuilder(
  edition: EditionMap(
    edition: 'synthetic',
    starts: {
      Division.page: [_a('1:1'), _a('1:3'), _a('2:3'), _a('3:1')],
      Division.juz: [_a('1:1')],
      Division.hizb: [_a('1:1'), _a('2:3')],
    },
    sajdas: const {},
  ),
  ayahCounts: const [3, 5, 2],
  basmalaSurahs: const {2, 3},
);

Recitation _recitation(RecitationUnit unit, {String reciter = 'Reciter A'}) =>
    Recitation(
      id: 'synthetic-${unit.name}-$reciter',
      reciter: reciter,
      riwaya: 'x',
      style: 'Style A',
      unit: unit,
      hasWordTiming: false,
      rightsComplete: true,
      hasBasmalaFile: true,
    );

/// Ten seconds per ayah, from the start of each surah file.
final class _Timings implements AyahTimings {
  @override
  SurahClip clipOf(QuranAddress ayah) => SurahClip(
    ayah.surah,
    Duration(seconds: 10 * ayah.ayah),
    Duration(seconds: 10 * ayah.ayah + 10),
  );

  @override
  SurahClip? basmalaOf(int surah) =>
      SurahClip(surah, Duration.zero, const Duration(seconds: 10));
}

PlaybackPlan _plan(
  PlaybackRange range, {
  RecitationUnit unit = RecitationUnit.ayah,
  RepeatMode repeat = RepeatMode.once,
  Duration silence = Duration.zero,
  bool continueToNextSurah = false,
  AyahTimings? timings,
  String reciter = 'Reciter A',
}) => switch (_builder.build(
  _recitation(unit, reciter: reciter),
  range,
  repeat: repeat,
  silence: silence,
  continueToNextSurah: continueToNextSurah,
  timings: timings,
)) {
  PlanReady(:final plan) => plan,
  PlanRefused(:final reason) => fail('refused: $reason'),
};

AyahSpan _span(String start, String end) =>
    AyahSpan(QuranRange(_a(start), _a(end)));

String _file(PlaybackSource source) => switch (source) {
  AyahFile(:final ayah) => '${ayah.surah}-${ayah.ayah}',
  SurahFile(:final surah) || SurahClip(:final surah) => 's$surah',
  BasmalaFile() => 'basmala',
  IstiadhaFile() => 'istiadha',
};

String _brief(EngineTrack track) => switch ((track.start, track.end)) {
  (final start?, final end?) =>
    '${track.uri.pathSegments.last} ${start.inSeconds}-${end.inSeconds}',
  _ => track.uri.pathSegments.last,
};

final class _ActivationFailed implements Exception {
  const _ActivationFailed();
}

/// Plays what it is told at once; [finish] ends the current track and moves
/// into the next one, as a gapless playlist does.
final class _FakeEngine implements AudioEngineService {
  final _controller = StreamController<EngineEvent>.broadcast();
  final List<String> log = [];

  /// Every track the listener heard, in order.
  final List<String> heard = [];
  final List<double> volumes = [];
  final List<MediaInfo> infos = [];

  EngineTrack? current;
  EngineTrack? next;
  bool playing = false;
  double speed = 1;
  bool _held = false;

  @override
  Stream<EngineEvent> get events => _controller.stream;

  void emit(EngineEvent event) => _controller.add(event);

  void finish() {
    final ended = current!;
    current = next;
    next = null;
    if (current case final track?) {
      heard.add(_brief(track));
    } else {
      playing = false;
    }
    emit(TrackEnded(ended.id));
  }

  /// Thrown by [activate] while set.
  Exception? activation;

  @override
  Future<void> activate() async {
    if (activation case final error?) throw error;
    log.add('activate');
  }

  @override
  Future<void> play(
    EngineTrack track, {
    EngineTrack? next,
    Duration from = Duration.zero,
  }) async {
    current = track;
    this.next = next;
    playing = true;
    _held = false;
    heard.add(_brief(track));
    log.add('play ${_brief(track)} from ${from.inSeconds}');
  }

  @override
  Future<void> load(EngineTrack track) async {
    current = track;
    next = null;
    playing = false;
    _held = true;
    log.add('load ${_brief(track)}');
  }

  @override
  Future<void> setNext(EngineTrack? next) async {
    this.next = next;
    log.add('next ${next == null ? '-' : _brief(next)}');
  }

  @override
  Future<void> pause() async {
    playing = false;
    log.add('pause');
  }

  @override
  Future<void> resume() async {
    if (_held) heard.add(_brief(current!));
    _held = false;
    playing = true;
    log.add('resume');
  }

  @override
  Future<void> setSessionPlaying(bool playing) async =>
      log.add('session ${playing ? 'playing' : 'paused'}');

  @override
  Future<void> stop() async {
    current = null;
    next = null;
    playing = false;
    _held = false;
    log.add('stop');
  }

  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);

  @override
  Future<void> seek(Duration position) async =>
      log.add('seek ${position.inSeconds}');

  @override
  Future<void> setSpeed(double factor) async => speed = factor;

  @override
  Future<void> setMediaInfo(MediaInfo info) async => infos.add(info);

  @override
  Future<void> dispose() => _controller.close();
}

final class _Harness {
  _Harness(this.async, {this._missing = const {}}) {
    repository = EnginePlayerRepository(
      engine: engine,
      locate: (recitation, source) async => _missing.contains(_file(source))
          ? null
          : (
              uri: Uri.parse('https://audio.test/${_file(source)}'),
              streamed: true,
            ),
      surahName: (surah) async => PackText.fromPack('synthetic name $surah'),
      now: () => DateTime.utc(2026).add(async.elapsed),
    )..addListener(_record);
  }

  final FakeAsync async;
  final Set<String> _missing;
  final engine = _FakeEngine();
  late final EnginePlayerRepository repository;

  /// Each segment the repository started.
  final List<PlaybackSegment> started = [];

  PlayerState get state => repository.state;

  void _record() {
    final segment = state.segment;
    if (segment != null && !identical(segment, started.lastOrNull)) {
      started.add(segment);
    }
  }

  void settle() => async.flushMicrotasks();

  void run(Future<void> Function(EnginePlayerRepository) action) {
    unawaited(action(repository));
    settle();
  }

  /// Plays every track to its end, waiting out silences, until playback
  /// stops.
  void playToEnd({int limit = 200}) {
    for (var step = 0; step < limit; step++) {
      settle();
      if (state.inSilence) {
        async.elapse(_builderMaxSilence);
        continue;
      }
      if (engine.current == null || !engine.playing) return;
      engine.finish();
    }
    fail('playback did not stop');
  }
}

const _builderMaxSilence = PlaybackPlanBuilder.maxSilence;

void main() {
  test('an ayah range plays in order, each ayah chained without a gap', () {
    fakeAsync((async) {
      final h = _Harness(async);
      h.run((p) => p.play(_plan(_span('1:1', '1:3'))));
      expect(h.state.ayah, _a('1:1'));
      expect(h.state.playing, isTrue);
      h.playToEnd();
      expect(h.engine.heard, ['1-1', '1-2', '1-3']);
      expect(h.engine.log.where((line) => line.startsWith('play')), [
        'play 1-1 from 0',
      ]);
      expect(h.state.stopReason, StopReason.endOfPlan);
      expect(h.state.playing, isFalse);
      expect(h.state.ayah, _a('1:3'));
      expect(h.engine.log.first, 'activate');
    });
  });

  test('a repeat count of n plays exactly n times and counts each', () {
    fakeAsync((async) {
      for (final count in [1, 2, 3, 7]) {
        final h = _Harness(async);
        final repeats = <int?>[];
        h.repository.addListener(() {
          if (repeats.lastOrNull != h.state.repeat) repeats.add(h.state.repeat);
        });
        h.run(
          (p) => p.play(
            _plan(
              SingleAyah(_a('1:2')),
              repeat: RepeatMode(RepeatUnit.ayah, count),
            ),
          ),
        );
        h.playToEnd();
        expect(h.engine.heard, List.filled(count, '1-2'), reason: '$count');
        expect(repeats, [for (var i = 1; i <= count; i++) i]);
      }
    });
  });

  test('stop-after ayah stops at the end of the ayah, with nothing queued '
      'behind it', () {
    fakeAsync((async) {
      final h = _Harness(async);
      h.run((p) => p.play(_plan(_span('1:1', '1:3'))));
      expect(h.engine.next, isNotNull);
      h.run((p) => p.setStopAfter(StopAfter.ayah));
      expect(h.engine.next, isNull);
      expect(h.repository.stopAfter, StopAfter.ayah);
      h.playToEnd();
      expect(h.engine.heard, ['1-1']);
      expect(h.state.stopReason, StopReason.stopAfter);
    });
  });

  test('stop-after page stops at the last ayah of the page', () {
    fakeAsync((async) {
      final h = _Harness(async);
      h.run((p) => p.play(_plan(_span('1:3', '2:4'))));
      h.run((p) => p.setStopAfter(StopAfter.page));
      h.playToEnd();
      expect(h.engine.heard, ['1-3', 'basmala', '2-1', '2-2']);
      expect(h.state.stopReason, StopReason.stopAfter);
    });
  });

  test('the sleep timer comes before stop-after and repeat', () {
    fakeAsync((async) {
      final h = _Harness(async);
      h.run(
        (p) => p.play(
          _plan(_span('1:1', '1:3'), repeat: RepeatMode(RepeatUnit.ayah, 3)),
        ),
      );
      h.run((p) => p.setStopAfter(StopAfter.surah));
      h.run((p) => p.setSleepTimer(const SleepAtEndOfAyah()));
      h.playToEnd();
      expect(h.engine.heard, ['1-1']);
      expect(h.state.stopReason, StopReason.sleepTimer);
      expect(h.repository.sleepTimer, isNull);
    });
  });

  test('a sleep timer in minutes fades out mid-ayah, then stops', () {
    fakeAsync((async) {
      final h = _Harness(async);
      h.run((p) => p.play(_plan(WholeSurah(2))));
      h.run((p) => p.setSleepTimer(SleepAfter(5)));
      expect(h.repository.sleepRemaining, const Duration(minutes: 5));
      async.elapse(const Duration(minutes: 5));
      expect(h.state.stopReason, StopReason.sleepTimer);
      expect(h.engine.log.last, isNot('stop'));
      async.elapse(EnginePlayerRepository.sleepFade);
      expect(h.engine.log.last, 'stop');
      final [...fade, restored] = h.engine.volumes;
      expect(fade, hasLength(greaterThan(1)));
      for (var i = 1; i < fade.length; i++) {
        expect(fade[i], lessThan(fade[i - 1]));
      }
      expect(fade.first, lessThan(1));
      expect(restored, 1);
      expect(h.engine.heard, ['basmala']);
    });
  });

  test('the fade lets no further ayah start', () {
    fakeAsync((async) {
      final h = _Harness(async);
      h.run((p) => p.play(_plan(_span('1:1', '1:3'))));
      h.run((p) => p.setSleepTimer(SleepAfter(5)));
      async.elapse(const Duration(minutes: 5, seconds: 1));
      expect(h.engine.next, isNull);
      h.engine.finish();
      async.elapse(EnginePlayerRepository.sleepFade);
      expect(h.engine.heard, ['1-1']);
      expect(h.engine.log.last, 'stop');
    });
  });

  test('playing again during the fade cancels it at full volume', () {
    fakeAsync((async) {
      final h = _Harness(async);
      h.run((p) => p.play(_plan(WholeSurah(2))));
      h.run((p) => p.setSleepTimer(SleepAfter(5)));
      async.elapse(const Duration(minutes: 5, seconds: 2));
      h.run((p) => p.play(_plan(WholeSurah(3))));
      expect(h.engine.volumes.last, 1);
      final played = h.engine.log.length;
      async.elapse(EnginePlayerRepository.sleepFade * 2);
      expect(h.engine.log.sublist(played), isNot(contains('stop')));
      expect(h.state.playing, isTrue);
    });
  });

  test('a surah continues into the next ones, announcing each surah', () {
    fakeAsync((async) {
      final h = _Harness(async);
      h.run((p) => p.play(_plan(WholeSurah(2), continueToNextSurah: true)));
      h.playToEnd();
      expect(h.engine.heard, [
        'basmala', '2-1', '2-2', '2-3', '2-4', '2-5', //
        'basmala', '3-1', '3-2',
      ]);
      expect(h.engine.infos, [
        const MediaInfo(
          surahName: PackText.fromPack('synthetic name 2'),
          reciter: 'Reciter A',
        ),
        const MediaInfo(
          surahName: PackText.fromPack('synthetic name 3'),
          reciter: 'Reciter A',
        ),
      ]);
    });
  });

  test('ayat of a surah file play as chained clips of the one file', () {
    fakeAsync((async) {
      final h = _Harness(async);
      h.run(
        (p) => p.play(
          _plan(
            _span('2:2', '2:4'),
            unit: RecitationUnit.surah,
            timings: _Timings(),
          ),
        ),
      );
      h.playToEnd();
      expect(h.engine.heard, ['s2 20-30', 's2 30-40', 's2 40-50']);
      expect(
        h.engine.log.where((line) => line.startsWith('play')),
        hasLength(1),
      );
    });
  });

  test(
    'a silence holds the next ayah loaded, and a pause holds the silence',
    () {
      fakeAsync((async) {
        final h = _Harness(async);
        h.run(
          (p) => p.play(
            _plan(_span('1:1', '1:2'), silence: const Duration(seconds: 4)),
          ),
        );
        expect(h.engine.next, isNull);
        h.engine.finish();
        h.settle();
        expect(h.state.inSilence, isTrue);
        expect(h.engine.log.last, 'load 1-2');
        async.elapse(const Duration(seconds: 1));
        h.run((p) => p.pause());
        expect(h.engine.log.last, 'session paused');
        async.elapse(const Duration(seconds: 30));
        expect(h.state.inSilence, isTrue);
        h.run((p) => p.resume());
        expect(h.engine.log.last, 'session playing');
        async.elapse(const Duration(seconds: 2));
        expect(h.state.inSilence, isTrue);
        async.elapse(const Duration(seconds: 1));
        expect(h.state.inSilence, isFalse);
        expect(h.state.ayah, _a('1:2'));
        expect(h.engine.heard, ['1-1', '1-2']);
        expect(
          h.engine.log.where((line) => line.startsWith('play')),
          hasLength(1),
        );
      });
    },
  );

  group('the queue', () {
    test('adds, reorders and removes plans', () {
      fakeAsync((async) {
        final h = _Harness(async);
        final one = _plan(WholeSurah(1));
        final two = _plan(WholeSurah(2));
        final three = _plan(WholeSurah(3));
        h.repository
          ..enqueue(one)
          ..enqueue(two)
          ..enqueue(three);
        expect(h.state.queue, [one, two, three]);
        h.repository.moveInQueue(2, 0);
        expect(h.state.queue, [three, one, two]);
        h.repository.moveInQueue(0, 2);
        expect(h.state.queue, [one, two, three]);
        h.repository.removeFromQueue(1);
        expect(h.state.queue, [one, three]);
        expect(() => h.repository.moveInQueue(0, 2), throwsRangeError);
        expect(() => h.state.queue.add(two), throwsUnsupportedError);
      });
    });

    test('plays the next queued plan when a plan ends', () {
      fakeAsync((async) {
        final h = _Harness(async);
        final next = _plan(SingleAyah(_a('3:2')));
        h.repository.enqueue(next);
        h.run((p) => p.play(_plan(SingleAyah(_a('1:1')))));
        h.playToEnd();
        expect(h.engine.heard, ['1-1', '3-2']);
        expect(h.state.plan, same(next));
        expect(h.state.queue, isEmpty);
        expect(
          h.engine.log.where((line) => line == 'stop'),
          hasLength(1),
          reason: 'only at the end of the last plan',
        );
      });
    });

    test('is kept when the user or stop-after stops playback', () {
      fakeAsync((async) {
        final h = _Harness(async);
        final next = _plan(SingleAyah(_a('3:2')));
        h.repository.enqueue(next);
        h.run((p) => p.play(_plan(_span('1:1', '1:3'))));
        h.run((p) => p.stop());
        expect(h.state.stopReason, StopReason.user);
        expect(h.state.queue, [next]);
        expect(h.engine.heard, ['1-1']);
      });
    });
  });

  test('a lost connection keeps the position and resumes from it', () {
    fakeAsync((async) {
      final h = _Harness(async);
      h.run((p) => p.play(_plan(_span('2:1', '2:3'))));
      h.engine.finish();
      h.settle();
      h.engine.emit(const PositionChanged(Duration(seconds: 7)));
      h.settle();
      h.engine.emit(const EngineFailed(EngineFailure.connection));
      h.settle();
      expect(h.state.error, PlayerError.connectionFailed);
      expect(h.state.playing, isFalse);
      expect(h.state.position, const Duration(seconds: 7));
      expect(h.state.ayah, _a('2:1'));
      h.engine.emit(const PositionChanged(Duration.zero));
      h.settle();
      expect(h.state.position, const Duration(seconds: 7));
      h.run((p) => p.resume());
      expect(h.state.error, isNull);
      expect(h.state.playing, isTrue);
      expect(
        h.engine.log.where((line) => line.startsWith('play')).last,
        'play 2-1 from 7',
      );
      expect(h.engine.next, isNotNull);
    });
  });

  test('a lost connection during a silence lets the silence end, and the '
      'next ayah is fetched again', () {
    fakeAsync((async) {
      final h = _Harness(async);
      h.run(
        (p) => p.play(
          _plan(_span('1:1', '1:2'), silence: const Duration(seconds: 2)),
        ),
      );
      h.engine.finish();
      h.settle();
      expect(h.engine.log.last, 'load 1-2');
      h.engine.emit(const EngineFailed(EngineFailure.connection));
      h.settle();
      expect(h.state.error, isNull);
      async.elapse(const Duration(seconds: 2));
      expect(h.state.ayah, _a('1:2'));
      expect(h.engine.log.last, 'play 1-2 from 0');
    });
  });

  test('another recitation of the same surah renews the media metadata', () {
    fakeAsync((async) {
      final h = _Harness(async);
      h.run((p) => p.play(_plan(SingleAyah(_a('2:1')))));
      h.run((p) => p.play(_plan(SingleAyah(_a('2:2')), reciter: 'Reciter B')));
      expect(h.engine.infos.map((info) => info.reciter), [
        'Reciter A',
        'Reciter B',
      ]);
    });
  });

  test('a failed activation is reported, and resuming retries it', () {
    fakeAsync((async) {
      final h = _Harness(async);
      h.engine.activation = const _ActivationFailed();
      h.run((p) => p.play(_plan(_span('1:1', '1:3'))));
      expect(h.state.error, PlayerError.playbackFailed);
      expect(h.state.playing, isFalse);
      h.run((p) => p.resume());
      h.run((p) => p.pause());
      expect(h.engine.log, isEmpty);
      h.engine.activation = null;
      h.run((p) => p.resume());
      expect(h.state.error, isNull);
      expect(h.engine.heard, ['1-1']);
    });
  });

  test('a file that fails to play is reported, and stops the engine', () {
    fakeAsync((async) {
      final h = _Harness(async);
      h.run((p) => p.play(_plan(_span('1:1', '1:3'))));
      h.engine.emit(const EngineFailed(EngineFailure.playback));
      h.settle();
      expect(h.state.error, PlayerError.playbackFailed);
      expect(h.state.playing, isFalse);
      expect(h.engine.log.last, 'stop');
    });
  });

  test('a recitation file that cannot be found is reported', () {
    fakeAsync((async) {
      final h = _Harness(async, missing: {'1-2'});
      h.run((p) => p.play(_plan(_span('1:1', '1:3'))));
      expect(h.engine.next, isNull);
      h.engine.finish();
      h.settle();
      expect(h.state.error, PlayerError.fileMissing);
      expect(h.state.playing, isFalse);
    });
  });

  group('speed', () {
    test('runs from 0.5 to 2.0 in steps of 0.25', () {
      expect(PlaybackSpeed.all.map((speed) => speed.factor), [
        0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, //
      ]);
      var speed = PlaybackSpeed.normal;
      for (var i = 0; i < 10; i++) {
        speed = speed.faster;
      }
      expect(speed.factor, 2.0);
      expect(speed.isFastest, isTrue);
      for (var i = 0; i < 10; i++) {
        speed = speed.slower;
      }
      expect(speed.factor, 0.5);
      expect(speed.isSlowest, isTrue);
    });

    test('is set on the engine and kept in the state', () {
      fakeAsync((async) {
        final h = _Harness(async);
        h.run((p) => p.setSpeed(PlaybackSpeed.normal.faster));
        expect(h.engine.speed, 1.25);
        expect(h.state.speed, PlaybackSpeed.normal.faster);
      });
    });
  });

  group('next and previous', () {
    test('ayah skip the repeats of an ayah', () {
      fakeAsync((async) {
        final h = _Harness(async);
        h.run(
          (p) => p.play(
            _plan(_span('1:1', '1:3'), repeat: RepeatMode(RepeatUnit.ayah, 2)),
          ),
        );
        h.engine.finish();
        h.settle();
        expect((h.state.ayah, h.state.repeat), (_a('1:1'), 2));
        h.run((p) => p.nextAyah());
        expect((h.state.ayah, h.state.repeat), (_a('1:2'), 1));
        h.run((p) => p.nextAyah());
        expect(h.state.ayah, _a('1:3'));
        h.run((p) => p.previousAyah());
        expect((h.state.ayah, h.state.repeat), (_a('1:2'), 1));
        h.run((p) => p.previousAyah());
        h.run((p) => p.previousAyah());
        expect((h.state.ayah, h.state.repeat), (_a('1:1'), 1));
      });
    });

    test('ayah does nothing in an ayah repeated without end', () {
      fakeAsync((async) {
        final h = _Harness(async);
        h.run(
          (p) => p.play(
            _plan(
              _span('1:1', '1:3'),
              repeat: const RepeatMode.unlimited(RepeatUnit.ayah),
            ),
          ),
        );
        final index = h.state.segmentIndex;
        h.run((p) => p.nextAyah());
        expect(h.state.segmentIndex, index);
      });
    });

    test('surah moves within the plan, to the basmala first', () {
      fakeAsync((async) {
        final h = _Harness(async);
        h.run((p) => p.play(_plan(SurahSet(const [1, 2, 3]))));
        h.run((p) => p.nextSurah());
        expect(h.state.segment!.kind, SegmentKind.basmala);
        expect(h.state.segment!.address, _a('2:1'));
        h.run((p) => p.nextSurah());
        expect(h.state.segment!.address, _a('3:1'));
        h.run((p) => p.previousSurah());
        expect(h.state.segment!.address, _a('2:1'));
        h.run((p) => p.nextSurah());
        h.run((p) => p.nextSurah());
        expect(h.state.segment!.address, _a('3:1'));
      });
    });

    test('keep the sleep timer and stop-after', () {
      fakeAsync((async) {
        final h = _Harness(async);
        h.run((p) => p.play(_plan(_span('1:1', '2:5'))));
        h.run((p) => p.setStopAfter(StopAfter.surah));
        h.run((p) => p.setSleepTimer(SleepAfter(10)));
        async.elapse(const Duration(minutes: 1));
        h.run((p) => p.nextAyah());
        expect(h.repository.stopAfter, StopAfter.surah);
        expect(h.repository.sleepRemaining, const Duration(minutes: 9));
      });
    });
  });

  test('commands from the lock screen, notification and headset', () {
    fakeAsync((async) {
      final h = _Harness(async);
      h.run((p) => p.play(_plan(_span('1:1', '1:3'))));
      h.engine.emit(const RemoteCommandReceived(RemotePause()));
      h.settle();
      expect(h.state.playing, isFalse);
      expect(h.engine.playing, isFalse);
      h.engine.emit(const RemoteCommandReceived(RemotePlay()));
      h.settle();
      expect(h.state.playing, isTrue);
      h.engine.emit(const RemoteCommandReceived(RemoteNext()));
      h.settle();
      expect(h.state.ayah, _a('1:2'));
      h.engine.emit(const RemoteCommandReceived(RemotePrevious()));
      h.settle();
      expect(h.state.ayah, _a('1:1'));
      h.engine.emit(
        const RemoteCommandReceived(RemoteSeek(Duration(seconds: 3))),
      );
      h.settle();
      expect(h.state.position, const Duration(seconds: 3));
      h.engine.emit(const RemoteCommandReceived(RemoteStop()));
      h.settle();
      expect(h.state.stopReason, StopReason.user);
      h.run((p) => p.resume());
      expect(h.state.playing, isTrue);
      expect(h.state.ayah, _a('1:1'));
    });
  });

  test('the end of a track that is no longer playing is ignored', () {
    fakeAsync((async) {
      final h = _Harness(async);
      h.run((p) => p.play(_plan(_span('1:1', '1:3'))));
      final first = h.engine.current!.id;
      h.run((p) => p.nextAyah());
      h.engine.emit(TrackEnded(first));
      h.settle();
      expect(h.state.ayah, _a('1:2'));
    });
  });

  test('setting a rule with nothing playing is refused', () {
    fakeAsync((async) {
      final h = _Harness(async);
      final errors = <Object>[];
      void attempt() {
        h.repository.setStopAfter(StopAfter.ayah).catchError(errors.add);
        h.repository
            .setSleepTimer(const SleepAtEndOfSurah())
            .catchError(errors.add);
        h.settle();
      }

      attempt();
      h.run((p) => p.play(_plan(_span('1:1', '1:3'))));
      h.run((p) => p.stop());
      attempt();
      expect(errors, hasLength(4));
      expect(errors, everyElement(isStateError));
      expect(h.repository.stopAfter, isNull);
    });
  });

  test('a rule set right after play applies to that plan', () {
    fakeAsync((async) {
      final h = _Harness(async);
      unawaited(h.repository.play(_plan(_span('1:1', '1:3'))));
      unawaited(h.repository.setStopAfter(StopAfter.ayah));
      h.playToEnd();
      expect(h.engine.heard, ['1-1']);
    });
  });

  test('the listener hears only the segments the rules start, whatever the '
      'rules', () {
    final timers = <SleepTimer?>[
      null,
      const SleepAtEndOfAyah(),
      const SleepAtEndOfSurah(),
    ];
    for (final stopAfter in [null, ...StopAfter.values]) {
      for (final sleep in timers) {
        for (final silence in [Duration.zero, const Duration(seconds: 1)]) {
          fakeAsync((async) {
            final h = _Harness(async);
            h.run(
              (p) => p.play(
                _plan(
                  _span('1:2', '3:1'),
                  repeat: RepeatMode(RepeatUnit.ayah, 2),
                  silence: silence,
                ),
              ),
            );
            h.run((p) => p.setStopAfter(stopAfter));
            h.run((p) => p.setSleepTimer(sleep));
            h.playToEnd();
            final label = '$stopAfter $sleep $silence';
            expect(h.engine.heard, [
              for (final segment in h.started) _file(segment.source),
            ], reason: label);
            if (silence == Duration.zero) {
              expect(
                h.engine.log.where((line) => line.startsWith('play')),
                hasLength(1),
                reason: label,
              );
            }
          });
        }
      }
    }
  });
}
