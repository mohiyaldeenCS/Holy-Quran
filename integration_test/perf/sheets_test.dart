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

// NF-05. Ten openings of each sheet in one process.
void main() {
  initPerfBinding();

  testWidgets('NF-05 word and ayah sheets open', (tester) async {
    await runPerf(
      tester,
      scenarios: const ['word_sheet', 'ayah_sheet'],
      size: PerfPackSize.full,
      reseed: true,
      seed: QuranAddress('hafs', perfLongSurah, 1),
      run: (perf) => scenarios.sheets(tester, perf),
    );
  }, timeout: const Timeout(Duration(minutes: 15)));
}
