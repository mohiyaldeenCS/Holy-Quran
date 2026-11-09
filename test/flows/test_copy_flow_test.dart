import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/services/share_service.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/share/copy_sheet_view.dart';
import 'package:holyquran/ui/core/share/share_card_sheet_view.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';
import 'package:holyquran/ui/core/widgets/ayah_toolbar.dart';
import 'package:holyquran/ui/core/widgets/search_result.dart';
import 'package:holyquran/ui/core/widgets/unapproved_copy_banner.dart';
import 'package:holyquran/ui/features/home/views/home_screen.dart';
import 'package:holyquran/ui/features/mushaf/views/mushaf_screen.dart';
import 'package:holyquran/ui/features/search/views/search_screen.dart';
import 'package:holyquran/ui/features/sheets/views/ayah_sheet_view.dart';
import 'package:holyquran/utils/result.dart';

import '../../testing/flows/flow_driver.dart';
import '../../testing/flows/flow_rig.dart';
import '../../testing/flows/flow_test_copy.dart';
import '../../testing/packs/synthetic_files.dart' show syntheticArabic;
import '../integrity/pack_integrity_suite.dart';
import '../ui/core/share/share_test_pack.dart';
import 'copy_scenario.dart';

// D-162 (4), (14), D-163, D-164: the unapproved test copy, run over a
// synthetic pack signed with a key made here and read through
// DevicePackBundle from a folder, as the phone's files are. No Quran text is
// typed: the ayat are the synthetic pack's, and the expected copy is made
// from the pack's stored bytes.

/// The ayah the search finds, and an ayah of the reader's first screen.
final _found = QuranAddress('hafs', 2, 5);
final _first = QuranAddress('hafs', 1, 3);

/// The user taps the ayah, and its toolbar opens.
Future<void> openToolbar(WidgetTester tester, QuranAddress ayah) async {
  await tester.tap(
    find
        .byWidgetPredicate(
          (w) => w is AyahMarker && w.number == ayah.ayah && !w.playing,
        )
        .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  late Directory parent;
  setUp(() => parent = Directory.systemTemp.createTempSync('test_copy_flow'));
  tearDown(() => parent.deleteSync(recursive: true));

  Future<TestCopyPack> build(WidgetTester tester, {bool signed = true}) =>
      real(tester, () => buildFlowTestCopy(parent, signed: signed));

  void expectBanner() {
    expect(find.byType(UnapprovedCopyBanner), findsOneWidget);
    expect(find.text(flowL10n.unapprovedTestCopy), findsOneWidget);
  }

  FlowRig().test('the banner is on home, the reader, search results and the '
      'ayah sheet', (tester, run) async {
    final pack = await build(tester);
    await run.session(tester, testCopy: pack, (session) async {
      expect(find.byType(HomeScreen), findsOneWidget);
      expectBanner();

      final text = session.read<QuranTextRepository>();
      final stored = switch (await real(tester, () => text.ayahText(_found))) {
        Ok(:final value) => value.verbatim,
        Failure(:final error) => fail('$error'),
      };

      await tapNamed(tester, flowL10n.homeSearch);
      expect(find.byType(SearchScreen), findsOneWidget);
      await settle(
        tester,
        () => spokenNames(tester).contains(flowL10n.searchModesLabel),
      );
      await tester.enterText(
        find.byType(EditableText),
        '$syntheticArabic word 2:5:1',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(
        tester,
        () => find.byType(SearchResult).evaluate().isNotEmpty,
      );
      expect(find.byType(SearchResult), findsOneWidget);
      expect(spokenNames(tester), contains(stored));
      expectBanner();

      await tapNamed(tester, flowL10n.searchResultOpen);
      expect(find.byType(MushafScreen), findsWidgets);
      expect(spokenNames(tester), contains(stored));
      expectBanner();

      await openToolbar(tester, _found);
      expect(find.byType(AyahToolbar), findsOneWidget);
      expectBanner();

      await tapNamed(tester, flowL10n.toolbarStudy);
      expect(find.byType(AyahSheetView), findsOneWidget);
      expectBanner();
    });
  });

  FlowRig().test('copying an ayah puts the approved composition, a newline '
      'and the marking line on the clipboard', (tester, run) async {
    mockClipboard(tester);
    final pack = await build(tester);
    final loaded = await real(
      tester,
      () => PackUnderTest.load('${pack.root.path}/$flowTestCopyId/1'),
    );
    addTearDown(loaded.close);
    final ayat = await real(
      tester,
      () => packAyat(loaded, loaded.openRepository()),
    );
    expect(ayat.length, loaded.manifest.counts.ayat);
    final ayah = ayat.firstWhere((a) => a.address == _first);
    final expected = [
      ...expectedCopy(ayah.stored, ayah.storedName, _first.ayah),
      ...utf8.encode('\n${flowL10n.unapprovedTestCopy}'),
    ];

    await run.session(tester, testCopy: pack, (session) async {
      await tapNamed(tester, flowL10n.tabMushaf);
      await openToolbar(tester, _first);
      expect(find.byType(AyahToolbar), findsOneWidget);
      await clearClipboard(tester);
      await tapNamed(tester, flowL10n.toolbarCopy);
      expect(find.byType(CopySheetView), findsOneWidget);
      expectBanner();
      await tapNamed(tester, flowL10n.copyAction);

      final copied = await copiedText(tester);
      expect(copied, isNotNull);
      expect(byteMismatch(utf8.encode(copied!), expected), isNull);
      expect(copied.endsWith('\n${flowL10n.unapprovedTestCopy}'), isTrue);
    });
  });

  FlowRig().test('the share card is unreachable', (tester, run) async {
    final pack = await build(tester);
    await run.session(tester, testCopy: pack, (session) async {
      expect(() => session.read<ShareService>(), throwsStateError);

      await tapNamed(tester, flowL10n.tabMushaf);
      await openToolbar(tester, _first);
      expect(find.byType(AyahToolbar), findsOneWidget);
      expect(spokenNames(tester), contains(flowL10n.toolbarCopy));
      expect(spokenNames(tester), isNot(contains(flowL10n.toolbarShare)));

      final router = GoRouter.of(tester.element(find.byType(Navigator).first));
      unawaited(router.push<Object?>(Routes.shareSheet(_first)));
      await tester.pumpAndSettle();
      expect(find.byType(ShareCardSheetView), findsNothing);
    });
  });

  FlowRig().test('an approved build has the share card the copy lacks', (
    tester,
    run,
  ) async {
    await run.session(tester, (session) async {
      expect(session.read<ShareService>(), isNotNull);
      expect(find.byType(UnapprovedCopyBanner), findsNothing);

      await tapNamed(tester, flowL10n.tabMushaf);
      await openToolbar(tester, _first);
      expect(spokenNames(tester), contains(flowL10n.toolbarShare));
    });
  });

  FlowRig().test('a pack without a signature shows the integrity alert on '
      'home and no text', (tester, run) async {
    final pack = await build(tester, signed: false);
    await run.session(
      tester,
      testCopy: pack,
      features: testCopyFeatures(pack),
      (session) async {
        expect(find.byType(HomeScreen), findsOneWidget);
        expectBanner();
        expect(find.text(flowL10n.integrityBaseTitle), findsOneWidget);
        expect(find.text(flowL10n.integrityBaseBody), findsOneWidget);
        expect(() => session.read<QuranTextRepository>(), throwsStateError);
        expect(find.byType(SearchResult), findsNothing);
      },
    );
  });
}
