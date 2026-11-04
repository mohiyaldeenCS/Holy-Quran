import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/perf/perf_result.dart';
import '../../test_driver/perf_summary.dart';

PerfResult _run(String scenario, String metric, num value) => PerfResult(
  scenario: scenario,
  buildMode: 'profile',
  platform: 'android',
  metrics: {metric: value},
  details: const {
    'device': 'test phone',
    'os': 'synthetic',
    'refreshRateHz': 60.0,
  },
);

PerfResult _named(String runId) => PerfResult(
  scenario: 'cold_start',
  buildMode: 'profile',
  platform: 'android',
  metrics: const {'savedAyahShownMs': 1500},
  details: {'device': 'test phone', 'runId': runId},
);

void main() {
  late Directory directory;

  setUp(() => directory = Directory.systemTemp.createTempSync('perf_driver'));
  tearDown(() => directory.deleteSync(recursive: true));

  File logOf(List<PerfResult> results, {String name = 'run.log'}) =>
      File('${directory.path}/$name')..writeAsStringSync(
        [
          'I/flutter: starting',
          for (final result in results) 'I/flutter: ${result.toLogLine()}',
        ].join('\n'),
      );

  Future<({int code, String report, String errors})> drive(
    List<String> arguments,
  ) async {
    final report = StringBuffer();
    final errors = StringBuffer();
    final code = await collect(arguments, report: report, errors: errors);
    return (code: code, report: '$report', errors: '$errors');
  }

  test(
    'a log whose runs are within every budget it measures exits 0',
    () async {
      final log = logOf([
        for (var i = 0; i < 10; i++)
          _run('cold_start', 'savedAyahShownMs', 1500),
        for (var i = 0; i < 5; i++) _run('search', 'resultsShownMs', 120),
      ]);

      final outcome = await drive([log.path]);

      expect(outcome.code, 0);
      expect(outcome.report, contains('MET'));
      expect(outcome.report, contains('NF-01 cold_start.savedAyahShownMs'));
      expect(outcome.report, contains('NOTMEASURED'));
    },
  );

  test('a missed budget exits 1 and the report names it', () async {
    final log = logOf([_run('cold_start', 'savedAyahShownMs', 2600)]);

    final outcome = await drive([log.path]);

    expect(outcome.code, 1);
    expect(
      outcome.report,
      contains(
        'MISSED       NF-01 cold_start.savedAyahShownMs: median 2600 ms over '
        '1 run, worst 2600 (at most 2000 ms)',
      ),
    );
  });

  test('several logs are read as one set of runs', () async {
    final first = logOf([
      _run('word_sheet', 'sheetOpenMs', 150),
    ], name: 'first.log');
    final second = logOf([
      _run('word_sheet', 'sheetOpenMs', 250),
    ], name: 'second.log');

    final outcome = await drive([first.path, second.path]);

    expect(outcome.report, contains('median 200 ms over 2 runs, worst 250'));
  });

  test('runs of two devices are reported one device after the other', () async {
    PerfResult on(String os, num ms) => PerfResult(
      scenario: 'word_sheet',
      buildMode: 'profile',
      platform: 'ios',
      metrics: {'sheetOpenMs': ms},
      details: {'device': os, 'repetitions': 10},
    );
    final log = logOf([on('phone A', 150), on('phone B', 250)]);

    final outcome = await drive([log.path]);

    expect(outcome.code, 1);
    expect(outcome.report, contains('MET          [phone A] NF-05'));
    expect(outcome.report, contains('MISSED       [phone B] NF-05'));
  });

  test('--out writes the report with the verdicts and the devices', () async {
    final log = logOf([
      for (var i = 0; i < 10; i++) _run('cold_start', 'savedAyahShownMs', 1500),
    ]);
    final out = File('${directory.path}/report.json');

    final outcome = await drive(['--out', out.path, log.path]);

    expect(outcome.code, 0);
    final json = jsonDecode(out.readAsStringSync()) as Map<String, Object?>;
    expect(json['results'], 10);
    expect(json['devices'], [
      {
        'platform': 'android',
        'buildMode': 'profile',
        'device': 'test phone',
        'os': 'synthetic',
        'processors': null,
        'refreshRateHz': 60.0,
        'devicePixelRatio': null,
        'liveFrames': null,
      },
    ]);
    final outcomes = json['outcomes']! as List<Object?>;
    expect(outcomes.first, containsPair('verdict', 'met'));
    expect(outcomes.first, containsPair('check', 'NF-01'));
  });

  test('a log with no result exits 2', () async {
    final log = File('${directory.path}/empty.log')
      ..writeAsStringSync('I/flutter: nothing\n');

    final outcome = await drive([log.path]);

    expect(outcome.code, 2);
    expect(outcome.errors, contains('No PERF_RESULT'));
  });

  test('a log that cannot be read, or a damaged line, exits 2', () async {
    expect((await drive(['${directory.path}/missing.log'])).code, 2);
    final damaged = File('${directory.path}/damaged.log')
      ..writeAsStringSync('$perfResultMarker{broken');

    final outcome = await drive([damaged.path]);

    expect(outcome.code, 2);
    expect(outcome.errors, contains('Unreadable result line'));
  });

  test('no argument prints the usage and exits 2', () async {
    final outcome = await drive(const []);

    expect(outcome.code, 2);
    expect(outcome.errors, contains('perf_summary.dart'));
  });

  test(
    'a short set of runs is reported incomplete and still exits 0',
    () async {
      final log = logOf([
        for (var i = 0; i < 6; i++)
          _run('cold_start', 'savedAyahShownMs', 1500),
      ]);

      final outcome = await drive([log.path]);

      expect(outcome.code, 0);
      expect(
        outcome.report,
        contains(
          'INCOMPLETE   NF-01 cold_start.savedAyahShownMs: median 1500 ms over '
          '6 runs, worst 1500, only 6 of the 10 measurements the protocol '
          'asks for',
        ),
      );
    },
  );

  test('a failed run is reported as a miss and exits 1', () async {
    const failed = PerfResult(
      scenario: 'search',
      buildMode: 'profile',
      platform: 'android',
      metrics: {},
      details: {'device': 'test phone', 'failed': true},
    );
    final log = logOf([failed]);

    final outcome = await drive([log.path]);

    expect(outcome.code, 1);
    expect(
      outcome.report,
      contains('MISSED       NF-03 search.resultsShownMs: 1 failed run '),
    );
  });

  test('the same runs given twice count once', () async {
    final runs = [for (var i = 0; i < 6; i++) _named('42-cold_start-$i')];
    final driver = logOf(runs, name: 'driver.log');
    final logcat = logOf(runs, name: 'logcat.log');
    final out = File('${directory.path}/report.json');

    final outcome = await drive(['--out', out.path, driver.path, logcat.path]);

    expect(
      outcome.report,
      contains('median 1500 ms over 6 runs, worst 1500, only 6 of the 10'),
    );
    final json = jsonDecode(out.readAsStringSync()) as Map<String, Object?>;
    expect(json['results'], 6);
  });

  test('twelve lines of six runs do not make ten cold starts', () async {
    final runs = [for (var i = 0; i < 6; i++) _named('42-cold_start-$i')];
    final log = logOf([...runs, ...runs]);

    final outcome = await drive([log.path]);

    expect(outcome.report, contains('INCOMPLETE'));
    expect(outcome.report, isNot(contains('MET  ')));
  });

  test('runs of two processes with the same scenario are all kept', () async {
    final log = logOf([
      for (final process in [1, 2])
        for (var i = 0; i < 5; i++) _named('$process-cold_start-$i'),
    ]);

    final outcome = await drive([log.path]);

    expect(outcome.report, contains('MET          NF-01'));
    expect(outcome.report, contains('over 10 runs'));
  });

  test(
    'a stray debug run under a label does not hide its device\'s miss',
    () async {
      final log = logOf([
        _run('cold_start', 'savedAyahShownMs', 2600),
        const PerfResult(
          scenario: 'cold_start',
          buildMode: 'debug',
          platform: 'android',
          metrics: {'savedAyahShownMs': 1200},
          details: {'device': 'test phone'},
        ),
      ]);

      final outcome = await drive([log.path]);

      expect(outcome.code, 1);
      expect(outcome.report, contains('MISSED       [test phone] NF-01'));
      expect(
        outcome.report,
        contains('INFORMATIVE  [test phone (informative)] NF-01'),
      );
    },
  );
}
