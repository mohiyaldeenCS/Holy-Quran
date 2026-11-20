import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/playback_rules.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/domain/models/sleep_timer.dart';
import 'package:holyquran/ui/features/listen/view_models/controls/sleep_sheet_view_model.dart';

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

  group('SleepSheetViewModel (AU-07)', () {
    test('minutes stay within 5 to 120 and open at 5 with no timer', () {
      final vm = SleepSheetViewModel(player: playingSurah());
      expect((vm.minutes, vm.min, vm.max), (5, 5, 120));
      vm.setMinutes(4);
      expect(vm.minutes, 5);
      vm.setMinutes(121);
      expect(vm.minutes, 120);
    });

    test('opens at the minutes of the timer set', () {
      final player = playingSurah()..sleepTimer = SleepAfter(45);
      expect(SleepSheetViewModel(player: player).minutes, 45);
    });

    test('sets each timer on the player and cancels it', () async {
      final player = playingSurah();
      final vm = SleepSheetViewModel(player: player)..setMinutes(20);

      expect(await vm.startMinutes(), isTrue);
      expect(player.sleepTimer, SleepAfter(20));
      expect(vm.timer, SleepAfter(20));

      expect(await vm.endOfAyah(), isTrue);
      expect(player.sleepTimer, isA<SleepAtEndOfAyah>());

      expect(await vm.endOfSurah(), isTrue);
      expect(player.sleepTimer, isA<SleepAtEndOfSurah>());

      expect(await vm.cancel(), isTrue);
      expect(player.sleepTimer, isNull);
    });

    test('a surah file without timing offers no end of ayah', () async {
      final player = playingSurah(unit: RecitationUnit.surah);
      final vm = SleepSheetViewModel(player: player);
      expect(vm.offersEndOfAyah, isFalse);
      expect(await vm.endOfAyah(), isFalse);
      expect(player.sleepTimer, isNull);
      expect(await vm.endOfSurah(), isTrue);
      expect(player.sleepTimer, isA<SleepAtEndOfSurah>());
    });

    test('sets nothing while nothing plays', () async {
      final idle = SleepSheetViewModel(player: playerAt(null));
      expect(idle.available, isFalse);
      expect(await idle.startMinutes(), isFalse);

      final player = playingSurah();
      player.state = player.state.copyWith(stopReason: () => StopReason.user);
      final stopped = SleepSheetViewModel(player: player);
      expect(stopped.available, isFalse);
      expect(await stopped.endOfSurah(), isFalse);
      expect(player.sleepTimer, isNull);
    });

    test('tells its listeners of a new choice', () async {
      final vm = SleepSheetViewModel(player: playingSurah());
      var told = 0;
      vm.addListener(() => told++);
      vm.setMinutes(10);
      await vm.startMinutes();
      expect(told, 2);
    });

    test(
      'reports false when the run ended before the timer reached it',
      () async {
        final player = playingSurah()..runEnded = true;
        final vm = SleepSheetViewModel(player: player);
        expect(vm.available, isTrue);
        expect(await vm.endOfSurah(), isFalse);
        expect(player.sleepTimer, isNull);
      },
    );

    test('tells its listeners of the player until disposed', () {
      final player = playingSurah();
      final vm = SleepSheetViewModel(player: player);
      var told = 0;
      vm.addListener(() => told++);
      player.state = player.state.copyWith(
        stopReason: () => StopReason.endOfPlan,
      );
      expect((told, vm.available), (1, false));
      vm.dispose();
      player.state = player.state.copyWith(stopReason: () => null);
      expect(told, 1);
    });

    test('a timer set as the sheet closes completes without error', () async {
      final player = playingSurah();
      final vm = SleepSheetViewModel(player: player);
      final set = vm.endOfSurah();
      vm.dispose();
      expect(await set, isTrue);
      expect(player.sleepTimer, isA<SleepAtEndOfSurah>());
    });
  });
}
