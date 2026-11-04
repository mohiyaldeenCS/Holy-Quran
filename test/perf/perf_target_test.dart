import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';

import '../../integration_test/perf/perf_app.dart';
import '../../integration_test/perf/perf_binding.dart';
import '../../integration_test/perf/perf_pack.dart';
import '../../integration_test/perf/perf_result.dart';
import '../../integration_test/perf/perf_run.dart';
import '../../integration_test/perf/perf_target.dart';

PerfResult _result(WidgetTester tester) =>
    resultOf(tester, 'search', const {'resultsShownMs': 1});

void main() {
  testWidgets('a run publishes what it measured', (tester) async {
    final before = publishedResults.length;

    await runPerf(
      tester,
      scenarios: const ['search'],
      size: PerfPackSize.small,
      seed: QuranAddress('hafs', 1, 1),
      run: (perf) async => [_result(tester)],
    );

    final added = publishedResults.skip(before).toList();
    expect(added.map((r) => r.scenario), ['search']);
    expect(added.single.failed, isFalse);
  });

  testWidgets('a run that ends in an error publishes a failure for each of '
      'its scenarios and the error goes on', (tester) async {
    final before = publishedResults.length;

    await expectLater(
      runPerf(
        tester,
        scenarios: const ['word_sheet', 'ayah_sheet'],
        size: PerfPackSize.small,
        seed: QuranAddress('hafs', 1, 1),
        run: (perf) async => throw StateError('the sheet never opened'),
      ),
      throwsA(isA<StateError>()),
    );

    final added = publishedResults.skip(before).toList();
    expect([for (final r in added) r.scenario], ['word_sheet', 'ayah_sheet']);
    for (final failure in added) {
      expect(failure.failed, isTrue);
      expect(failure.metrics, isEmpty);
      expect(failure.details['reason'], contains('the sheet never opened'));
      expect(failure.details['prepared'], isTrue, reason: 'it built the pack');
      expect(failure.samples, 0);
    }
  });

  testWidgets('a long reason is cut', (tester) async {
    final before = publishedResults.length;

    await expectLater(
      runPerf(
        tester,
        scenarios: const ['search'],
        size: PerfPackSize.small,
        seed: QuranAddress('hafs', 1, 1),
        run: (perf) async => throw StateError('x' * 5000),
      ),
      throwsA(isA<StateError>()),
    );

    final reason = publishedResults[before].details['reason']! as String;
    expect(reason.length, lessThan(400));
  });

  test('the font is loaded only when the pack has to be built', () async {
    final support = Directory.systemTemp.createTempSync('perf_app');
    addTearDown(() => support.deleteSync(recursive: true));
    var loads = 0;
    Future<Uint8List?> load() async {
      loads++;
      return null;
    }

    final first = await PerfApp.open(
      size: PerfPackSize.small,
      support: support,
      loadFont: load,
    );
    final second = await PerfApp.open(
      size: PerfPackSize.small,
      support: support,
      loadFont: load,
    );

    expect(first.packReused, isFalse);
    expect(second.packReused, isTrue);
    expect(loads, 1);
  });
}
