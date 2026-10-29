import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/bookmark_repository.dart';
import 'package:holyquran/domain/models/bookmark.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';
import 'package:holyquran/ui/core/widgets/ayah_toolbar.dart';
import 'package:holyquran/ui/core/widgets/bookmark_ribbon.dart';
import 'package:holyquran/utils/result.dart';

import '../../testing/flows/flow_driver.dart';
import '../../testing/flows/flow_rig.dart';

void main() {
  final rig = FlowRig();

  Finder marker(int ayah) => find.byWidgetPredicate(
    (widget) =>
        widget is AyahMarker && widget.number == ayah && !widget.playing,
  );

  rig.test('an ayah is bookmarked in two taps, and the bookmark survives a '
      'restart of the app', (tester, run) async {
    final ayah = QuranAddress('hafs', 1, 3);
    late Bookmark made;

    await run.session(tester, (session) async {
      await tapNamed(tester, flowL10n.tabMushaf);
      expect(find.byType(BookmarkRibbon), findsNothing);
      final bookmarks = session.read<BookmarkRepository>();

      // First tap: the ayah. Second tap: its bookmark button.
      await tester.tap(marker(3).first);
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
      final stored = await tester.runAsync(() => bookmarks.bookmarkAt(ayah));
      made = (stored! as Ok<Bookmark?>).value!;
      expect(made.address, ayah);
    });

    await run.session(tester, (session) async {
      await tapNamed(tester, flowL10n.tabMushaf);
      await settle(
        tester,
        () => find.byType(BookmarkRibbon).evaluate().isNotEmpty,
      );
      expect(find.byType(BookmarkRibbon), findsOneWidget);
      final stored = await tester.runAsync(
        () => session.read<BookmarkRepository>().bookmarkAt(ayah),
      );
      expect((stored! as Ok<Bookmark?>).value, made);
    });
  });
}
