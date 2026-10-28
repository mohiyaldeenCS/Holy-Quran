import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/playback_segment.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/domain/models/repeat_mode.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/widgets/stepper.dart';
import 'package:holyquran/ui/features/listen/view_models/controls/repeat_sheet_view_model.dart';

import '../../../../../testing/fakes/fake_player_repository.dart';
import 'controls_harness.dart';

void main() {
  final index = syntheticIndex();
  final builder = syntheticBuilder(index);

  RepeatSheetViewModel viewModel(FakePlayerRepository player) =>
      RepeatSheetViewModel(player: player, builder: builder);

  group('RepeatSheetViewModel', () {
    test('starts at the plan count and stays within 1 to 99', () {
      final vm = viewModel(
        playerAt(
          planOf(
            builder,
            WholeSurah(1),
            repeat: RepeatMode(RepeatUnit.ayah, 5),
          ),
        ),
      );
      expect(vm.count, 5);
      expect((vm.min, vm.max), (1, 99));
      vm.setCount(0);
      expect(vm.count, 1);
      vm.setCount(100);
      expect(vm.count, 99);
    });

    test('a count of n plays each ayah n times exactly', () async {
      final player = playerAt(
        planOf(
          builder,
          SingleAyah(at(1, 2)),
          repeat: RepeatMode(RepeatUnit.ayah, 2),
        ),
        ayah: at(1, 2),
      );
      final vm = viewModel(player)..setCount(7);
      expect(await vm.play(), isTrue);
      final plan = player.state.plan!;
      expect(plan.repeat, RepeatMode(RepeatUnit.ayah, 7));
      final heard = plan.segments.where((s) => s.kind == SegmentKind.ayah);
      expect(heard.map((s) => s.repeat), [1, 2, 3, 4, 5, 6, 7]);
      expect(heard.map((s) => s.address).toSet(), {at(1, 2)});
    });

    test('goes on from the ayah being heard', () async {
      final player = playerAt(
        planOf(builder, WholeSurah(1)),
        ayah: at(1, 3),
        segment: 2,
      );
      final vm = viewModel(player)..setCount(3);
      await vm.play();
      final plan = player.state.plan!;
      expect(plan.repeat, RepeatMode(RepeatUnit.range, 3));
      // The range is heard three times; the third ayah first starts at 2.
      expect(player.commands, ['play 2']);
      expect(plan.segments.length, 12);
    });

    test('keeps the recitation and the next-surah run', () async {
      final player = playerAt(
        planOf(builder, WholeSurah(2), continueToNextSurah: true),
        ayah: at(2, 1),
      );
      await (viewModel(player)..setCount(2)).play();
      final plan = player.state.plan!;
      expect(plan.continuesToNextSurah, isTrue);
      expect(plan.recitation, syntheticRecitation());
    });

    test('repeats only whole surahs from surah files without timing', () async {
      FakePlayerRepository untimed(RepeatUnit unit) => playerAt(
        planOf(
          builder,
          WholeSurah(1),
          recitation: syntheticRecitation(unit: RecitationUnit.surah),
          repeat: RepeatMode(unit, 1),
        ),
      );
      final byAyah = untimed(RepeatUnit.ayah);
      final vm = viewModel(byAyah)..setCount(2);
      expect(vm.available, isFalse);
      expect(await vm.play(), isFalse);
      expect(byAyah.commands, isEmpty);
      final bySurah = untimed(RepeatUnit.surah);
      expect(await (viewModel(bySurah)..setCount(2)).play(), isTrue);
      expect(bySurah.state.plan!.repeat, RepeatMode(RepeatUnit.surah, 2));
    });

    test('a second play while the first runs starts nothing', () async {
      final player = playerAt(planOf(builder, WholeSurah(1)), ayah: at(1, 1));
      final vm = viewModel(player);
      expect(await Future.wait([vm.play(), vm.play()]), [true, false]);
      expect(player.commands, ['play 0']);
      expect(await vm.play(), isTrue);
    });

    test('offers nothing before any plan', () async {
      final player = playerAt(null);
      final vm = viewModel(player);
      expect(vm.available, isFalse);
      expect(await vm.play(), isFalse);
      expect(player.commands, isEmpty);
    });
  });

  group('RepeatSheet', () {
    testWidgets('steps the count and plays it', (tester) async {
      final player = playerAt(planOf(builder, WholeSurah(1)), ayah: at(1, 1));
      final app = ControlsApp(player: player, builder: builder, index: index);
      await app.open(tester, Routes.repeatSheet);

      final increase = find.bySemanticsLabel(
        l10n.stepperIncrease(l10n.playerRepeat),
      );
      for (var tap = 0; tap < 2; tap++) {
        await tester.tap(increase);
        await tester.pump();
      }
      expect(tester.widget<Stepper>(find.byType(Stepper)).value, 3);
      await tester.tap(find.text(l10n.playerPlay));
      await tester.pumpAndSettle();
      expect(player.state.plan!.repeat.count, 3);
      expect(app.sheetOpen, isFalse);
    });

    testWidgets('announces the count as it changes', (tester) async {
      final app = ControlsApp(
        player: playerAt(planOf(builder, WholeSurah(1)), ayah: at(1, 1)),
        builder: builder,
        index: index,
      );
      await app.open(tester, Routes.repeatSheet);
      await tester.tap(
        find.bySemanticsLabel(l10n.stepperIncrease(l10n.playerRepeat)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.bySemanticsLabel('٢')),
        isSemantics(label: '٢', isLiveRegion: true),
      );
    });

    testWidgets('keeps the count when the route rebuilds', (tester) async {
      final app = ControlsApp(
        player: playerAt(planOf(builder, WholeSurah(1)), ayah: at(1, 1)),
        builder: builder,
        index: index,
      );
      await app.open(tester, Routes.repeatSheet);
      await tester.tap(
        find.bySemanticsLabel(l10n.stepperIncrease(l10n.playerRepeat)),
      );
      await tester.pump();
      app.router.refresh();
      await tester.pumpAndSettle();
      expect(tester.widget<Stepper>(find.byType(Stepper)).value, 2);
    });

    testWidgets('fits at 200% text', (tester) async {
      final app = ControlsApp(
        player: playerAt(planOf(builder, WholeSurah(1))),
        builder: builder,
        index: index,
      );
      await app.open(tester, Routes.repeatSheet, textScale: 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the stepper stops at 1 and at 99', (tester) async {
      final app = ControlsApp(
        player: playerAt(
          planOf(
            builder,
            WholeSurah(1),
            repeat: RepeatMode(RepeatUnit.range, 99),
          ),
        ),
        builder: builder,
        index: index,
      );
      await app.open(tester, Routes.repeatSheet);
      final stepper = tester.widget<Stepper>(find.byType(Stepper));
      expect((stepper.min, stepper.value, stepper.max), (1, 99, 99));
      expect(
        tester.getSemantics(
          find.bySemanticsLabel(l10n.stepperIncrease(l10n.playerRepeat)),
        ),
        isSemantics(isButton: true, isEnabled: false),
      );
    });
  });
}
