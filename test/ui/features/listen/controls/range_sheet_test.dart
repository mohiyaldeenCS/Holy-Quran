import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/domain/models/repeat_mode.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/mode_chips.dart';
import 'package:holyquran/ui/core/widgets/stepper.dart';
import 'package:holyquran/ui/features/listen/view_models/controls/range_sheet_view_model.dart';

import '../../../../../testing/fakes/fake_player_repository.dart';
import 'controls_harness.dart';

void main() {
  final index = syntheticIndex();
  final builder = syntheticBuilder(index);

  RangeSheetViewModel viewModel(FakePlayerRepository player) =>
      RangeSheetViewModel(player: player, builder: builder, index: index);

  group('RangeSheetViewModel', () {
    test('starts where playback is, in each kind of range', () {
      final vm = viewModel(
        playerAt(planOf(builder, WholeSurah(1)), ayah: at(1, 4)),
      );
      expect(vm.kinds, RangeKind.values);
      final values = {
        for (final kind in RangeKind.values) kind: (vm..selectKind(kind)).value,
      };
      expect(values, {
        RangeKind.ayah: 4,
        RangeKind.page: 2,
        RangeKind.juz: 1,
        RangeKind.hizb: 2,
        RangeKind.surah: 1,
      });
    });

    test('keeps each number within its bounds', () {
      final vm = viewModel(
        playerAt(planOf(builder, WholeSurah(1)), ayah: at(1, 1)),
      );
      final bounds = {
        for (final kind in RangeKind.values)
          kind: () {
            vm
              ..selectKind(kind)
              ..setValue(0);
            final low = vm.value;
            vm.setValue(1000);
            return (vm.min, low, vm.max, vm.value);
          }(),
      };
      expect(bounds, {
        RangeKind.ayah: (1, 1, 4, 4),
        RangeKind.page: (1, 1, 4, 4),
        RangeKind.juz: (1, 1, 2, 2),
        RangeKind.hizb: (1, 1, 4, 4),
        RangeKind.surah: (1, 1, 3, 3),
      });
    });

    test('plays the range picked, keeping repeat and silence', () async {
      final player = playerAt(
        planOf(
          builder,
          WholeSurah(2),
          repeat: RepeatMode(RepeatUnit.ayah, 3),
          silence: const Duration(seconds: 4),
        ),
        ayah: at(2, 2),
      );
      final vm = viewModel(player)..selectKind(RangeKind.hizb);
      expect(await vm.play(), isTrue);
      final plan = player.state.plan!;
      expect((plan.range as WholeHizb).hizb, 3);
      expect(plan.repeat, RepeatMode(RepeatUnit.ayah, 3));
      expect(plan.silence, const Duration(seconds: 4));
      expect(player.commands, ['play 0']);
    });

    test('builds an ayah, a page, a juz and a hizb', () {
      final vm = viewModel(
        playerAt(planOf(builder, WholeSurah(1)), ayah: at(1, 3)),
      );
      expect((vm.range as SingleAyah).ayah, at(1, 3));
      vm.selectKind(RangeKind.page);
      expect(vm.range, isA<PageSpan>().having((r) => r.first, 'first', 1));
      vm.selectKind(RangeKind.juz);
      expect(vm.range, isA<WholeJuz>().having((r) => r.juz, 'juz', 1));
      vm.selectKind(RangeKind.hizb);
      expect(vm.range, isA<WholeHizb>().having((r) => r.hizb, 'hizb', 2));
      vm.selectKind(RangeKind.surah);
      expect(vm.range, isA<WholeSurah>().having((r) => r.surah, 'surah', 1));
    });

    test('a new range does not continue into the next surah', () async {
      final player = playerAt(
        planOf(builder, WholeSurah(1), continueToNextSurah: true),
        ayah: at(1, 2),
      );
      await (viewModel(player)..selectKind(RangeKind.surah)).play();
      expect(player.state.plan!.continuesToNextSurah, isFalse);
      expect(player.state.plan!.recitation, syntheticRecitation());
    });

    test('plays with the plan playing at play time, not at opening', () async {
      final player = playerAt(planOf(builder, WholeSurah(1)), ayah: at(1, 1));
      final vm = viewModel(player);
      final other = syntheticRecitation(unit: RecitationUnit.surah);
      player.state = player.state.copyWith(
        plan: planOf(builder, WholeSurah(3), recitation: other),
      );
      // Hizb 1 is part of surah 1, which the new recitation cannot play.
      vm.selectKind(RangeKind.hizb);
      expect(await vm.play(), isFalse);
      expect(player.commands, isEmpty);
    });

    test('offers whole surahs only from surah files without timing', () {
      final vm = viewModel(
        playerAt(
          planOf(
            builder,
            WholeSurah(1),
            recitation: syntheticRecitation(unit: RecitationUnit.surah),
          ),
          ayah: at(1, 1),
        ),
      );
      expect(vm.kinds, [RangeKind.surah]);
      expect(vm.kind, RangeKind.surah);
    });

    test('offers nothing before any plan', () async {
      final player = playerAt(null);
      final vm = viewModel(player);
      expect(vm.kinds, isEmpty);
      expect(await vm.play(), isFalse);
      expect(player.commands, isEmpty);
    });
  });

  group('RangeSheet', () {
    testWidgets('picks a page with the stepper and plays it', (tester) async {
      final player = playerAt(planOf(builder, WholeSurah(1)), ayah: at(1, 1));
      final app = ControlsApp(player: player, builder: builder, index: index);
      await app.open(tester, Routes.rangeSheet);

      expect(find.byType(ModeChips), findsOneWidget);
      await tester.tap(find.text(l10n.goToPage));
      await tester.pumpAndSettle();
      expect(tester.widget<Stepper>(find.byType(Stepper)).label, l10n.goToPage);
      await tester.tap(
        find.bySemanticsLabel(l10n.stepperIncrease(l10n.goToPage)),
      );
      await tester.pumpAndSettle();
      expect(find.text('٢'), findsOneWidget);

      await tester.tap(find.text(l10n.playerPlay));
      await tester.pumpAndSettle();
      expect((player.state.plan!.range as PageSpan).first, 2);
      expect(app.sheetOpen, isFalse);
    });

    testWidgets('disables the stepper button at each bound', (tester) async {
      final app = ControlsApp(
        player: playerAt(planOf(builder, WholeSurah(1)), ayah: at(1, 1)),
        builder: builder,
        index: index,
      );
      await app.open(tester, Routes.rangeSheet);
      await tester.tap(find.text(l10n.goToJuz));
      await tester.pumpAndSettle();

      Matcher enabled({required bool value}) =>
          isSemantics(isButton: true, isEnabled: value);
      SemanticsNode node(String label) =>
          tester.getSemantics(find.bySemanticsLabel(label));
      final decrease = l10n.stepperDecrease(l10n.goToJuz);
      final increase = l10n.stepperIncrease(l10n.goToJuz);
      expect(node(decrease), enabled(value: false));
      await tester.tap(find.bySemanticsLabel(increase));
      await tester.pumpAndSettle();
      expect(node(increase), enabled(value: false));
      expect(node(decrease), enabled(value: true));
    });

    testWidgets('shows no chips when only surahs can play', (tester) async {
      final app = ControlsApp(
        player: playerAt(
          planOf(
            builder,
            WholeSurah(2),
            recitation: syntheticRecitation(unit: RecitationUnit.surah),
          ),
        ),
        builder: builder,
        index: index,
      );
      await app.open(tester, Routes.rangeSheet);
      expect(find.byType(ModeChips), findsNothing);
      expect(find.text(l10n.surahTitle('Synthetic surah 2')), findsOneWidget);
      expect(
        tester.widget<Stepper>(find.byType(Stepper)).label,
        l10n.goToSurah,
      );
    });

    testWidgets('shows nothing to pick before any plan', (tester) async {
      final app = ControlsApp(
        player: playerAt(null),
        builder: builder,
        index: index,
      );
      await app.open(tester, Routes.rangeSheet);
      expect(find.byType(Stepper), findsNothing);
      expect(find.byType(Button), findsNothing);
    });

    testWidgets('fits at 200% text', (tester) async {
      final app = ControlsApp(
        player: playerAt(planOf(builder, WholeSurah(1)), ayah: at(1, 1)),
        builder: builder,
        index: index,
      );
      await app.open(tester, Routes.rangeSheet, textScale: 2);
      expect(tester.takeException(), isNull);
      expect(find.byType(Stepper), findsOneWidget);
    });
  });
}
