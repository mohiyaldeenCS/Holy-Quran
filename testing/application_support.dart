import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _pathProvider = MethodChannel('plugins.flutter.io/path_provider');

/// Answers path_provider's application-support directory with a new
/// temporary folder until the test ends, then deletes the folder. A database
/// opened there must be closed first: Windows keeps an open file.
Directory useTemporaryApplicationSupport() {
  final directory = Directory.systemTemp.createTempSync('application_support');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    _pathProvider,
    (call) async =>
        call.method == 'getApplicationSupportDirectory' ? directory.path : null,
  );
  addTearDown(() {
    messenger.setMockMethodCallHandler(_pathProvider, null);
    directory.deleteSync(recursive: true);
  });
  return directory;
}

/// Pumps until [done] holds, letting real input and output (a database, a
/// file) finish between frames, which a widget test's fake clock does not.
Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 500 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(done(), isTrue, reason: 'not done after 500 rounds');
}
