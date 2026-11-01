import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';

import 'perf_binding.dart';
import 'perf_launch.dart';
import 'perf_pack.dart';
import 'perf_run.dart';
import 'perf_scenarios.dart' as scenarios;

// NF-05. Ten openings of each sheet in one process.
void main() {
  initPerfBinding();

  testWidgets('NF-05 word and ayah sheets open', (tester) async {
    const size = PerfPackSize.full;
    final perf = await preparePerfApp(
      tester,
      size: size,
      reseed: true,
      seed: QuranAddress('hafs', perfLongSurah, 1),
    );
    (await scenarios.sheets(tester, perf)).forEach(publish);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
