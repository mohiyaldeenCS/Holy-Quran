import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/features/search/view_models/search_view_model.dart';

import 'perf_binding.dart';
import 'perf_launch.dart';
import 'perf_pack.dart';
import 'perf_scenarios.dart' as scenarios;

// NF-03. Run it in a new process for each repetition: the first query of a
// process builds the index, which is what the first search of a session pays.
void main() {
  initPerfBinding();

  testWidgets('NF-03 offline search to the first result', (tester) async {
    const size = PerfPackSize.full;
    final perf = await preparePerfApp(
      tester,
      size: size,
      seed: QuranAddress('hafs', 1, 1),
    );
    final results = await scenarios.search(
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
    );
    results.forEach(publish);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
