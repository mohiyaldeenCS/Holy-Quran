import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/ui/features/start/view_models/app_start_view_model.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

void main() {
  late List<FlutterErrorDetails> reported;
  late FlutterExceptionHandler? previous;

  setUp(() {
    reported = [];
    previous = FlutterError.onError;
    FlutterError.onError = reported.add;
  });
  tearDown(() => FlutterError.onError = previous);

  test('is pending until the dependencies are built, then ready', () async {
    final dependencies = Completer<List<SingleChildWidget>>();
    final viewModel = AppStartViewModel(dependencies.future);
    addTearDown(viewModel.dispose);

    expect(viewModel.state, isA<StartPending>());

    final providers = [Provider<int>.value(value: 1)];
    dependencies.complete(providers);
    await pumpEventQueue();

    expect(viewModel.state, isA<StartReady>());
    expect((viewModel.state as StartReady).providers, same(providers));
    expect(reported, isEmpty);
  });

  test('fails, and reports the error once, when a start step throws', () async {
    final dependencies = Completer<List<SingleChildWidget>>();
    final viewModel = AppStartViewModel(dependencies.future);
    addTearDown(viewModel.dispose);
    var notified = 0;
    viewModel.addListener(() => notified++);

    final error = StateError('synthetic');
    dependencies.completeError(error);
    await pumpEventQueue();

    expect(viewModel.state, isA<StartFailed>());
    expect(notified, 1);
    expect(reported.single.exception, same(error));
    expect(reported.single.library, 'start');
  });

  test(
    'a start that ends after the view model is disposed changes nothing',
    () async {
      final dependencies = Completer<List<SingleChildWidget>>();
      AppStartViewModel(dependencies.future).dispose();

      dependencies.completeError(StateError('synthetic'));
      await pumpEventQueue();

      expect(reported, hasLength(1));
    },
  );
}
