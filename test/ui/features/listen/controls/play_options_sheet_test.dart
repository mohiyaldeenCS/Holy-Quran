import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/domain/models/repeat_mode.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/features/listen/view_models/controls/play_options_view_model.dart';

import '../../../../../testing/fakes/fake_player_repository.dart';
import 'controls_harness.dart';

void main() {
  final index = syntheticIndex();
  final builder = syntheticBuilder(index);
  final allLabels = [
    l10n.playOnlyAyah,
    l10n.playToPageEnd,
    l10n.playToSurahEnd,
    l10n.playToJuzEnd,
    l10n.playUntilStopped,
  ];

  PlayOptionsViewModel viewModel(
    FakePlayerRepository player,
    QuranAddress address,
  ) => PlayOptionsViewModel(
    address: address,
    player: player,
    builder: builder,
    index: index,
  );

  group('PlayOptionsViewModel', () {
    test('offers the five ends of AU-03 in order', () {
      final vm = viewModel(playerAt(planOf(builder, WholeSurah(3))), at(1, 2));
      expect(vm.options, AyahToolEnd.values);
    });

    test('plays from the ayah to the end picked', () async {
      final player = playerAt(
        planOf(builder, WholeSurah(3), repeat: RepeatMode(RepeatUnit.ayah, 2)),
      );
      final vm = viewModel(player, at(1, 2));
      expect(await vm.play(AyahToolEnd.page), isTrue);
      final plan = player.state.plan!;
      final range = plan.range as FromAyahTool;
      expect((range.ayah, range.until), (at(1, 2), AyahToolEnd.page));
      expect(plan.repeat, RepeatMode(RepeatUnit.ayah, 2));
      expect(builder.ayatOf(range), [at(1, 2), at(1, 3)]);
    });

    test('a second play while the first runs starts nothing', () async {
      final player = playerAt(planOf(builder, WholeSurah(3)));
      final vm = viewModel(player, at(1, 2));
      final plays = [vm.play(AyahToolEnd.page), vm.play(AyahToolEnd.surah)];
      expect(await Future.wait(plays), [true, false]);
      expect(player.commands, ['play 0']);
      final range = player.state.plan!.range as FromAyahTool;
      expect(range.until, AyahToolEnd.page);
    });

    test('a word address plays from its ayah', () async {
      final player = playerAt(planOf(builder, WholeSurah(3)));
      final vm = viewModel(player, QuranAddress('hafs', 2, 1, 3));
      await vm.play(AyahToolEnd.ayah);
      expect((player.state.plan!.range as FromAyahTool).ayah, at(2, 1));
    });

    test('offers only whole surahs from surah files without timing', () {
      final vm = viewModel(
        playerAt(
          planOf(
            builder,
            WholeSurah(1),
            recitation: syntheticRecitation(unit: RecitationUnit.surah),
          ),
        ),
        at(1, 1),
      );
      expect(vm.options, [
        AyahToolEnd.surah,
        AyahToolEnd.juz,
        AyahToolEnd.untilStopped,
      ]);
    });

    test('offers nothing before any plan or outside the edition', () {
      expect(viewModel(playerAt(null), at(1, 1)).options, isEmpty);
      final player = playerAt(planOf(builder, WholeSurah(1)));
      expect(viewModel(player, at(1, 5)).options, isEmpty);
      expect(viewModel(player, at(4, 1)).options, isEmpty);
      expect(viewModel(player, QuranAddress('warsh', 1, 1)).options, isEmpty);
    });
  });

  group('PlayOptionsSheet', () {
    testWidgets('lists the options and plays the one tapped', (tester) async {
      final player = playerAt(planOf(builder, WholeSurah(3)));
      final app = ControlsApp(player: player, builder: builder, index: index);
      await app.open(tester, Routes.playOptionsSheet(at(1, 2)));

      expect(
        tester.widgetList<Button>(find.byType(Button)).map((b) => b.label),
        allLabels,
      );
      expect(
        find.text(l10n.surahAyahReference('Synthetic surah 1', '٢')),
        findsOneWidget,
      );
      await tester.tap(find.text(l10n.playToSurahEnd));
      await tester.pumpAndSettle();
      expect(
        (player.state.plan!.range as FromAyahTool).until,
        AyahToolEnd.surah,
      );
      expect(app.sheetOpen, isFalse);
    });

    testWidgets('shows nothing before any plan', (tester) async {
      final app = ControlsApp(
        player: playerAt(null),
        builder: builder,
        index: index,
      );
      await app.open(tester, Routes.playOptionsSheet(at(1, 2)));
      expect(find.byType(Button), findsNothing);
    });

    testWidgets('fits at 200% text', (tester) async {
      final app = ControlsApp(
        player: playerAt(planOf(builder, WholeSurah(3))),
        builder: builder,
        index: index,
      );
      await app.open(tester, Routes.playOptionsSheet(at(1, 2)), textScale: 2);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text(l10n.playUntilStopped), 100);
      expect(find.text(l10n.playUntilStopped), findsOneWidget);
    });
  });
}
