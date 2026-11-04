import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/perf/perf_budget.dart';
import '../../integration_test/perf/perf_result.dart';

PerfResult _run(
  String scenario,
  String metric,
  num value, {
  String mode = 'profile',
  Map<String, Object?> details = const {},
}) => PerfResult(
  scenario: scenario,
  buildMode: mode,
  platform: 'android',
  metrics: {metric: value},
  details: details,
);

CheckOutcome _outcomeOf(
  List<PerfResult> results,
  String scenario,
  String metric,
) => evaluate(
  results,
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
}
