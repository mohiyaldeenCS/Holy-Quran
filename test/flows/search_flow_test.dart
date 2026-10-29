import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/repositories/search_history_repository.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/widgets/search_result.dart';
import 'package:holyquran/ui/features/mushaf/view_models/mushaf_view_model.dart';
import 'package:holyquran/ui/features/mushaf/views/mushaf_screen.dart';
import 'package:holyquran/ui/features/search/views/search_screen.dart';
import 'package:holyquran/utils/result.dart';
import 'package:provider/provider.dart';

import '../../testing/flows/flow_driver.dart';
import '../../testing/flows/flow_rig.dart';
import '../../testing/packs/synthetic_files.dart' show syntheticArabic;

void main() {
  final rig = FlowRig();

  rig.test('a search finds the ayah, shows it as the pack holds it, and its '
      'result opens the reader at that ayah', (tester, run) async {
    final ayah = QuranAddress('hafs', 2, 5);
    const query = '$syntheticArabic word 2:5:1';

    await run.session(tester, (session) async {
      final text = session.read<QuranTextRepository>();
      final stored = switch (await text.ayahText(ayah)) {
        Ok(:final value) => value.verbatim,
        Failure(:final error) => fail('$error'),
      };

      await tapNamed(tester, flowL10n.homeSearch);
      expect(find.byType(SearchScreen), findsOneWidget);
      // The chips show once the pack's search forms are read.
      await settle(
        tester,
        () => spokenNames(tester).contains(flowL10n.searchModesLabel),
      );

      // The synthetic pack's search form of the first word of 2:5: the
      // pack's own data, found by the engine, never derived from the text.
      await tester.enterText(find.byType(EditableText), query);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(
        tester,
        () => find.byType(SearchResult).evaluate().isNotEmpty,
      );

      expect(find.byType(SearchResult), findsOneWidget);
      expect(spokenNames(tester), contains(stored));

      await tapNamed(tester, flowL10n.searchResultOpen);
      expect(find.byType(MushafScreen), findsWidgets);
      final reader = tester
          .element(find.byType(MushafScreen).last)
          .read<MushafViewModel>();
      expect(reader.position!.address, ayah);
      expect(spokenNames(tester), contains(stored));

      // The query is kept on the device for the next search (SR-10).
      final kept = await session.read<SearchHistoryRepository>().queries();
      expect((kept as Ok<List<String>>).value, [query]);
    });
  });
}
