import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/player_state.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/shell_chrome.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';
import 'package:holyquran/ui/core/widgets/ayah_toolbar.dart';
import 'package:holyquran/ui/core/widgets/reader_player_bar.dart';
import 'package:holyquran/ui/core/widgets/small_button.dart';
import 'package:holyquran/ui/features/mushaf/view_models/mushaf_view_model.dart';

import '../../../../testing/fakes/fake_player_repository.dart';
import 'mushaf_harness.dart';
import 'recitation_fixture.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

void main() {
  late Directory root;
  late MushafRig rig;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('mushaf_player_bar');
    rig = await MushafRig.load(root);
  });
  tearDownAll(() async {
    rig.close();
    await root.delete(recursive: true);
  });

  late FakePlayerRepository player;
  late MushafViewModel viewModel;
  late ShellChrome chrome;
  late ValueNotifier<bool> shown;

  Future<void> pumpReader(WidgetTester tester, {double textScale = 1}) async {
    setReaderView(tester);
    player = FakePlayerRepository();
    chrome = ShellChrome();
    shown = ValueNotifier(true);
    addTearDown(shown.dispose);
    viewModel = rig.viewModel(address: ayahAt(2, 1), player: player);
    addTearDown(viewModel.dispose);
    await tester.pumpWidget(
      readerApp(viewModel, textScale: textScale, chrome: chrome, shown: shown),
    );
    await tester.pumpAndSettle();
  }

  Finder bar() => find.byType(ReaderPlayerBar);

  Future<void> playAyah(WidgetTester tester, int ayah) async {
    player.reach(recitationPlan(), ayahSegment(2, ayah));
    await tester.pumpAndSettle();
  }

  group('the player bar', () {
    testWidgets('shows what is recited while it plays or is paused', (
      tester,
    ) async {
      await pumpReader(tester);
      expect(bar(), findsNothing);
      expect(chrome.miniPlayerVisible, isTrue);

      await playAyah(tester, 2);
      final shownBar = tester.widget<ReaderPlayerBar>(bar());
      expect(shownBar.ayah, 2);
      expect(shownBar.reciter, 'Synthetic reciter');
      expect(shownBar.playing, isTrue);
      expect(shownBar.surah.verbatim, 'Synthetic long surah');

      await player.pause();
      await tester.pumpAndSettle();
      expect(bar(), findsOneWidget);
      expect(tester.widget<ReaderPlayerBar>(bar()).playing, isFalse);
    });

    testWidgets('follows the recited ayah', (tester) async {
      await pumpReader(tester);
      final plan = recitationPlan();
      player.reach(plan, ayahSegment(2, 2));
      await tester.pumpAndSettle();
      player.reach(plan, ayahSegment(2, 3), index: 1);
      await tester.pumpAndSettle();

      expect(tester.widget<ReaderPlayerBar>(bar()).ayah, 3);
    });

    testWidgets('is gone once playback stops', (tester) async {
      await pumpReader(tester);
      await playAyah(tester, 2);

      await player.stop();
      await tester.pumpAndSettle();

      expect(bar(), findsNothing);
      expect(chrome.miniPlayerVisible, isTrue);
    });

    testWidgets('is none for a recitation served as whole surahs', (
      tester,
    ) async {
      await pumpReader(tester);
      player.reach(recitationPlan(boundaries: false), surahSegment(2));
      await tester.pumpAndSettle();

      expect(bar(), findsNothing);
      expect(chrome.miniPlayerVisible, isTrue);
    });

    testWidgets('takes the mini player\'s place while the reader is shown', (
      tester,
    ) async {
      await pumpReader(tester);
      await playAyah(tester, 2);
      expect(chrome.miniPlayerVisible, isFalse);

      shown.value = false;
      await tester.pumpAndSettle();
      expect(chrome.miniPlayerVisible, isTrue);

      shown.value = true;
      await tester.pumpAndSettle();
      expect(chrome.miniPlayerVisible, isFalse);
    });

    testWidgets('its buttons act on the player', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpReader(tester);
      await playAyah(tester, 2);

      await tester.tap(find.bySemanticsLabel(_l10n.playerPause));
      await tester.pumpAndSettle();
      expect(player.commands, ['pause']);
      expect(find.bySemanticsLabel(_l10n.playerPlay), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(_l10n.playerPlay));
      await tester.pumpAndSettle();
      expect(player.commands, ['pause', 'resume']);

      await tester.tap(find.bySemanticsLabel(_l10n.playerNextAyah));
      await tester.pumpAndSettle();
      expect(player.commands.last, 'nextAyah');
      semantics.dispose();
    });

    testWidgets('is hidden with the rest of the interface, in both states', (
      tester,
    ) async {
      await pumpReader(tester);
      await playAyah(tester, 2);

      viewModel.setDistractionFree(true);
      await tester.pumpAndSettle();
      expect(bar(), findsNothing);
      expect(chrome.miniPlayerVisible, isFalse);

      viewModel.setDistractionFree(false);
      await tester.pumpAndSettle();
      expect(bar(), findsOneWidget);

      viewModel.setStandMode(true);
      await tester.pumpAndSettle();
      expect(bar(), findsNothing);
      expect(chrome.miniPlayerVisible, isFalse);
    });

    testWidgets('leaves room for the toolbar and the way back', (tester) async {
      await pumpReader(tester);
      await playAyah(tester, 2);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -150));
      await tester.pumpAndSettle();
      viewModel.select(ayahAt(2, 3));
      await tester.pumpAndSettle();

      final barRect = tester.getRect(bar());
      expect(find.byType(SmallButton), findsOneWidget);
      expect(find.byType(AyahToolbar), findsOneWidget);
      expect(
        tester.getRect(find.byType(SmallButton)).overlaps(barRect),
        isFalse,
      );
      expect(
        tester.getRect(find.byType(AyahToolbar)).overlaps(barRect),
        isFalse,
      );
    });

    testWidgets('lays out at 200% text without overflow', (tester) async {
      await pumpReader(tester, textScale: 2);
      await playAyah(tester, 2);

      expect(bar(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the highlight keeps pace with the player (SY-01, SY-04)', () {
    for (final speed in [PlaybackSpeed.all.first, PlaybackSpeed.all.last]) {
      testWidgets('is painted in the frame after an ayah event at '
          '${speed.factor}x', (tester) async {
        await pumpReader(tester);
        final plan = recitationPlan();
        player.reach(plan, ayahSegment(2, 2));
        await tester.pumpAndSettle();
        await player.setSpeed(speed);
        await tester.pump();

        List<int> filled() => [
          for (final marker in tester.widgetList<AyahMarker>(
            find.byType(AyahMarker),
          ))
            if (marker.playing) marker.number,
        ];
        expect(filled(), [2]);

        // One frame, with no time passing, between the event and the paint.
        player.reach(plan, ayahSegment(2, 3), index: 1);
        await tester.pump();
        expect(filled(), [3]);
      });
    }
  });
}
