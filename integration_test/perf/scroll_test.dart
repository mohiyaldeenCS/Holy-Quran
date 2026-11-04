// WARNING: a run on a phone uses the app's real id, com.example.holyquran, and
// its data: it overwrites the saved reading position, the UI level and the
// "open at last position" setting, and leaves synthetic packs in the app's
// storage. `flutter drive` also uninstalls an installed build signed with
// another key, which erases everything that build holds. Use a phone with no
// build of the app that holds anything to keep (README, "On a reference
// device").

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';

import 'perf_binding.dart';
import 'perf_pack.dart';
import 'perf_scenarios.dart' as scenarios;
import 'perf_target.dart';

// NF-02. Three runs in one process, as the spike did. The reader saves its
// position as it scrolls, so each run starts from the top of the surah again.
void main() {
  initPerfBinding();

  testWidgets('NF-02 scroll of the longest surah at 1500 px/s', (tester) async {
    for (var run = 0; run < 3; run++) {
      await runPerf(
        tester,
        scenarios: const ['scroll'],
        size: PerfPackSize.full,
        reseed: true,
        seed: QuranAddress('hafs', perfLongSurah, 1),
        run: (perf) async => [await scenarios.scroll(tester, perf)],
      );
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
}
