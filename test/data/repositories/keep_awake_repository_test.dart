import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/keep_awake_repository.dart';
import 'package:holyquran/data/services/wakelock_service.dart';
import 'package:holyquran/utils/result.dart';

final class _FakeWakelock implements WakelockService {
  final calls = <bool>[];
  Exception? failure;
  Completer<void>? gate;

  @override
  Future<void> enable() => _call(true);

  @override
  Future<void> disable() => _call(false);

  Future<void> _call(bool on) async {
    calls.add(on);
    await gate?.future;
    if (failure case final failure?) throw failure;
  }
}

void main() {
  late _FakeWakelock wakelock;
  late LocalKeepAwakeRepository keepAwake;
  late int notified;

  setUp(() {
    wakelock = _FakeWakelock();
    keepAwake = LocalKeepAwakeRepository(wakelock);
    notified = 0;
    keepAwake.addListener(() => notified++);
  });

  for (final setting in [false, true]) {
    for (final reader in [false, true]) {
      for (final player in [false, true]) {
        final expected = setting && (reader || player);
        test('setting $setting, reader $reader, player $player: '
            'awake is $expected', () async {
          await keepAwake.setSettingOn(setting);
          await keepAwake.setReaderActive(reader);
          await keepAwake.setPlayerActive(player);

          expect(keepAwake.awake, expected);
          expect(wakelock.calls, expected ? [true] : isEmpty);
          expect(notified, expected ? 1 : 0);
        });
      }
    }
  }

  test('calls the wakelock only when the outcome changes', () async {
    await keepAwake.setSettingOn(true);
    await keepAwake.setReaderActive(true);
    await keepAwake.setPlayerActive(true);
    await keepAwake.setReaderActive(false);
    await keepAwake.setPlayerActive(false);
    await keepAwake.setReaderActive(true);
    await keepAwake.setSettingOn(false);
    await keepAwake.setSettingOn(false);

    expect(wakelock.calls, [true, false, true, false]);
    expect(keepAwake.awake, isFalse);
    expect(notified, 4);
  });

  test('a failing wakelock returns a Failure and is tried again', () async {
    wakelock.failure = const FormatException('synthetic failure');
    await keepAwake.setSettingOn(true);

    final result = await keepAwake.setReaderActive(true);

    expect((result as Failure).error, isA<FormatException>());
    expect(keepAwake.awake, isFalse);
    expect(notified, 0);

    wakelock.failure = null;
    expect(await keepAwake.setPlayerActive(true), isA<Ok<void>>());
    expect(keepAwake.awake, isTrue);
    expect(wakelock.calls, [true, true]);
  });

  test(
    'changes made while the wakelock answers end in the last state',
    () async {
      wakelock.gate = Completer();
      await keepAwake.setSettingOn(true);
      final on = keepAwake.setReaderActive(true);
      await pumpEventQueue();
      final off = keepAwake.setReaderActive(false);
      wakelock.gate!.complete();
      await Future.wait([on, off]);

      expect(wakelock.calls, [true, false]);
      expect(keepAwake.awake, isFalse);
    },
  );

  test('changes queued behind each other read the latest inputs', () async {
    await keepAwake.setSettingOn(true);
    final on = keepAwake.setReaderActive(true);
    final off = keepAwake.setReaderActive(false);
    await Future.wait([on, off]);

    expect(wakelock.calls, isEmpty);
    expect(keepAwake.awake, isFalse);
  });
}
