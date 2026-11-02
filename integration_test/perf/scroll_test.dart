import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';

import 'perf_binding.dart';
import 'perf_launch.dart';
import 'perf_pack.dart';
import 'perf_scenarios.dart' as scenarios;

// NF-02. Three runs in one process, as the spike did.
void main() {
  initPerfBinding();

  testWidgets('NF-02 scroll of the longest surah at 1500 px/s', (tester) async {
    const size = PerfPackSize.full;
    final perf = await preparePerfApp(
      tester,
      size: size,
      reseed: true,
      seed: QuranAddress('hafs', perfLongSurah, 1),
    );
    for (var run = 0; run < 3; run++) {
      publish(await scenarios.scroll(tester, perf));
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
}
