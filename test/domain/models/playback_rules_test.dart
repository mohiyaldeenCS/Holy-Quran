import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/edition_map.dart';
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

Recitation _recitation(RecitationUnit unit) => Recitation(
  id: 'synthetic-${unit.name}',
  reciter: 'Reciter A',
  riwaya: 'x',
  style: 'Style A',
  unit: unit,
  hasWordTiming: false,
  rightsComplete: true,
  hasBasmalaFile: true,
);

PlaybackPlan _plan(
  PlaybackRange range, {
  RecitationUnit unit = RecitationUnit.ayah,
  RepeatMode repeat = RepeatMode.once,
  Duration silence = Duration.zero,
  bool continueToNextSurah = false,
}) => switch (_builder.build(
  _recitation(unit),
  range,
  repeat: repeat,
  silence: silence,
  continueToNextSurah: continueToNextSurah,
)) {
  PlanReady(:final plan) => plan,
  PlanRefused(:final reason) => fail('refused: $reason'),
};

String _brief(PlaybackSegment s) =>
    '${s.kind.name} ${s.address.surah}:${s.address.ayah} #${s.repeat}';

final class _Clock {
  DateTime _now = DateTime.utc(2026);

  DateTime call() => _now;

  void advance(Duration by) => _now = _now.add(by);
}

/// A fake engine: it ends each segment and each silence at once, and keeps
/// what the rules said.
final class _Run {
  _Run(PlaybackPlan plan, {SleepTimer? sleep, StopAfter? stopAfter})
    : rules = PlaybackRules(plan, clock: () => DateTime.utc(2026)) {
    rules
      ..sleepTimer = sleep
      ..stopAfter = stopAfter;
  }

  final PlaybackRules rules;
  final outputs = <PlaybackOutput>[];

  void start() => outputs.addAll(rules.start());

  void send(PlaybackInput input) => outputs.addAll(rules.handle(input));

  /// Ends segments and silences until playback stops, at most [limit] steps.
  _Run toEnd({int limit = 100000}) {
    start();
    for (var step = 0; step < limit && !rules.isStopped; step++) {
      send(
        outputs.last is SilenceStarted
            ? SilenceEnded(rules.index)
            : SegmentEnded(rules.index),
      );
    }
    return this;
  }

  /// Each segment heard, as `kind surah:ayah #repeat`.
  List<String> get heard => [
    for (final output in outputs)
      if (output case SegmentStarted(:final segment)) _brief(segment),
  ];

  List<String> get followed => [
    for (final output in outputs)
      if (output case AyahStarted(:final ayah)) '${ayah.surah}:${ayah.ayah}',
  ];

  PlaybackStopped get stopped => outputs.last as PlaybackStopped;
}

