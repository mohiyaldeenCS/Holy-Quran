import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/playback_segment.dart';
import 'package:holyquran/domain/models/player_state.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/reader/gesture_target.dart';
import 'package:holyquran/ui/core/shell_chrome.dart';
import 'package:holyquran/ui/core/theme/motion.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';
import 'package:holyquran/ui/core/widgets/ayah_toolbar.dart';
import 'package:holyquran/ui/core/widgets/position_bar.dart';
import 'package:holyquran/ui/core/widgets/small_button.dart';
import 'package:holyquran/ui/features/mushaf/view_models/mushaf_view_model.dart';

import '../../../../testing/fakes/fake_keep_awake_repository.dart';
import '../../../../testing/fakes/fake_player_repository.dart';
import 'mushaf_harness.dart';
import 'recitation_fixture.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

void main() {
  late Directory root;
  late MushafRig rig;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('mushaf_follow');
    rig = await MushafRig.load(root);
  });
  tearDownAll(() async {
    rig.close();
    await root.delete(recursive: true);
  });

  late FakePlayerRepository player;
  late MushafViewModel viewModel;
  late ShellChrome chrome;

  Future<void> pumpReader(
    WidgetTester tester, {
    double textScale = 1,
    FakeKeepAwakeRepository? keepAwake,
  }) async {
    setReaderView(tester);
    player = FakePlayerRepository();
    chrome = ShellChrome();
    viewModel = rig.viewModel(
      address: ayahAt(2, 1),
      player: player,
      keepAwake: keepAwake,
    );
    addTearDown(viewModel.dispose);
    await tester.pumpWidget(
      readerApp(viewModel, textScale: textScale, chrome: chrome),
    );
    await tester.pumpAndSettle();
  }

  /// The numbers of the markers drawn filled: the ayat being recited.
  List<int> filled(WidgetTester tester) => [
    for (final marker in tester.widgetList<AyahMarker>(find.byType(AyahMarker)))
      if (marker.playing) marker.number,
  ];

  Finder playingMarker() => find.byWidgetPredicate(
    (widget) => widget is AyahMarker && widget.playing,
  );

  double offset(WidgetTester tester) => scrollOf(tester).offset;

  Finder returnButton() => find.text(_l10n.returnToRecitation);

  Future<void> dragText(WidgetTester tester) async {
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -150));
    await tester.pumpAndSettle();
  }

  group('the recited ayah (SY-01)', () {
    testWidgets('is highlighted, with its marker filled, as the events move', (
      tester,
    ) async {
      await pumpReader(tester);
      expect(filled(tester), isEmpty);

      final plan = recitationPlan();
      player.reach(plan, ayahSegment(2, 2));
      await tester.pumpAndSettle();
      expect(filled(tester), [2]);

      player.reach(plan, ayahSegment(2, 3), index: 1);
      await tester.pumpAndSettle();
      expect(filled(tester), [3]);
    });

    testWidgets('is cleared when playback stops', (tester) async {
      await pumpReader(tester);
      player.reach(recitationPlan(), ayahSegment(2, 2));
      await tester.pumpAndSettle();
      expect(filled(tester), [2]);

      await player.stop();
      await tester.pumpAndSettle();
      expect(filled(tester), isEmpty);
    });

    testWidgets('is none for a recitation served as whole surahs', (
      tester,
    ) async {
      await pumpReader(tester);
      player.reach(recitationPlan(boundaries: false), surahSegment(2));
      await tester.pumpAndSettle();
      await dragText(tester);
      final moved = offset(tester);

      expect(filled(tester), isEmpty);
      expect(returnButton(), findsNothing);
      expect(offset(tester), moved);
    });

    for (final speed in [PlaybackSpeed.all.first, PlaybackSpeed.all.last]) {
      testWidgets('keeps step with the events at ${speed.factor}x (SY-04)', (
        tester,
      ) async {
        await pumpReader(tester);
        final plan = recitationPlan();
        player.reach(plan, ayahSegment(2, 2));
        await player.setSpeed(speed);
        await tester.pumpAndSettle();
        expect(filled(tester), [2]);

        player.reach(plan, ayahSegment(2, 3), index: 1);
        await tester.pumpAndSettle();
        expect(player.state.speed, speed);
        expect(filled(tester), [3]);
      });
    }
  });

  group('following (SY-03)', () {
    testWidgets('scrolls to an ayah out of view', (tester) async {
      await pumpReader(tester);
      expect(offset(tester), 0);

      player.reach(recitationPlan(), ayahSegment(2, 30));
      await tester.pumpAndSettle();

      expect(offset(tester), greaterThan(0));
      expect(filled(tester), [30]);
      final marker = tester.getCenter(
        find.byWidgetPredicate(
          (widget) => widget is AyahMarker && widget.playing,
        ),
      );
      expect(marker.dy, inInclusiveRange(0, readerHeight));
    });

    testWidgets('leaves the text where it is while the ayah is in view', (
      tester,
    ) async {
      await pumpReader(tester);
      player.reach(recitationPlan(), ayahSegment(2, 2));
      await tester.pumpAndSettle();

      expect(offset(tester), 0);
    });

    testWidgets('animates, unless the platform asks for less motion', (
      tester,
    ) async {
      await pumpReader(tester);
      player.reach(recitationPlan(), ayahSegment(2, 30));
      await tester.pump();
      expect(offset(tester), 0);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(motionNormal ~/ 2);
      final partway = offset(tester);
      await tester.pumpAndSettle();

      expect(partway, greaterThan(0));
      expect(partway, lessThan(offset(tester)));
    });

    testWidgets('jumps when the platform asks for less motion', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpReader(tester);
      player.reach(recitationPlan(), ayahSegment(2, 30));
      await tester.pump();

      expect(offset(tester), greaterThan(0));
      await tester.pumpAndSettle();
      expect(filled(tester), [30]);
    });

    testWidgets('brings in the next surah when the recitation runs into it', (
      tester,
    ) async {
      await pumpReader(tester);
      expect(viewModel.surahs.map((s) => s.info.number), [2]);

      player.reach(recitationPlan(), ayahSegment(3, 1));
      await tester.pumpAndSettle();

      expect(viewModel.surahs.map((s) => s.info.number), contains(3));
      expect(filled(tester), [1]);
      expect(offset(tester), greaterThan(0));
      expect(
        tester.getCenter(playingMarker()).dy,
        inInclusiveRange(0, readerHeight),
      );
    });

    testWidgets('a scroll of the user stops it and offers the way back', (
      tester,
    ) async {
      await pumpReader(tester);
      final plan = recitationPlan();
      player.reach(plan, ayahSegment(2, 2));
      await tester.pumpAndSettle();
      expect(returnButton(), findsNothing);

      await dragText(tester);
      expect(returnButton(), findsOneWidget);
      final moved = offset(tester);

      player.reach(plan, ayahSegment(2, 30), index: 1);
      await tester.pumpAndSettle();

      expect(offset(tester), moved);
      expect(viewModel.follow.recited, ayahAt(2, 30));
      expect(returnButton(), findsOneWidget);
    });

    testWidgets('the button goes back to the recitation and follows again', (
      tester,
    ) async {
      await pumpReader(tester);
      final plan = recitationPlan();
      player.reach(plan, ayahSegment(2, 2));
      await tester.pumpAndSettle();
      await dragText(tester);
      player.reach(plan, ayahSegment(2, 30), index: 1);
      await tester.pumpAndSettle();
      final away = offset(tester);

      await tester.tap(returnButton());
      await tester.pumpAndSettle();

      expect(returnButton(), findsNothing);
      expect(viewModel.follow.following, isTrue);
      expect(offset(tester), greaterThan(away));
      player.reach(plan, ayahSegment(2, 36), index: 2);
      await tester.pumpAndSettle();
      expect(filled(tester), [36]);
      expect(offset(tester), greaterThan(away));
    });

    testWidgets('a new recitation follows again', (tester) async {
      await pumpReader(tester);
      player.reach(recitationPlan(), ayahSegment(2, 2));
      await tester.pumpAndSettle();
      await dragText(tester);
      expect(returnButton(), findsOneWidget);

      final next = recitationPlan();
      await player.play(next);
      player.reach(next, ayahSegment(2, 30));
      await tester.pumpAndSettle();

      expect(returnButton(), findsNothing);
      expect(filled(tester), [30]);
    });

    testWidgets('the button is gone once playback stops', (tester) async {
      await pumpReader(tester);
      player.reach(recitationPlan(), ayahSegment(2, 2));
      await tester.pumpAndSettle();
      await dragText(tester);

      await player.stop();
      await tester.pumpAndSettle();

      expect(returnButton(), findsNothing);
    });

    testWidgets('the distraction-free state hides the button with the rest', (
      tester,
    ) async {
      await pumpReader(tester);
      player.reach(recitationPlan(), ayahSegment(2, 2));
      await tester.pumpAndSettle();
      await dragText(tester);

      viewModel.setDistractionFree(true);
      await tester.pumpAndSettle();
      expect(returnButton(), findsNothing);

      viewModel.setDistractionFree(false);
      await tester.pumpAndSettle();
      expect(returnButton(), findsOneWidget);
    });

    testWidgets('the button is labelled and reaches 48 at 200% text', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpReader(tester, textScale: 2);
      player.reach(recitationPlan(), ayahSegment(2, 2));
      await tester.pumpAndSettle();
      await dragText(tester);

      expect(find.bySemanticsLabel(_l10n.returnToRecitation), findsOneWidget);
      expect(
        tester.getSize(find.byType(SmallButton)).height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });

  group('stand mode (SY-05)', () {
    testWidgets('hides the interface and follows whatever the user does', (
      tester,
    ) async {
      await pumpReader(tester);
      expect(find.byType(PositionBar), findsOneWidget);

      viewModel.setStandMode(true);
      await tester.pumpAndSettle();
      expect(find.byType(PositionBar), findsNothing);
      expect(chrome.tabBarVisible, isFalse);

      final plan = recitationPlan();
      player.reach(plan, ayahSegment(2, 2));
      await tester.pumpAndSettle();
      await dragText(tester);
      expect(returnButton(), findsNothing);

      player.reach(plan, ayahSegment(2, 36), index: 1);
      await tester.pumpAndSettle();
      expect(filled(tester), [36]);
      final marker = tester.getCenter(
        find.byWidgetPredicate(
          (widget) => widget is AyahMarker && widget.playing,
        ),
      );
      expect(marker.dy, inInclusiveRange(0, readerHeight));
    });

    testWidgets('a tap does not bring the interface back, nor change it '
        'after', (tester) async {
      await pumpReader(tester);
      viewModel.setStandMode(true);
      await tester.pumpAndSettle();

      viewModel.tap(const MarginTarget(), wordSheet: false);
      await tester.pumpAndSettle();
      expect(viewModel.distractionFree, isTrue);

      viewModel.setStandMode(false);
      await tester.pumpAndSettle();
      expect(viewModel.distractionFree, isFalse);
    });

    testWidgets('a drag does not call off the scroll to the ayah', (
      tester,
    ) async {
      await pumpReader(tester);
      viewModel.setStandMode(true);
      await tester.pumpAndSettle();

      player.reach(recitationPlan(), ayahSegment(2, 30));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(filled(tester), [30]);
      expect(viewModel.follow.following, isTrue);
    });

    testWidgets('a long press or a tap on a marker selects nothing', (
      tester,
    ) async {
      await pumpReader(tester);
      viewModel.select(ayahAt(2, 3));
      await tester.pumpAndSettle();
      expect(find.byType(AyahToolbar), findsOneWidget);

      viewModel.setStandMode(true);
      await tester.pumpAndSettle();
      expect(viewModel.selectedAyah, isNull);
      expect(find.byType(AyahToolbar), findsNothing);

      viewModel.longPress(WordTarget(ayahAt(2, 3)));
      viewModel.tap(MarkerTarget(ayahAt(2, 4)), wordSheet: false);
      await tester.pumpAndSettle();

      expect(viewModel.selectedAyah, isNull);
      expect(find.byType(AyahToolbar), findsNothing);
    });

    testWidgets('leaving it gives the interface back', (tester) async {
      await pumpReader(tester);
      viewModel.setStandMode(true);
      await tester.pumpAndSettle();

      viewModel.setStandMode(false);
      await tester.pumpAndSettle();

      expect(find.byType(PositionBar), findsOneWidget);
      expect(chrome.tabBarVisible, isTrue);
    });
  });

  group('the screen stays on (RD-16)', () {
    late FakeKeepAwakeRepository keepAwake;

    setUp(() => keepAwake = FakeKeepAwakeRepository());

    testWidgets('while a recitation sounds under the reader, and after it '
        'pauses', (tester) async {
      await pumpReader(tester, keepAwake: keepAwake);
      player.reach(recitationPlan(), ayahSegment(2, 2));
      await tester.pumpAndSettle();
      expect(keepAwake.awake, isTrue);

      await player.pause();
      await tester.pumpAndSettle();
      expect(keepAwake.awake, isTrue);
    });

    testWidgets('not once the reader is left, with the setting on', (
      tester,
    ) async {
      await pumpReader(tester, keepAwake: keepAwake);
      player.reach(recitationPlan(), ayahSegment(2, 2));
      await tester.pumpAndSettle();

      await viewModel.leave();
      await tester.pumpAndSettle();

      expect(keepAwake.awake, isFalse);
    });

    testWidgets('in stand mode, setting or no setting (SY-05)', (tester) async {
      keepAwake.settingOn = false;
      await pumpReader(tester, keepAwake: keepAwake);
      player.reach(recitationPlan(), ayahSegment(2, 2));
      await tester.pumpAndSettle();
      expect(keepAwake.awake, isFalse);

      viewModel.setStandMode(true);
      await tester.pumpAndSettle();
      expect(keepAwake.awake, isTrue);

      viewModel.setStandMode(false);
      await tester.pumpAndSettle();
      expect(keepAwake.awake, isFalse);
    });

    testWidgets('not in stand mode once the reader is left', (tester) async {
      keepAwake.settingOn = false;
      await pumpReader(tester, keepAwake: keepAwake);
      viewModel.setStandMode(true);
      await tester.pumpAndSettle();

      await viewModel.leave();
      await tester.pumpAndSettle();

      expect(keepAwake.awake, isFalse);
    });
  });

  group('an ayah of another riwaya', () {
    testWidgets('of a surah shown is neither highlighted nor scrolled to', (
      tester,
    ) async {
      await pumpReader(tester);
      final other = QuranAddress('warsh', 2, 30);
      player.reach(
        recitationPlan(),
        PlaybackSegment(
          kind: SegmentKind.ayah,
          address: other,
          source: AyahFile(other),
          repeat: 1,
        ),
      );
      await tester.pumpAndSettle();

      expect(offset(tester), 0);
      expect(filled(tester), isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('the last ayah of the surahs shown', () {
    testWidgets('is reached once the next surah is appended', (tester) async {
      await pumpReader(tester);

      player.reach(recitationPlan(), ayahSegment(2, 40));
      await tester.pumpAndSettle();

      expect(filled(tester), [40]);
      expect(
        tester.getCenter(playingMarker()).dy,
        inInclusiveRange(0, readerHeight),
      );
    });
  });

  group('a surah the reader does not show', () {
    testWidgets('after the ones shown opens the reader at the ayah', (
      tester,
    ) async {
      await pumpReader(tester);

      player.reach(recitationPlan(), ayahSegment(6, 1));
      await tester.pumpAndSettle();

      expect(viewModel.surahs.first.info.number, 6);
      expect(filled(tester), [1]);
      expect(returnButton(), findsNothing);
    });

    testWidgets('before the ones shown opens the reader at the ayah', (
      tester,
    ) async {
      await pumpReader(tester);

      player.reach(recitationPlan(), ayahSegment(1, 1));
      await tester.pumpAndSettle();

      expect(viewModel.surahs.first.info.number, 1);
      expect(filled(tester), [1]);
    });

    testWidgets('is reached by the way back, after the user scrolled', (
      tester,
    ) async {
      await pumpReader(tester);
      final plan = recitationPlan();
      player.reach(plan, ayahSegment(2, 2));
      await tester.pumpAndSettle();
      await dragText(tester);
      player.reach(plan, ayahSegment(6, 1), index: 1);
      await tester.pumpAndSettle();
      expect(viewModel.surahs.map((s) => s.info.number), isNot(contains(6)));
      expect(returnButton(), findsOneWidget);

      await tester.tap(returnButton());
      await tester.pumpAndSettle();

      expect(viewModel.surahs.first.info.number, 6);
      expect(filled(tester), [1]);
      expect(returnButton(), findsNothing);
    });
  });

  group('a reader that is not shown', () {
    testWidgets('waits to follow until it is', (tester) async {
      final shown = ValueNotifier(false);
      addTearDown(shown.dispose);
      setReaderView(tester);
      player = FakePlayerRepository();
      viewModel = rig.viewModel(address: ayahAt(2, 1), player: player);
      addTearDown(viewModel.dispose);
      await tester.pumpWidget(readerApp(viewModel, shown: shown));
      shown.value = true;
      await tester.pumpAndSettle();
      shown.value = false;
      await tester.pumpAndSettle();

      player.reach(recitationPlan(), ayahSegment(6, 1));
      await tester.pumpAndSettle();
      expect(viewModel.surahs.map((s) => s.info.number), [2]);

      shown.value = true;
      await tester.pumpAndSettle();
      expect(viewModel.surahs.first.info.number, 6);
    });
  });
}
