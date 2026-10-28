@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/player_state.dart';
import 'package:holyquran/domain/models/repeat_mode.dart';
import 'package:holyquran/ui/features/listen/view_models/controls/play_options_view_model.dart';
import 'package:holyquran/ui/features/listen/view_models/controls/queue_sheet_view_model.dart';
import 'package:holyquran/ui/features/listen/view_models/controls/range_sheet_view_model.dart';
import 'package:holyquran/ui/features/listen/view_models/controls/repeat_sheet_view_model.dart';
import 'package:holyquran/ui/features/listen/view_models/controls/silence_sheet_view_model.dart';
import 'package:holyquran/ui/features/listen/views/controls/play_options_sheet.dart';
import 'package:holyquran/ui/features/listen/views/controls/queue_sheet.dart';
import 'package:holyquran/ui/features/listen/views/controls/range_sheet.dart';
import 'package:holyquran/ui/features/listen/views/controls/repeat_sheet.dart';
import 'package:holyquran/ui/features/listen/views/controls/silence_sheet.dart';

import '../../../../../testing/fakes/fake_player_repository.dart';
import 'controls_harness.dart';

void main() {
  final index = syntheticIndex();
  final builder = syntheticBuilder(index);
  final player = playerAt(
    planOf(
      builder,
      WholeSurah(1),
      repeat: RepeatMode(RepeatUnit.ayah, 3),
      silence: const Duration(seconds: 2),
    ),
    segment: 3,
  );

  testWidgets('range sheet', (tester) async {
    final vm = RangeSheetViewModel(
      player: player,
      builder: builder,
      index: index,
    );
    await expectSheetGoldens(
      tester,
      'range_sheet',
      (context) => RangeSheet(viewModel: vm),
    );
  });

  testWidgets('play options sheet', (tester) async {
    final vm = PlayOptionsViewModel(
      address: at(1, 2),
      player: player,
      builder: builder,
      index: index,
    );
    await expectSheetGoldens(
      tester,
      'play_options_sheet',
      (context) => PlayOptionsSheet(viewModel: vm),
    );
  });

  testWidgets('repeat sheet', (tester) async {
    final vm = RepeatSheetViewModel(player: player, builder: builder);
    await expectSheetGoldens(
      tester,
      'repeat_sheet',
      (context) => RepeatSheet(viewModel: vm),
    );
  });

  testWidgets('silence sheet', (tester) async {
    final vm = SilenceSheetViewModel(player: player, builder: builder);
    await expectSheetGoldens(
      tester,
      'silence_sheet',
      (context) => SilenceSheet(viewModel: vm),
    );
  });

  testWidgets('queue sheet', (tester) async {
    final vm = QueueSheetViewModel(
      player: FakePlayerRepository(
        state: PlayerState(
          queue: [
            planOf(builder, WholeSurah(2)),
            planOf(builder, FromAyahTool(at(1, 3), AyahToolEnd.surah)),
            planOf(builder, WholeHizb(2)),
          ],
        ),
      ),
      index: index,
    );
    addTearDown(vm.dispose);
    await expectSheetGoldens(
      tester,
      'queue_sheet',
      (context) => QueueSheet(viewModel: vm),
    );
  });
}
