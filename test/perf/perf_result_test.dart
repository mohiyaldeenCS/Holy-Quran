import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/perf/perf_budget.dart';
import '../../integration_test/perf/perf_result.dart';

PerfResult _run(
  String scenario,
  String metric,
  num value, {
  String mode = 'profile',
  String platform = 'android',
  Map<String, Object?> details = const {},
}) => PerfResult(
  scenario: scenario,
  buildMode: mode,
  platform: platform,
  metrics: {metric: value},
  details: {'device': 'test phone', ...details},
);

PerfResult _failure(String scenario, {Map<String, Object?>? details}) =>
    PerfResult(
      scenario: scenario,
      buildMode: 'profile',
      platform: 'android',
      metrics: const {},
      details: {
        'device': 'test phone',
        'failed': true,
        'reason': 'timed out',
        ...?details,
      },
    );

/// The budgets with the protocol's counts relaxed to one run, for the tests of
/// the limits and of the median; the tests of the counts use the real ones.
final _oneRunSuffices = [
  for (final c in perfChecks)
    PerfCheck(
      id: c.id,
      scenario: c.scenario,
      metric: c.metric,
      comparison: c.comparison,
      limit: c.limit,
      unit: c.unit,
      source: c.source,
      measures: c.measures,
      minSamples: 1,
      everyRun: c.everyRun,
    ),
];

CheckOutcome _outcomeOf(
  List<PerfResult> results,
  String scenario,
  String metric, {
  List<PerfCheck>? checks,
}) => evaluate(
  results,
  checks: checks ?? _oneRunSuffices,
).singleWhere((o) => o.check.scenario == scenario && o.check.metric == metric);

Object? _json(String line) =>
    jsonDecode(line.substring(perfResultMarker.length));

