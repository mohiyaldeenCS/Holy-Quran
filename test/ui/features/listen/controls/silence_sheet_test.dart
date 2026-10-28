import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/playback_segment.dart';
import 'package:holyquran/domain/models/player_state.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/domain/models/repeat_mode.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/widgets/stepper.dart';
import 'package:holyquran/ui/features/listen/view_models/controls/silence_sheet_view_model.dart';

import '../../../../../testing/fakes/fake_player_repository.dart';
import 'controls_harness.dart';

void main() {
  final index = syntheticIndex();
  final builder = syntheticBuilder(index);

  SilenceSheetViewModel viewModel(FakePlayerRepository player) =>
      SilenceSheetViewModel(player: player, builder: builder);

  group('SilenceSheetViewModel', () {
    test('starts at the plan silence and stays within 0 to 30', () {
      final vm = viewModel(
        playerAt(
          planOf(builder, WholeSurah(1), silence: const Duration(seconds: 6)),
        ),
      );
      expect(vm.seconds, 6);
      expect((vm.min, vm.max), (0, 30));
      vm.setSeconds(-1);
      expect(vm.seconds, 0);
      vm.setSeconds(31);
      expect(vm.seconds, 30);
    });

    test('plays the plan with the silence, from the same segment', () async {
      final player = playerAt(
        planOf(builder, WholeSurah(1), repeat: RepeatMode(RepeatUnit.ayah, 2)),
        segment: 3,
      );
      final vm = viewModel(player)..setSeconds(12);
      expect(await vm.play(), isTrue);
      final plan = player.state.plan!;
      expect(plan.silence, const Duration(seconds: 12));
      expect(plan.repeat, RepeatMode(RepeatUnit.ayah, 2));
      final silences = plan.segments
          .where((s) => s.kind == SegmentKind.ayah)
          .map((s) => s.silenceAfter);
      expect(silences.take(7).toSet(), {const Duration(seconds: 12)});
      expect(silences.last, Duration.zero);
      expect(player.commands, ['play 3']);
    });

    test('rebuilds the plan playing when it plays', () async {
      final player = playerAt(planOf(builder, WholeSurah(1)), segment: 3);
      final vm = viewModel(player)..setSeconds(5);
      final next = planOf(builder, WholeSurah(3));
      player.state = PlayerState(plan: next, segmentIndex: 0);
      await vm.play();
      expect((player.state.plan!.range as WholeSurah).surah, 3);
      expect(player.commands, ['play 0']);
    });

    test('a second play while the first runs starts nothing', () async {
      final player = playerAt(planOf(builder, WholeSurah(1)), segment: 3);
      final vm = viewModel(player)..setSeconds(4);
      expect(await Future.wait([vm.play(), vm.play()]), [true, false]);
      expect(player.commands, ['play 3']);
    });

    test('a play the player refuses reports false', () async {
      final player = playerAt(planOf(builder, WholeSurah(1)), segment: 3)
        ..playFailure = Exception('refused');
      final vm = viewModel(player)..setSeconds(4);
      expect(await vm.play(), isFalse);
      expect(player.commands, isEmpty);
      expect(await vm.play(), isTrue);
    });

    test('offers nothing for whole surahs without timing', () async {
      final player = playerAt(
        planOf(
          builder,
          WholeSurah(1),
          recitation: syntheticRecitation(unit: RecitationUnit.surah),
        ),
      );
      final vm = viewModel(player)..setSeconds(5);
      expect(vm.available, isFalse);
      expect(await vm.play(), isFalse);
      expect(player.commands, isEmpty);
    });

    test('offers nothing before any plan', () async {
      final player = playerAt(null);
      final vm = viewModel(player);
      expect(vm.available, isFalse);
      expect(await vm.play(), isFalse);
      expect(player.commands, isEmpty);
    });
  });

  group('SilenceSheet', () {
    testWidgets('names the silence once, with its seconds as the value', (
      tester,
    ) async {
      final player = playerAt(planOf(builder, WholeSurah(1)), segment: 0);
      final app = ControlsApp(player: player, builder: builder, index: index);
      await app.open(tester, Routes.silenceSheet);

      String seconds(String digits) =>
          l10n.stepperValueWithUnit(digits, l10n.playerSecondsUnit);
      expect(find.text(l10n.playerSilenceBetweenAyat), findsOneWidget);
      expect(find.text(seconds('٠')), findsOneWidget);
      expect(find.text(l10n.playerSilenceSeconds('٠')), findsNothing);
      await tester.tap(
        find.bySemanticsLabel(
          l10n.stepperIncrease(l10n.playerSilenceBetweenAyat),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.playerSilenceBetweenAyat), findsOneWidget);
      expect(find.text(seconds('١')), findsOneWidget);
      await tester.tap(find.text(l10n.playerPlay));
      await tester.pumpAndSettle();
      expect(player.state.plan!.silence, const Duration(seconds: 1));
      expect(app.sheetOpen, isFalse);
    });

    testWidgets('the stepper stops at 0 and at 30', (tester) async {
      final app = ControlsApp(
        player: playerAt(
          planOf(builder, WholeSurah(1), silence: const Duration(seconds: 30)),
        ),
        builder: builder,
        index: index,
      );
      await app.open(tester, Routes.silenceSheet);
      final stepper = tester.widget<Stepper>(find.byType(Stepper));
      expect((stepper.min, stepper.value, stepper.max), (0, 30, 30));
    });

    testWidgets('fits at 200% text', (tester) async {
      final app = ControlsApp(
        player: playerAt(planOf(builder, WholeSurah(1))),
        builder: builder,
        index: index,
      );
      await app.open(tester, Routes.silenceSheet, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });
}
