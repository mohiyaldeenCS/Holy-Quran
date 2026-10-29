import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/bookmark_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/data/repositories/search_history_repository.dart';
import 'package:holyquran/domain/models/bookmark.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';
import 'package:holyquran/ui/core/widgets/ayah_toolbar.dart';
import 'package:holyquran/ui/core/widgets/bookmark_ribbon.dart';
import 'package:holyquran/ui/core/widgets/search_result.dart';
import 'package:holyquran/ui/features/home/views/home_screen.dart';
import 'package:holyquran/ui/features/mushaf/view_models/mushaf_view_model.dart';
import 'package:holyquran/ui/features/mushaf/views/mushaf_screen.dart';
import 'package:holyquran/ui/features/search/views/search_screen.dart';
import 'package:holyquran/utils/result.dart';
import 'package:provider/provider.dart';

import '../packs/synthetic_files.dart' show syntheticArabic;
import 'flow_driver.dart';
import 'flow_rig.dart';

// The flows that need nothing of a test's clock or mocks beyond what a run of
// the rig gives, so that the widget tests under test/flows/ and the device
// tests under integration_test/ run the same steps (NF-20).

Finder _marker(int ayah) => find.byWidgetPredicate(
  (widget) => widget is AyahMarker && widget.number == ayah && !widget.playing,
);

MushafViewModel _reader(WidgetTester tester) =>
    tester.element(find.byType(MushafScreen).last).read<MushafViewModel>();

/// `UD-05`, `NF-20`: an ayah is bookmarked in two taps, the ayah and the
/// bookmark button, and the bookmark is there after the app restarts.
Future<void> bookmarkInTwoTaps(WidgetTester tester, FlowRun run) async {
  final ayah = QuranAddress('hafs', 1, 3);
  late Bookmark made;

  await run.session(tester, (session) async {
    await tapNamed(tester, flowL10n.tabMushaf);
    expect(find.byType(BookmarkRibbon), findsNothing);
    final bookmarks = session.read<BookmarkRepository>();

    await tester.tap(_marker(3).first);
    await tester.pumpAndSettle();
    expect(find.byType(AyahToolbar), findsOneWidget);
    await tapNamed(
      tester,
      flowL10n.toolbarBookmark,
      done: () => find.byType(BookmarkRibbon).evaluate().isNotEmpty,
    );

    expect(find.byType(BookmarkRibbon), findsOneWidget);
    expect(
      tester.widget<AyahToolbar>(find.byType(AyahToolbar)).bookmarked,
      isTrue,
    );
    final stored = await real(tester, () => bookmarks.bookmarkAt(ayah));
    made = (stored as Ok<Bookmark?>).value!;
    expect(made.address, ayah);
  });

  await run.session(tester, (session) async {
    await tapNamed(tester, flowL10n.tabMushaf);
    await settle(
      tester,
      () => find.byType(BookmarkRibbon).evaluate().isNotEmpty,
    );
    expect(find.byType(BookmarkRibbon), findsOneWidget);
    final stored = await real(
      tester,
      () => session.read<BookmarkRepository>().bookmarkAt(ayah),
    );
    expect((stored as Ok<Bookmark?>).value, made);
  });
}

/// `RD-13`, `NF-20`: the app opens at the ayah where the last session stopped
/// reading when the user asked for it, and on home when he did not.
Future<void> reopenAtLastPosition(WidgetTester tester, FlowRun run) async {
  late QuranAddress last;

  await run.session(tester, (session) async {
    await real(
      tester,
      () => session.read<AppSettingsRepository>().setOpenAtLastPosition(true),
    );
    expect(find.byType(HomeScreen), findsOneWidget);

    // Home, the index, the second juz: the reader opens in the middle of a
    // surah; then the user reads on.
    await tapNamed(tester, flowL10n.homeDoorIndex);
    await tapNamed(tester, flowL10n.indexTabJuz);
    await tapNamed(tester, RegExp(flowL10n.juzLabel(arabicDigits(2))));
    expect(find.byType(MushafScreen), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(_reader(tester).position!.address.ayah, greaterThan(20));

    // Where reading stopped is saved, and again when the app is left.
    pauseApp(tester);
    await settle(
      tester,
      () => session.read<ReadingPositionRepository>().last != null,
    );
    last = session.read<ReadingPositionRepository>().last!;
    expect(last.surah, 2);
    expect(last.ayah, greaterThan(20));
    // The write is in flight on the database's own time.
    await settle(tester);
  });

  await run.session(tester, (session) async {
    expect(find.byType(HomeScreen), findsNothing);
    expect(_reader(tester).position!.address, last);
  });

  await run.session(tester, (session) async {
    expect(find.byType(MushafScreen), findsOneWidget);
    await real(
      tester,
      () => session.read<AppSettingsRepository>().setOpenAtLastPosition(false),
    );
    await settle(tester);
  });
  await run.session(tester, (session) async {
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(MushafScreen), findsNothing);
    expect(session.read<ReadingPositionRepository>().last, last);
  });
}

/// `SR-01` to `SR-03`, `SR-10`, `NF-20`: a search finds the ayah, the result
/// shows it as the pack holds it, and opening it leads to the reader at that
/// ayah.
Future<void> searchAndOpenResult(WidgetTester tester, FlowRun run) async {
  final ayah = QuranAddress('hafs', 2, 5);
  const query = '$syntheticArabic word 2:5:1';

  await run.session(tester, (session) async {
    final text = session.read<QuranTextRepository>();
    final stored = switch (await real(tester, () => text.ayahText(ayah))) {
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

    // The synthetic pack's search form of the first word of 2:5: the pack's
    // own data, found by the engine, never derived from the text.
    await tester.enterText(find.byType(EditableText), query);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester, () => find.byType(SearchResult).evaluate().isNotEmpty);

    expect(find.byType(SearchResult), findsOneWidget);
    expect(spokenNames(tester), contains(stored));

    await tapNamed(tester, flowL10n.searchResultOpen);
    expect(find.byType(MushafScreen), findsWidgets);
    expect(_reader(tester).position!.address, ayah);
    expect(spokenNames(tester), contains(stored));

    // The query is kept on the device for the next search (SR-10).
    final kept = await real(
      tester,
      session.read<SearchHistoryRepository>().queries,
    );
    expect((kept as Ok<List<String>>).value, [query]);
  });
}
