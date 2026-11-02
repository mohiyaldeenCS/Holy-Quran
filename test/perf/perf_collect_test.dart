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
}
