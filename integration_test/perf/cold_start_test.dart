import 'package:flutter_test/flutter_test.dart';

import 'perf_binding.dart';
import 'perf_launch.dart';
import 'perf_pack.dart';
import 'perf_run.dart';
import 'perf_scenarios.dart' as scenarios;

// NF-01. One start per process: the first launch of an install builds the pack
// and its result is not counted; each launch after it is a cold start.
void main() {
  initPerfBinding();

  testWidgets('NF-01 cold start to the last position', (tester) async {
    const size = PerfPackSize.full;
    final saved = scenarios.middleOfLongSurah(size);
    final perf = await preparePerfApp(tester, size: size, seed: saved);
    publish(await scenarios.coldStart(tester, perf, saved: saved));
  }, timeout: const Timeout(Duration(minutes: 15)));
}