void main() {
  test('plays the plan through, following each ayah, then stops', () {
    final run = _Run(_plan(WholeSurah(2))).toEnd();
    expect(run.heard, [
      'basmala 2:1 #1',
      for (var ayah = 1; ayah <= 5; ayah++) 'ayah 2:$ayah #1',
    ]);
    expect(run.followed, ['2:1', '2:2', '2:3', '2:4', '2:5']);
    expect(run.stopped.reason, StopReason.endOfPlan);
    expect(run.stopped.fade, isFalse);
  });

  test('repeat n is heard exactly n times, for every n from 1 to 99', () {
    for (var n = RepeatMode.minCount; n <= RepeatMode.maxCount; n++) {
      final run = _Run(
        _plan(SingleAyah(_a('2:2')), repeat: RepeatMode(RepeatUnit.ayah, n)),
      ).toEnd();
      expect(run.heard, [for (var i = 1; i <= n; i++) 'ayah 2:2 #$i']);
      expect(run.stopped.reason, StopReason.endOfPlan);
    }
  });

  test('an unlimited repeat plays until something stops it', () {
    final run = _Run(
      _plan(
        SingleAyah(_a('2:2')),
        repeat: const RepeatMode.unlimited(RepeatUnit.ayah),
      ),
    )..toEnd(limit: 5000);
    expect(run.rules.isStopped, isFalse);
    expect(run.heard, hasLength(5001));
    run.send(const UserStopped());
    expect(run.stopped.reason, StopReason.user);
  });

  test('a silence comes between ayat and ends before the next', () {
    final run = _Run(
      _plan(
        AyahSpan(QuranRange(_a('2:2'), _a('2:3'))),
        silence: const Duration(seconds: 4),
      ),
    )..start();
    run.send(const SegmentEnded(0));
    expect(run.outputs.last, isA<SilenceStarted>());
    expect(
      (run.outputs.last as SilenceStarted).duration,
      const Duration(seconds: 4),
    );
    run.send(const SegmentEnded(0));
    expect(run.outputs.last, isA<SilenceStarted>(), reason: 'stale, ignored');
    run.send(const SilenceEnded(0));
    expect(run.heard.last, 'ayah 2:3 #1');
    expect(run.outputs[run.outputs.length - 2], isA<SegmentStarted>());
    run.send(const SilenceEnded(0));
    expect(run.heard, hasLength(2), reason: 'stale, ignored');
    run.send(const SegmentEnded(1));
    expect(run.stopped.reason, StopReason.endOfPlan);
  });

  test('a repeated or late segment end never skips a segment', () {
    final run = _Run(_plan(AyahSpan(QuranRange(_a('2:2'), _a('2:4')))))
      ..start();
    run.send(const SegmentEnded(0));
    run.send(const SegmentEnded(0));
    expect(run.heard, ['ayah 2:2 #1', 'ayah 2:3 #1']);
    run.send(const SegmentEnded(5));
    expect(run.heard, hasLength(2));
    expect(run.rules.index, 1);
    run.send(const SegmentEnded(1));
    expect(run.heard.last, 'ayah 2:4 #1');
    expect(
      [for (final o in run.outputs.whereType<SegmentStarted>()) o.index],
      [0, 1, 2],
    );
  });

  test('nothing happens before start or after a stop', () {
    final rules = PlaybackRules(
      _plan(WholeSurah(1)),
      clock: () => DateTime.utc(2026),
    );
    expect(rules.handle(const SegmentEnded(-1)), isEmpty);
    expect(rules.handle(const SegmentEnded(0)), isEmpty);
    rules.start();
    expect(rules.start, throwsStateError);
    expect(rules.handle(const UserStopped()), hasLength(1));
    expect(rules.handle(const SegmentEnded(0)), isEmpty);
    expect(rules.handle(const UserStopped()), isEmpty);
  });

  test('shows the next segment for preloading (AU-12)', () {
    final rules = PlaybackRules(
      _plan(AyahSpan(QuranRange(_a('2:2'), _a('2:3')))),
      clock: () => DateTime.utc(2026),
    );
    expect(rules.upcoming?.address, _a('2:2'));
    rules.start();
    expect((rules.index, rules.current?.address), (0, _a('2:2')));
    expect(rules.upcoming?.address, _a('2:3'));
    rules.handle(const SegmentEnded(0));
    expect(rules.upcoming, isNull);
  });

  test('starts at a given segment of the plan', () {
    final plan = _plan(AyahSpan(QuranRange(_a('2:2'), _a('2:4'))));
    final rules = PlaybackRules(
      plan,
      clock: () => DateTime.utc(2026),
      startAt: 2,
    );
    final started = rules.start().first as SegmentStarted;
    expect((started.index, started.segment.address), (2, _a('2:4')));
    expect(
      PlaybackRules(plan, clock: () => DateTime.utc(2026), startAt: 3).start(),
      [isA<PlaybackStopped>()],
    );
    expect(
      () => PlaybackRules(plan, clock: () => DateTime.utc(2026), startAt: -1),
      throwsRangeError,
    );
  });

  test('a hand-over keeps the sleep deadline and the stop-after', () {
    final clock = _Clock();
    final first = PlaybackRules(_plan(WholeSurah(2)), clock: clock.call)
      ..sleepTimer = SleepAfter(5)
      ..stopAfter = StopAfter.page
      ..start();
    clock.advance(const Duration(minutes: 3, seconds: 12));
    final next = first.handOver(_plan(WholeSurah(1)), startAt: 1);
    expect(next.sleepRemaining, const Duration(minutes: 1, seconds: 48));
    expect(next.stopAfter, StopAfter.page);
    expect((next.start().first as SegmentStarted).segment.address, _a('1:2'));

    final whole = first.handOver(
      _plan(SurahSet(const [1, 2]), unit: RecitationUnit.surah),
    );
    expect(whole.stopAfter, isNull, reason: 'no page end in whole surahs');
    expect(whole.sleepTimer, SleepAfter(5));
  });

  group('sleep timer (AU-07)', () {
    test('after its minutes, fading, and not before', () {
      final clock = _Clock();
      final rules = PlaybackRules(
        _plan(
          SingleAyah(_a('2:2')),
          repeat: const RepeatMode.unlimited(RepeatUnit.ayah),
        ),
        clock: clock.call,
      )..sleepTimer = SleepAfter(5);
      expect(rules.sleepRemaining, const Duration(minutes: 5));
      rules.start();
      clock.advance(const Duration(minutes: 4));
      expect(rules.sleepRemaining, const Duration(minutes: 1));
      expect(rules.handle(const SleepTimerFired()), isEmpty);
      expect(rules.handle(const SegmentEnded(0)).first, isA<SegmentStarted>());
      clock.advance(const Duration(minutes: 1));
      expect(rules.sleepRemaining, Duration.zero);
      final stopped = rules.handle(const SleepTimerFired()).single;
      expect(stopped, isA<PlaybackStopped>());
      stopped as PlaybackStopped;
      expect(stopped.reason, StopReason.sleepTimer);
      expect(stopped.fade, isTrue);
      expect(rules.sleepRemaining, isNull);
      expect(rules.sleepTimer, isNull);
    });

    test('fired during a silence, it stops without a fade', () {
      final clock = _Clock();
      final rules =
          PlaybackRules(
              _plan(
                AyahSpan(QuranRange(_a('2:2'), _a('2:3'))),
                silence: const Duration(seconds: 30),
              ),
              clock: clock.call,
            )
            ..sleepTimer = SleepAfter(5)
            ..start();
      expect(rules.handle(const SegmentEnded(0)).single, isA<SilenceStarted>());
      clock.advance(const Duration(minutes: 5));
      final stopped =
          rules.handle(const SleepTimerFired()).single as PlaybackStopped;
      expect(stopped.reason, StopReason.sleepTimer);
      expect(stopped.fade, isFalse);
    });

    test('a late timer is caught at the next segment end or silence end', () {
      final clock = _Clock();
      final plan = _plan(WholeSurah(2), silence: const Duration(seconds: 2));
      final atSegment = PlaybackRules(plan, clock: clock.call)
        ..sleepTimer = SleepAfter(5)
        ..start();
      clock.advance(const Duration(minutes: 6));
      expect(
        (atSegment.handle(const SegmentEnded(0)).single as PlaybackStopped)
            .reason,
        StopReason.sleepTimer,
      );
      final atSilence = PlaybackRules(plan, clock: clock.call)
        ..sleepTimer = SleepAfter(5)
        ..start()
        ..handle(const SegmentEnded(0));
      expect(
        atSilence.handle(const SegmentEnded(1)).single,
        isA<SilenceStarted>(),
      );
      clock.advance(const Duration(minutes: 5));
      expect(
        (atSilence.handle(const SilenceEnded(1)).single as PlaybackStopped)
            .reason,
        StopReason.sleepTimer,
      );
    });

    test('at the end of the ayah or of the surah', () {
      expect(
        _Run(
          _plan(WholeSurah(2)),
          sleep: const SleepAtEndOfAyah(),
        ).toEnd().heard,
        ['basmala 2:1 #1', 'ayah 2:1 #1'],
      );
      final run = _Run(
        _plan(WholeSurah(1), continueToNextSurah: true),
        sleep: const SleepAtEndOfSurah(),
      ).toEnd();
      expect(run.followed, ['1:1', '1:2', '1:3']);
      expect(run.stopped.reason, StopReason.sleepTimer);
      expect(run.stopped.fade, isFalse);
    });
  });

  group('stop after (AU-08)', () {
    final plan = _plan(ToEndOfMushaf(_a('1:2')));

    test('the ayah, the page, the surah', () {
      expect(_Run(plan, stopAfter: StopAfter.ayah).toEnd().followed, ['1:2']);
      expect(
        _Run(plan, stopAfter: StopAfter.page).toEnd().followed,
        ['1:2'],
        reason: '1:2 ends page 1',
      );
      expect(
        _Run(
          _plan(ToEndOfMushaf(_a('1:3'))),
          stopAfter: StopAfter.page,
        ).toEnd().followed,
        ['1:3', '2:1', '2:2'],
      );
      final run = _Run(plan, stopAfter: StopAfter.surah).toEnd();
      expect(run.followed, ['1:2', '1:3']);
      expect(run.stopped.reason, StopReason.stopAfter);
    });

    test('set while playing, it applies from the current segment', () {
      final run = _Run(plan)..start();
      run.send(const SegmentEnded(0));
      run.rules.stopAfter = StopAfter.ayah;
      run.send(const SegmentEnded(1));
      expect(run.followed, ['1:2', '1:3']);
      expect(run.stopped.reason, StopReason.stopAfter);
    });
  });

  group('rule priority: sleep, stop-after, repeat, continue (AU-23)', () {
    test('sleep timer before stop-after', () {
      final run = _Run(
        _plan(WholeSurah(2)),
        sleep: const SleepAtEndOfAyah(),
        stopAfter: StopAfter.ayah,
      ).toEnd();
      expect(run.stopped.reason, StopReason.sleepTimer);
      final bySurah = _Run(
        _plan(WholeSurah(1)),
        sleep: const SleepAtEndOfSurah(),
        stopAfter: StopAfter.page,
      ).toEnd();
      expect(bySurah.followed, ['1:1', '1:2']);
      expect(bySurah.stopped.reason, StopReason.stopAfter);
    });

    test('sleep timer before repeat', () {
      final run = _Run(
        _plan(
          SingleAyah(_a('2:2')),
          repeat: const RepeatMode.unlimited(RepeatUnit.ayah),
        ),
        sleep: const SleepAtEndOfAyah(),
      ).toEnd();
      expect(run.heard, ['ayah 2:2 #1']);
      expect(run.stopped.reason, StopReason.sleepTimer);
    });

    test('sleep timer before continue', () {
      final run = _Run(
        _plan(WholeSurah(1), continueToNextSurah: true),
        sleep: const SleepAtEndOfSurah(),
      ).toEnd();
      expect(run.followed.last, '1:3');
      expect(run.stopped.reason, StopReason.sleepTimer);
    });

    test('stop-after before repeat', () {
      final byAyah = _Run(
        _plan(SingleAyah(_a('2:2')), repeat: RepeatMode(RepeatUnit.ayah, 3)),
        stopAfter: StopAfter.ayah,
      ).toEnd();
      expect(byAyah.heard, ['ayah 2:2 #1']);
      expect(byAyah.stopped.reason, StopReason.stopAfter);
      final byPage = _Run(
        _plan(PageSpan(2), repeat: RepeatMode(RepeatUnit.page, 3)),
        stopAfter: StopAfter.page,
      ).toEnd();
      expect(byPage.followed, ['1:3', '2:1', '2:2']);
      expect(byPage.stopped.reason, StopReason.stopAfter);
    });

    test('stop-after before continue', () {
      final run = _Run(
        _plan(WholeSurah(1), continueToNextSurah: true),
        stopAfter: StopAfter.surah,
      ).toEnd();
      expect(run.followed, ['1:1', '1:2', '1:3']);
      expect(run.stopped.reason, StopReason.stopAfter);
    });

    test('repeat before continue', () {
      final run = _Run(
        _plan(
          WholeSurah(2),
          repeat: RepeatMode(RepeatUnit.surah, 2),
          continueToNextSurah: true,
        ),
      ).toEnd();
      expect(run.heard, [
        for (var pass = 1; pass <= 2; pass++) ...[
          'basmala 2:1 #1',
          for (var ayah = 1; ayah <= 5; ayah++) 'ayah 2:$ayah #$pass',
        ],
        for (var pass = 1; pass <= 2; pass++) ...[
          'basmala 3:1 #1',
          'ayah 3:1 #$pass',
          'ayah 3:2 #$pass',
        ],
      ]);
      expect(run.stopped.reason, StopReason.endOfPlan);
    });

    test('an unlimited repeat never lets continue start', () {
      final run = _Run(
        _plan(
          WholeSurah(3),
          repeat: const RepeatMode.unlimited(RepeatUnit.range),
          continueToNextSurah: true,
        ),
      )..toEnd(limit: 3000);
      expect(run.rules.isStopped, isFalse);
      expect(run.followed.toSet(), {'3:1', '3:2'});
    });

    test('continue across the last surah stops', () {
      final run = _Run(_plan(WholeSurah(3), continueToNextSurah: true)).toEnd();
      expect(run.followed, ['3:1', '3:2']);
      expect(run.stopped.reason, StopReason.endOfPlan);
    });
  });

  group('a plan of whole surah files (D-112)', () {
    final plan = _plan(SurahSet(const [1, 2]), unit: RecitationUnit.surah);

    test('has no ayah or page end to stop or sleep at', () {
      final rules = PlaybackRules(plan, clock: () => DateTime.utc(2026));
      expect(() => rules.stopAfter = StopAfter.ayah, throwsArgumentError);
      expect(() => rules.stopAfter = StopAfter.page, throwsArgumentError);
      expect(
        () => rules.sleepTimer = const SleepAtEndOfAyah(),
        throwsArgumentError,
      );
      expect(rules.stopAfter, isNull);
      expect(rules.sleepTimer, isNull);
    });

    test('stops after a surah, and follows no ayah', () {
      final run = _Run(plan, stopAfter: StopAfter.surah).toEnd();
      expect(run.heard, ['surah 1:1 #1']);
      expect(run.followed, isEmpty);
      final sleeping = _Run(plan, sleep: const SleepAtEndOfSurah()).toEnd();
      expect(sleeping.stopped.reason, StopReason.sleepTimer);
    });
  });
}