void main() {
  group('the log line', () {
    test('is one line of JSON after the marker and reads back', () {
      const result = PerfResult(
        scenario: 'cold_start',
        buildMode: 'profile',
        platform: 'android',
        metrics: {'savedAyahShownMs': 1234.5},
        details: {'os': 'synthetic', 'prepared': false},
      );

      final line = result.toLogLine();

      expect(line, startsWith(perfResultMarker));
      expect(line, isNot(contains('\n')));
      expect(_json(line), containsPair('scenario', 'cold_start'));
      final back = PerfResult.fromJson(_json(line));
      expect(back.scenario, 'cold_start');
      expect(back.metrics['savedAyahShownMs'], 1234.5);
      expect(back.details['prepared'], isFalse);
    });

    test('is found among the lines of a device log', () {
      final first = _run('scroll', 'p99FrameMs', 20).toLogLine();
      final second = _run('scroll', 'p99FrameMs', 22).toLogLine();
      final log = [
        '10-29 12:00:00.001  1234  1234 I flutter : starting',
        '10-29 12:00:01.001  1234  1234 I flutter : $first',
        'D/EGL_emulation: eglMakeCurrent',
        '10-29 12:00:02.001  1234  1234 I flutter : $second',
        '',
      ].join('\n');

      final results = parsePerfLog(log);

      expect([for (final r in results) r.metrics['p99FrameMs']], [20, 22]);
    });

    test('a log with no result gives none', () {
      expect(parsePerfLog('flutter: nothing here\n'), isEmpty);
    });

    test('a marked line that is not a result is an error naming it', () {
      expect(
        () => parsePerfLog('${perfResultMarker}not json'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Unreadable result line'),
          ),
        ),
      );
      expect(
        () => parsePerfLog('$perfResultMarker{"scenario":"x"}'),
        throwsFormatException,
      );
      expect(
        () => parsePerfLog(
          '$perfResultMarker{"scenario":"x","buildMode":"profile",'
          '"platform":"android","metrics":{"a":"slow"}}',
        ),
        throwsFormatException,
      );
    });
  });

  group('evaluate', () {
    test('a profile run within the limit meets it', () {
      final outcome = _outcomeOf(
        [_run('cold_start', 'savedAyahShownMs', 1999)],
        'cold_start',
        'savedAyahShownMs',
      );

      expect(outcome.verdict, Verdict.met);
      expect(outcome.runs, 1);
    });

    test('a profile run over the limit misses it', () {
      final outcome = _outcomeOf(
        [_run('cold_start', 'savedAyahShownMs', 2001)],
        'cold_start',
        'savedAyahShownMs',
      );

      expect(outcome.verdict, Verdict.missed);
    });

    test('a debug run is informative whatever its number', () {
      for (final value in [1, 99999]) {
        final outcome = _outcomeOf(
          [_run('search', 'resultsShownMs', value, mode: 'debug')],
          'search',
          'resultsShownMs',
        );
        expect(outcome.verdict, Verdict.informative);
      }
    });

    test('a metric no run reported is not measured', () {
      final outcome = _outcomeOf(
        [_run('search', 'resultsShownMs', 10)],
        'ayah_sheet',
        'sheetOpenMs',
      );

      expect(outcome.verdict, Verdict.notMeasured);
      expect(outcome.runs, 0);
      expect(outcome.median, isNull);
    });

    test('the verdict is on the median, the worst run is reported', () {
      final runs = [
        for (final ms in [1500, 1800, 5000, 1700, 1600])
          _run('cold_start', 'savedAyahShownMs', ms),
      ];

      final outcome = _outcomeOf(runs, 'cold_start', 'savedAyahShownMs');

      expect(outcome.median, 1700);
      expect(outcome.worst, 5000);
      expect(outcome.verdict, Verdict.met);
    });

    test('the median of an even count is the mean of the middle two', () {
      final outcome = _outcomeOf(
        [
          _run('word_sheet', 'sheetOpenMs', 100),
          _run('word_sheet', 'sheetOpenMs', 301),
        ],
        'word_sheet',
        'sheetOpenMs',
      );

      expect(outcome.median, 200.5);
      expect(outcome.verdict, Verdict.missed);
    });

    test('for a floor the worst run is the lowest', () {
      final outcome = _outcomeOf(
        [
          _run('scroll', 'framesPerSecond', 60),
          _run('scroll', 'framesPerSecond', 41),
          _run('scroll', 'framesPerSecond', 60),
        ],
        'scroll',
        'framesPerSecond',
      );

      expect(outcome.verdict, Verdict.met);
      expect(outcome.worst, 41);
    });

    test('the launch that built the pack is not counted', () {
      final outcome = _outcomeOf(
        [
          _run(
            'cold_start',
            'savedAyahShownMs',
            9000,
            details: const {'prepared': true},
          ),
          _run('cold_start', 'savedAyahShownMs', 1500),
        ],
        'cold_start',
        'savedAyahShownMs',
      );

      expect(outcome.runs, 1);
      expect(outcome.verdict, Verdict.met);
    });

    test('a debug run among profile runs makes the verdict informative', () {
      final outcome = _outcomeOf(
        [
          _run('search', 'resultsShownMs', 100),
          _run('search', 'resultsShownMs', 100, mode: 'debug'),
        ],
        'search',
        'resultsShownMs',
      );

      expect(outcome.verdict, Verdict.informative);
    });

    test('frames that were the cost of a pump are informative in any mode', () {
      final outcome = _outcomeOf(
        [
          _run(
            'scroll',
            'framesPerSecond',
            240,
            details: {'frameSource': 'pump-wall-clock'},
          ),
        ],
        'scroll',
        'framesPerSecond',
      );

      expect(outcome.verdict, Verdict.informative);
    });

    test('engine frame timings from a profile run are held to the limit', () {
      final outcome = _outcomeOf(
        [
          _run(
            'scroll',
            'framesPerSecond',
            58,
            details: {'frameSource': 'frame-timing'},
          ),
        ],
        'scroll',
        'framesPerSecond',
      );

      expect(outcome.verdict, Verdict.missed);
    });

    test('a profile run on a computer is informative', () {
      for (final platform in ['linux', 'windows', 'macos']) {
        final outcome = _outcomeOf(
          [_run('search', 'resultsShownMs', 10, platform: platform)],
          'search',
          'resultsShownMs',
        );
        expect(outcome.verdict, Verdict.informative, reason: platform);
      }
    });

    test('a scroll that stopped early misses even among good runs', () {
      final outcome = _outcomeOf(
        [
          for (final share in [0.3, 0.99, 1.0])
            _run('scroll', 'travelledShare', share),
        ],
        'scroll',
        'travelledShare',
      );

      expect(outcome.verdict, Verdict.missed);
      expect(outcome.median, 0.99);
      expect(outcome.worst, 0.3);
    });

    test('each device is held to the budgets on its own', () {
      final outcomes = evaluate(
        [
          _run('search', 'resultsShownMs', 100, details: {'device': 'phone A'}),
          _run('search', 'resultsShownMs', 900, details: {'device': 'phone B'}),
        ],
        checks: _oneRunSuffices,
      ).where((o) => o.check.scenario == 'search').toList();

      expect([for (final o in outcomes) o.device], ['phone A', 'phone B']);
      expect(
        [for (final o in outcomes) o.verdict],
        [Verdict.met, Verdict.missed],
      );
    });

    test('every check gets one outcome, in the order of the checks', () {
      final outcomes = evaluate(const []);

      expect([for (final o in outcomes) o.check], perfChecks);
      expect(outcomes.every((o) => o.verdict == Verdict.notMeasured), isTrue);
    });

    test('an outcome writes its limit, source and what was timed', () {
      final json = _outcomeOf(
        [_run('cold_start', 'savedAyahShownMs', 1000)],
        'cold_start',
        'savedAyahShownMs',
      ).toJson();

      expect(json['check'], 'NF-01');
      expect(json['limit'], 'at most 2000 ms');
      expect(json['verdict'], 'met');
      expect(json['source'], contains('NF-01'));
      expect(json['measures'], isNotEmpty);
    });
  });

  group('the counts of the protocol', () {
    List<PerfResult> coldStarts(int count, [num ms = 1500]) => [
      for (var i = 0; i < count; i++)
        _run('cold_start', 'savedAyahShownMs', ms),
    ];

    test('ten cold starts within the limit meet it', () {
      final outcome = _outcomeOf(
        coldStarts(10),
        'cold_start',
        'savedAyahShownMs',
        checks: perfChecks,
      );

      expect(outcome.verdict, Verdict.met);
      expect(outcome.samples, 10);
    });

    test('six good cold starts of ten are incomplete, not met', () {
      final outcome = _outcomeOf(
        coldStarts(6),
        'cold_start',
        'savedAyahShownMs',
        checks: perfChecks,
      );

      expect(outcome.verdict, Verdict.incomplete);
      expect(outcome.samples, 6);
      expect(outcome.failures, 0);
    });

    test('eleven cold starts with four timeouts are a miss, not a met', () {
      final results = [
        _run(
          'cold_start',
          'savedAyahShownMs',
          9000,
          details: const {'prepared': true},
        ),
        ...coldStarts(6),
        for (var i = 0; i < 4; i++) _failure('cold_start'),
      ];

      final outcome = _outcomeOf(
        results,
        'cold_start',
        'savedAyahShownMs',
        checks: perfChecks,
      );

      expect(outcome.verdict, Verdict.missed);
      expect(outcome.failures, 4);
      expect(outcome.runs, 6);
    });

    test('a failed run misses every check of its scenario', () {
      final outcomes = evaluate([
        for (var i = 0; i < 3; i++)
          _run('scroll', 'framesPerSecond', 60, details: {'frameSource': 'x'}),
        _failure('scroll'),
      ]).where((o) => o.check.scenario == 'scroll');

      expect(outcomes, hasLength(3));
      expect(outcomes.every((o) => o.verdict == Verdict.missed), isTrue);
    });

    test('a run that failed before any figure is a miss with no median', () {
      final outcome = _outcomeOf(
        [_failure('search')],
        'search',
        'resultsShownMs',
        checks: perfChecks,
      );

      expect(outcome.verdict, Verdict.missed);
      expect(outcome.failures, 1);
      expect(outcome.median, isNull);
      expect(outcome.toJson()['failures'], 1);
    });

    test('a failure of the run that built the pack is not counted', () {
      final outcome = _outcomeOf(
        [
          _failure('search', details: const {'prepared': true}),
        ],
        'search',
        'resultsShownMs',
        checks: perfChecks,
      );

      expect(outcome.verdict, Verdict.notMeasured);
    });

    test('a failure in a debug build is informative', () {
      final outcome = _outcomeOf(
        [
          const PerfResult(
            scenario: 'search',
            buildMode: 'debug',
            platform: 'android',
            metrics: {},
            details: {'device': 'test phone', 'failed': true},
          ),
        ],
        'search',
        'resultsShownMs',
        checks: perfChecks,
      );

      expect(outcome.verdict, Verdict.informative);
    });

    test('a figure over the limit is a miss even from fewer runs', () {
      final outcome = _outcomeOf(
        coldStarts(3, 2500),
        'cold_start',
        'savedAyahShownMs',
        checks: perfChecks,
      );

      expect(outcome.verdict, Verdict.missed);
    });

    test('one run of ten openings meets the sheets budget, three do not', () {
      PerfResult sheet(int openings) => _run(
        'word_sheet',
        'sheetOpenMs',
        120,
        details: {'repetitions': openings},
      );

      expect(
        _outcomeOf(
          [sheet(10)],
          'word_sheet',
          'sheetOpenMs',
          checks: perfChecks,
        ).verdict,
        Verdict.met,
      );
      expect(
        _outcomeOf(
          [sheet(3)],
          'word_sheet',
          'sheetOpenMs',
          checks: perfChecks,
        ).verdict,
        Verdict.incomplete,
      );
    });

    test('the runs of a scroll that built the pack leave two of three', () {
      final outcome = _outcomeOf(
        [
          _run(
            'scroll',
            'framesPerSecond',
            60,
            details: const {'prepared': true},
          ),
          _run('scroll', 'framesPerSecond', 60),
          _run('scroll', 'framesPerSecond', 60),
        ],
        'scroll',
        'framesPerSecond',
        checks: perfChecks,
      );

      expect(outcome.verdict, Verdict.incomplete);
    });
  });

  group('the device label', () {
    test('two phones of one platform and OS are two devices', () {
      final outcomes = evaluate([
        _run(
          'search',
          'resultsShownMs',
          100,
          platform: 'ios',
          details: {'device': 'iPhone 8', 'os': 'iOS 15'},
        ),
        _run(
          'search',
          'resultsShownMs',
          900,
          platform: 'ios',
          details: {'device': 'iPhone SE', 'os': 'iOS 15'},
        ),
      ], checks: _oneRunSuffices).where((o) => o.check.scenario == 'search');

      expect(
        [for (final o in outcomes) (o.device, o.verdict)],
        [('iPhone 8', Verdict.met), ('iPhone SE', Verdict.missed)],
      );
    });

    test('a run without a label is informative whatever its number', () {
      for (final label in [null, '', '  ']) {
        final outcome = _outcomeOf(
          [
            _run(
              'search',
              'resultsShownMs',
              10,
              details: {'device': label, 'os': 'Android 14'},
            ),
          ],
          'search',
          'resultsShownMs',
        );

        expect(outcome.verdict, Verdict.informative, reason: '$label');
        expect(outcome.device, 'android Android 14');
      }
    });
  });
}
