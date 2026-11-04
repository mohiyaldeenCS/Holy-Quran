import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';

import 'perf_app.dart';
import 'perf_binding.dart';
import 'perf_launch.dart';
import 'perf_pack.dart';
import 'perf_result.dart';
import 'perf_run.dart';

const _reasonLength = 300;

/// Prepares the install, runs [run] over it and publishes what it returns.
///
/// A run that ends in an error publishes a failed result for each of
/// [scenarios] first and then lets the error go on, so that the summary counts
/// it as a miss instead of judging the runs that finished (D-157).
Future<void> runPerf(
  WidgetTester tester, {
  required List<String> scenarios,
  required PerfPackSize size,
  required QuranAddress seed,
  required Future<List<PerfResult>> Function(PerfApp perf) run,
  bool reseed = false,
}) async {
  PerfApp? perf;
  try {
    perf = await preparePerfApp(tester, size: size, seed: seed, reseed: reseed);
    (await run(perf)).forEach(publish);
  } catch (error) {
    final reason = '$error';
    for (final scenario in scenarios) {
      publish(
        resultOf(tester, scenario, const {}, {
          'failed': true,
          'reason': reason.length > _reasonLength
              ? reason.substring(0, _reasonLength)
              : reason,
          'prepared': perf != null && !perf.packReused,
        }),
      );
    }
    rethrow;
  }
}
