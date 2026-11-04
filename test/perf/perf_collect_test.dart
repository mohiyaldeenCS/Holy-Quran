import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/perf/perf_result.dart';
import '../../test_driver/perf_collect.dart';

PerfResult _result(String scenario) => PerfResult(
  scenario: scenario,
  buildMode: 'profile',
  platform: 'android',
  metrics: {'savedAyahShownMs': 1500},
);

Map<String, Object?> _data(List<PerfResult> results) => {
  perfReportKey: [for (final result in results) result.toJson()],
};

void main() {
  late Directory folder;

  setUp(() => folder = Directory.systemTemp.createTempSync('perf_collect'));
  tearDown(() => folder.deleteSync(recursive: true));

  test('the report data of a run becomes the lines of a log', () {
    final lines = resultLines(_data([_result('cold_start')]));

    expect(parsePerfLog(lines.join('\n')).single.scenario, 'cold_start');
  });

  test('report data without a result is refused', () {
    expect(() => resultLines(null), throwsFormatException);
    expect(() => resultLines(const {}), throwsFormatException);
    expect(() => resultLines(_data(const [])), throwsFormatException);
  });

  test('a damaged result in the report data is refused', () {
    expect(
      () => resultLines({
        perfReportKey: [
          {'scenario': 'scroll'},
        ],
      }),
      throwsFormatException,
    );
  });

  test('runs saved one after the other do not replace each other', () async {
    final data = _data([_result('cold_start')]);

    final first = await saveResults(
      data,
      folder: folder,
      now: DateTime.utc(2026, 11, 2, 10),
    );
    final second = await saveResults(
      data,
      folder: folder,
      now: DateTime.utc(2026, 11, 2, 10, 5),
    );

    expect(first.path, isNot(second.path));
    expect(first.uri.pathSegments.last, startsWith('cold_start-'));
    expect(parsePerfLog(first.readAsStringSync()).single.metrics, {
      'savedAyahShownMs': 1500,
    });
    expect(folder.listSync(), hasLength(2));
  });

  test('a run that published nothing says so and is not written', () async {
    final output = StringBuffer();

    final written = await writeRunResults(null, folder: folder, output: output);

    expect(written, isFalse);
    expect(output.toString(), contains('No performance result was written'));
    expect(output.toString(), contains('reported no performance result'));
    expect(folder.listSync(), isEmpty);
  });

  test('a run that published results says where they are', () async {
    final output = StringBuffer();

    final written = await writeRunResults(
      _data([_result('cold_start')]),
      folder: folder,
      output: output,
    );

    expect(written, isTrue);
    expect(output.toString(), contains('Performance results written to'));
    expect(folder.listSync(), hasLength(1));
  });

  test('a failed result is written like any other', () async {
    const failed = PerfResult(
      scenario: 'search',
      buildMode: 'profile',
      platform: 'android',
      metrics: {},
      details: {'failed': true, 'reason': 'timed out'},
    );

    final file = await saveResults(_data([failed]), folder: folder);

    final back = parsePerfLog(file.readAsStringSync()).single;
    expect(back.failed, isTrue);
    expect(back.details['reason'], 'timed out');
  });

  group('the driver', () {
    Future<
      ({
        bool? onFailure,
        Future<void> Function(Map<String, dynamic>?)? callback,
      })
    >
    arguments(StringBuffer output, List<int> failures) async {
      bool? onFailure;
      Future<void> Function(Map<String, dynamic>?)? callback;
      await runPerfDriver(
        ({responseDataCallback, writeResponseOnFailure = false}) async {
          onFailure = writeResponseOnFailure;
          callback = responseDataCallback;
        },
        folder: folder,
        output: output,
        fail: failures.add,
      );
      return (onFailure: onFailure, callback: callback);
    }

    test(
      'asks for the response of a failed run, which holds its failure',
      () async {
        final given = await arguments(StringBuffer(), []);

        expect(given.onFailure, isTrue);
        expect(given.callback, isNotNull);
      },
    );

    test('writes the results it is given and does not fail', () async {
      final output = StringBuffer();
      final failures = <int>[];
      final given = await arguments(output, failures);

      await given.callback!(_data([_result('cold_start')]));

      expect(folder.listSync(), hasLength(1));
      expect(output.toString(), contains('Performance results written to'));
      expect(failures, isEmpty);
    });

    test('fails when the run published nothing', () async {
      final failures = <int>[];
      final given = await arguments(StringBuffer(), failures);

      await given.callback!(null);

      expect(failures, [1]);
      expect(folder.listSync(), isEmpty);
    });
  });
}
