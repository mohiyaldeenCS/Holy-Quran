import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/utils/command.dart';
import 'package:holyquran/utils/result.dart';

void main() {
  group('Command0', () {
    test('starts idle, with no result', () {
      final command = Command0<int>(() async => const Ok(1));
      addTearDown(command.dispose);

      expect(command.running, isFalse);
      expect(command.result, isNull);
      expect(command.completed, isFalse);
      expect(command.error, isFalse);
    });

    test('is running until its action ends, then completed', () async {
      final gate = Completer<Result<int>>();
      final command = Command0<int>(() => gate.future);
      addTearDown(command.dispose);
      final seen = <bool>[];
      command.addListener(() => seen.add(command.running));

      final run = command.execute();
      expect(command.running, isTrue);
      expect(command.result, isNull);

      gate.complete(const Ok(7));
      await run;

      expect(command.running, isFalse);
      expect(command.completed, isTrue);
      expect(command.error, isFalse);
      expect((command.result! as Ok<int>).value, 7);
      expect(seen, [true, false]);
    });

    test('reports a failure as an error', () async {
      const failure = FormatException('synthetic');
      final command = Command0<int>(() async => const Failure(failure));
      addTearDown(command.dispose);

      await command.execute();

      expect(command.error, isTrue);
      expect(command.completed, isFalse);
      expect((command.result! as Failure<int>).error, same(failure));
    });

    test('ignores a run while one is in progress', () async {
      final gate = Completer<Result<int>>();
      var calls = 0;
      final command = Command0<int>(() {
        calls++;
        return gate.future;
      });
      addTearDown(command.dispose);

      final first = command.execute();
      final second = command.execute();
      gate.complete(const Ok(1));
      await Future.wait([first, second]);

      expect(calls, 1);
      expect(command.completed, isTrue);
    });

    test('runs again once the previous run has ended', () async {
      var calls = 0;
      final command = Command0<int>(() async => Ok(++calls));
      addTearDown(command.dispose);

      await command.execute();
      await command.execute();

      expect(calls, 2);
      expect((command.result! as Ok<int>).value, 2);
    });

    test('a new run clears the previous result while it runs', () async {
      final gates = [Completer<Result<int>>(), Completer<Result<int>>()];
      var call = 0;
      final command = Command0<int>(() => gates[call++].future);
      addTearDown(command.dispose);

      final first = command.execute();
      gates[0].complete(const Failure(FormatException('synthetic')));
      await first;
      expect(command.error, isTrue);

      final second = command.execute();
      expect(command.result, isNull);
      expect(command.error, isFalse);
      gates[1].complete(const Ok(2));
      await second;
      expect(command.completed, isTrue);
    });

    test('stops running when its action throws', () async {
      final command = Command0<int>(() async => throw StateError('synthetic'));
      addTearDown(command.dispose);

      await expectLater(command.execute(), throwsStateError);

      expect(command.running, isFalse);
      expect(command.result, isNull);
    });

    test('clearResult forgets the outcome and notifies', () async {
      final command = Command0<int>(() async => const Ok(1));
      addTearDown(command.dispose);
      await command.execute();
      var notified = 0;
      command.addListener(() => notified++);

      command.clearResult();

      expect(command.result, isNull);
      expect(command.completed, isFalse);
      expect(notified, 1);
    });
  });

  group('Command1', () {
    test('passes its argument to the action', () async {
      final command = Command1<String, int>((value) async => Ok('got $value'));
      addTearDown(command.dispose);

      await command.execute(3);

      expect((command.result! as Ok<String>).value, 'got 3');
    });

    test('ignores a run while one is in progress', () async {
      final gate = Completer<Result<int>>();
      final arguments = <int>[];
      final command = Command1<int, int>((value) {
        arguments.add(value);
        return gate.future;
      });
      addTearDown(command.dispose);

      final first = command.execute(1);
      expect(command.running, isTrue);
      final second = command.execute(2);
      gate.complete(const Ok(1));
      await Future.wait([first, second]);

      expect(arguments, [1]);
      expect(command.running, isFalse);
    });

    test('reports a failure as an error', () async {
      final command = Command1<int, int>(
        (_) async => const Failure(FormatException('synthetic')),
      );
      addTearDown(command.dispose);

      await command.execute(1);

      expect(command.error, isTrue);
      expect(command.running, isFalse);
    });
  });
}
