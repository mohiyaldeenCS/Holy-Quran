// WARNING: a run on a phone uses the app's real id, com.example.holyquran, and
// its data: it overwrites the saved reading position, the UI level and the
// "open at last position" setting, and leaves synthetic packs in the app's
// storage. `flutter drive` also uninstalls an installed build signed with
// another key, which erases everything that build holds. Use a phone with no
// build of the app that holds anything to keep (README, "On a reference
// device").

import 'package:flutter_test/flutter_test.dart';

import 'perf_binding.dart';
import 'perf_pack.dart';
import 'perf_scenarios.dart' as scenarios;
import 'perf_target.dart';

// NF-01. One start per process: the first launch of an install builds the pack
// and its result is not counted; each launch after it is a cold start. A run
// leaves the saved position as it found it, so the targets can run in any
// order.
void main() {
  initPerfBinding();

  testWidgets('NF-01 cold start to the last position', (tester) async {
    const size = PerfPackSize.full;
    final saved = scenarios.middleOfLongSurah(size);
    await runPerf(
      tester,
      scenarios: const ['cold_start'],
      size: size,
      seed: saved,
      run: (perf) async => [
        await scenarios.coldStart(tester, perf, saved: saved),
      ],
    );
  }, timeout: const Timeout(Duration(minutes: 15)));
}
