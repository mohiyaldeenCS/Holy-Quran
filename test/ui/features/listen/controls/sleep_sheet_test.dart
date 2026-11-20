import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/domain/models/sleep_timer.dart';
import 'package:holyquran/domain/models/stop_after.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/widgets/radio_row.dart';
import 'package:holyquran/ui/core/widgets/stepper.dart';
import 'package:holyquran/ui/features/listen/views/controls/sleep_sheet.dart';

import '../../../../../testing/fakes/fake_player_repository.dart';
import 'controls_harness.dart';

void main() {
  final index = syntheticIndex();
  final builder = syntheticBuilder(index);

  FakePlayerRepository playingSurah({
    RecitationUnit unit = RecitationUnit.ayah,
  }) => playerAt(
    planOf(builder, WholeSurah(1), recitation: syntheticRecitation(unit: unit)),
    segment: 0,
  );

  Future<ControlsApp> open(
    WidgetTester tester,
    FakePlayerRepository player, {
    double textScale = 1,
  }) async {
    final app = ControlsApp(player: player, builder: builder, index: index);
    await app.open(tester, Routes.sleepSheet, textScale: textScale);
    return app;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  bool selected(WidgetTester tester, String text) => tester
      .widget<RadioRow>(
        find.ancestor(of: find.text(text), matching: find.byType(RadioRow)),
      )
      .selected;

  group('SleepSheet (AU-07, AU-08)', () {
    testWidgets('sets the minutes from the stepper and stays open', (
      tester,
    ) async {
      final player = playingSurah();
      final app = await open(tester, player);
      final stepper = tester.widget<Stepper>(find.byType(Stepper));
      expect((stepper.min, stepper.value, stepper.max), (5, 5, 120));
      expect(selected(tester, l10n.playerSleepOff), isTrue);

      await tester.tap(
        find.bySemanticsLabel(l10n.stepperIncrease(l10n.playerSleepTimer)),
      );
      await tester.pumpAndSettle();
      await tapText(tester, l10n.minutesCount(6, '٦'));
      expect(player.sleepTimer, SleepAfter(6));
      expect(selected(tester, l10n.minutesCount(6, '٦')), isTrue);
      expect(selected(tester, l10n.playerSleepOff), isFalse);
      expect(app.sheetOpen, isTrue);

      await tester.ensureVisible(find.byType(Stepper));
      await tester.tap(
        find.bySemanticsLabel(l10n.stepperIncrease(l10n.playerSleepTimer)),
      );
      await tester.pumpAndSettle();
      expect(player.sleepTimer, SleepAfter(6));
      expect(selected(tester, l10n.minutesCount(7, '٧')), isFalse);
    });

    testWidgets('reads each set of choices as a radio group named by it', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await open(tester, playingSurah());
      final groups = find.descendant(
        of: find.byType(SleepSheet),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.role == SemanticsRole.radioGroup,
        ),
      );
      expect(groups, findsNWidgets(2));
      for (final (index, (name, row)) in [
        (l10n.playerSleepTimer, l10n.playerSleepOff),
        (l10n.stopAfterTitle, l10n.stopAfterNone),
      ].indexed) {
        final group = tester.getSemantics(groups.at(index));
        expect((group.label, group.role), (name, SemanticsRole.radioGroup));
        expect(
          find.descendant(of: groups.at(index), matching: find.text(row)),
          findsOneWidget,
        );
      }
      handle.dispose();
    });

    testWidgets('sets the end of the ayah or surah, and turns it off', (
      tester,
    ) async {
      final player = playingSurah();
      await open(tester, player);
      await tapText(tester, l10n.playerEndOfAyah);
      expect(player.sleepTimer, const SleepAtEndOfAyah());
      await tapText(tester, l10n.playerEndOfSurah);
      expect(player.sleepTimer, const SleepAtEndOfSurah());
      await tapText(tester, l10n.playerSleepOff);
      expect(player.sleepTimer, isNull);
    });

    testWidgets('its stop-after section sets and clears a stop', (
      tester,
    ) async {
      final player = playingSurah();
      await open(tester, player);
      expect(find.text(l10n.stopAfterTitle), findsOneWidget);
      expect(find.bySemanticsLabel(l10n.stopAfterTitle), findsOneWidget);
      await tapText(tester, l10n.stopAfterPage);
      expect(player.stopAfter, StopAfter.page);
      expect(selected(tester, l10n.stopAfterPage), isTrue);
      await tapText(tester, l10n.stopAfterNone);
      expect(player.stopAfter, isNull);
    });

    testWidgets('a surah file without timing offers only its surah end', (
      tester,
    ) async {
      await open(tester, playingSurah(unit: RecitationUnit.surah));
      expect(find.text(l10n.playerEndOfAyah), findsNothing);
      expect(find.text(l10n.playerEndOfSurah), findsOneWidget);
      expect(find.text(l10n.stopAfterAyah), findsNothing);
      expect(find.text(l10n.stopAfterPage), findsNothing);
      expect(find.text(l10n.stopAfterSurah), findsOneWidget);
    });

    testWidgets('is empty before any plan', (tester) async {
      await open(tester, playerAt(null));
      expect(find.byType(Stepper), findsNothing);
      expect(find.byType(RadioRow), findsNothing);
    });

    testWidgets('fits at 200% text', (tester) async {
      await open(tester, playingSurah(), textScale: 2);
      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });
}
