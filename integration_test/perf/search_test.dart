// WARNING: a run on a phone uses the app's real id, com.example.holyquran, and
// its data: it overwrites the saved reading position, the UI level and the
// "open at last position" setting, and leaves synthetic packs in the app's
// storage. `flutter drive` also uninstalls an installed build signed with
// another key, which erases everything that build holds. Use a phone with no
// build of the app that holds anything to keep (README, "On a reference
// device").

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/features/search/view_models/search_view_model.dart';

import 'perf_binding.dart';
import 'perf_pack.dart';
import 'perf_scenarios.dart' as scenarios;
import 'perf_target.dart';

// NF-03. Run it in a new process for each repetition: the first query of a
// process builds the index, which is what the first search of a session pays.
void main() {
  initPerfBinding();

  testWidgets('NF-03 offline search to the first result', (tester) async {
    const size = PerfPackSize.full;
    await runPerf(
      tester,
      scenarios: const ['search', 'search_warm'],
      size: size,
      seed: scenarios.middleOfLongSurah(size),
      run: (perf) => scenarios.search(
        tester,
        perf,
        first: scenarios.searchQueryFor(
          SearchKinds.word,
          QuranAddress('hafs', 5, 2, 1),
        ),
        second: scenarios.searchQueryFor(
          SearchKinds.word,
          QuranAddress('hafs', 40, 3, 1),
        ),
      ),
    );
  }, timeout: const Timeout(Duration(minutes: 15)));
}
