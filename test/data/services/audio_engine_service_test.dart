import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

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
import 'package:holyquran/domain/models/sleep_timer.dart';
import 'package:holyquran/domain/models/stop_after.dart';

import 'package:just_audio/just_audio.dart' hide PlayerState;

part 'audio_engine_harness.dart';

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

    test('is also reported when the player advances into it before its '
        'queueing replies, and is not started again', () async {
      final e = await _started();
      await e.playing(_track(1));
      e.player.hold('add');
      await e.engine.setNext(_track(2));
      await pumpEventQueue();
      e.player.arrive('add');
      e.player.end();

      e.player.deliver();
      await pumpEventQueue();

      expect(e.ended, [1]);
      e.player.reply('add');
      await pumpEventQueue();
      expect(e.player.calls, ['add 2', 'remove 0']);
      expect(e.player.audible, '2');
    });

    test('ending too before its queueing replies, it is reported then and '
        'not started again', () async {
      final e = await _started();
      await e.playing(_track(1));
      e.player.hold('add');
      await e.engine.setNext(_track(2));
      await pumpEventQueue();
      e.player
        ..arrive('add')
        ..end()
        ..end()
        ..seeAll();
      await pumpEventQueue();
      expect(e.ended, [1]);

      e.player.reply('add');
      await pumpEventQueue();

      expect(e.ended, [1, 2]);
      expect(e.player.calls, ['add 2']);
      expect(e.player.startedTwice, isNull);
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
      e.player.seeAll();
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
      e.player.seeAll();
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
      e.player.seeAll();
      await pumpEventQueue();
      e.player.unhold('add');
      e.player.reply('add');
      await pumpEventQueue();

      expect(repository.state.segment?.address, a('1:3'));
      expect(e.player.audible, 'AyahFile(x:1:3)');
    });

    Future<(_Engine, EnginePlayerRepository)> seeking() async {
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
      e.player.hold('seek');
      await repository.seek(const Duration(seconds: 1));
      await pumpEventQueue();
      return (e, repository);
    }

    test('an advance just_audio does not report during a seek is found from '
        'the current index when the seek replies', () async {
      final (e, repository) = await seeking();
      e.player.arrive('seek');
      e.player.end();
      e.player.deliver();
      e.player.deliver();
      await pumpEventQueue();
      expect(e.ended, isEmpty);

      e.player.reply('seek');
      await pumpEventQueue();

      expect(e.ended, [1]);
      expect(repository.state.segment?.address, a('1:2'));
      expect(e.player.audible, 'AyahFile(x:1:2)');
      expect(e.player.calls, ['seek 0', 'remove 0', 'add AyahFile(x:1:3)']);
    });

    test('a seek that reaches the engine after the end of its ayah was '
        'reported is dropped, so no ayah is heard twice', () async {
      final problems = await _replay(
        [
          'end',
          'stopOn',
          'seek',
          'stopOff',
          'arriveRemove',
          'see',
          'see',
          'see',
          'replyRemove',
          'arriveSeek',
          'replySeek',
          'arriveAdd',
          'end',
          'replyAdd',
        ],
        holding: {'add', 'remove', 'seek'},
      );

      expect(problems, isEmpty);
    });

    test('a seek lands on the ayah the repository is at, even when the '
        'player moved on before it arrived', () async {
      final (e, repository) = await seeking();
      e.player.end();
      e.player.deliver();
      await pumpEventQueue();

      e.player.release('seek');
      await pumpEventQueue();

      expect(e.ended, isEmpty);
      expect(repository.state.segment?.address, a('1:1'));
      expect(e.player.audible, 'AyahFile(x:1:1)');
      expect(e.player.calls, ['seek 0']);
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
      // Each walk replays every ordering from the start, so it takes seconds.
      const timeout = Timeout(Duration(minutes: 10));

      void walk(
        String name,
        Map<String, int> steps, {
        required int orderings,
        Set<String> holding = const {'add', 'remove'},
      }) => test(name, timeout: timeout, () async {
        final result = await _interleave(steps, holding: holding);
        expect(result.failures.take(40).join('\n'), isEmpty);
        expect(result.orderings, orderings);
      });

      walk('a track ends while its successor is being added', {
        'end': 2,
        'see': 2,
        'arriveAdd': 1,
        'replyAdd': 1,
        'arriveRemove': 2,
        'replyRemove': 2,
      }, orderings: 30);

      walk('stop-after turned on and off across an ayah boundary', {
        'stopOn': 1,
        'stopOff': 1,
        'end': 2,
        'see': 2,
        'arriveAdd': 1,
        'replyAdd': 1,
        'arriveRemove': 1,
        'replyRemove': 1,
      }, orderings: 1222);

      walk('the sleep timer turned on and off across an ayah boundary', {
        'sleepOn': 1,
        'sleepOff': 1,
        'end': 2,
        'see': 2,
        'arriveAdd': 1,
        'replyAdd': 1,
        'arriveRemove': 1,
        'replyRemove': 1,
      }, orderings: 1222);

      walk(
        'stop-after turned on and off while a seek is in flight',
        {
          'seek': 1,
          'arriveSeek': 1,
          'replySeek': 1,
          'stopOn': 1,
          'stopOff': 1,
          'end': 1,
          'see': 1,
          'arriveAdd': 1,
          'replyAdd': 1,
          'arriveRemove': 1,
          'replyRemove': 1,
        },
        orderings: 2063,
        holding: {'add', 'remove', 'seek'},
      );

      walk(
        'stop-after turned on and off while a seek is in flight and two '
        'ayat end',
        {
          'seek': 1,
          'arriveSeek': 1,
          'replySeek': 1,
          'stopOn': 1,
          'stopOff': 1,
          'end': 2,
          'see': 3,
        },
        orderings: 2959,
        holding: {'add', 'remove', 'seek'},
      );

      walk(
        'a plain seek across an ayah boundary',
        {
          'seek': 1,
          'arriveSeek': 1,
          'replySeek': 1,
          'end': 2,
          'see': 3,
          'arriveAdd': 1,
          'replyAdd': 1,
          'arriveRemove': 1,
          'replyRemove': 1,
        },
        orderings: 1820,
        holding: {'add', 'remove', 'seek'},
      );

      walk('a pause and a resume while tracks end and change', {
        'end': 2,
        'see': 3,
        'pause': 1,
        'resume': 1,
        'arriveAdd': 2,
        'replyAdd': 2,
        'arriveRemove': 2,
        'replyRemove': 2,
      }, orderings: 3158);

      walk(
        'a pause, a seek and a new play inside the window',
        {
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
          'arriveLoad': 1,
          'replyLoad': 1,
        },
        orderings: 1994,
        holding: {'add', 'remove', 'load'},
      );
    },
  );
}
