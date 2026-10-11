import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../testing/fonts.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadAppFonts();
  await testMain();
}
