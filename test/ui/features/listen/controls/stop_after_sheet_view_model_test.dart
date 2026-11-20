import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/playback_rules.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/domain/models/stop_after.dart';
import 'package:holyquran/ui/features/listen/view_models/controls/stop_after_sheet_view_model.dart';

import '../../../../../testing/fakes/fake_player_repository.dart';
import 'controls_harness.dart';

void main() {
  final builder = syntheticBuilder(syntheticIndex());

  FakePlayerRepository playingSurah({
    RecitationUnit unit = RecitationUnit.ayah,
  }) => playerAt(
    planOf(builder, WholeSurah(1), recitation: syntheticRecitation(unit: unit)),
    segment: 0,
  );

  group('StopAfterSheetViewModel (AU-08)', () {
    test('offers ayah, page and surah for a plan with ayah boundaries', () {
      final vm = StopAfterSheetViewModel(player: playingSurah());
      expect(vm.options, [StopAfter.ayah, StopAfter.page, StopAfter.surah]);
    });

    test('offers only the surah for a surah file without timing', () async {
      final player = playingSurah(unit: RecitationUnit.surah);
      final vm = StopAfterSheetViewModel(player: player);
      expect(vm.options, [StopAfter.surah]);
      expect(await vm.choose(StopAfter.page), isFalse);
      expect(player.stopAfter, isNull);
    });

    test('sets each choice on the player and clears it', () async {
      final player = playingSurah();
      final vm = StopAfterSheetViewModel(player: player);
      for (final option in StopAfter.values) {
        expect(await vm.choose(option), isTrue);
        expect((player.stopAfter, vm.chosen), (option, option));
      }
      expect(await vm.choose(null), isTrue);
      expect(player.stopAfter, isNull);
    });

    test('sets nothing while nothing plays', () async {
      final idle = StopAfterSheetViewModel(player: playerAt(null));
      expect(idle.available, isFalse);
      expect(idle.options, isEmpty);
      expect(await idle.choose(StopAfter.ayah), isFalse);

      final player = playingSurah();
      player.state = player.state.copyWith(stopReason: () => StopReason.user);
      expect(
        await StopAfterSheetViewModel(player: player).choose(StopAfter.ayah),
        isFalse,
      );
      expect(player.stopAfter, isNull);
    });
  });
}
