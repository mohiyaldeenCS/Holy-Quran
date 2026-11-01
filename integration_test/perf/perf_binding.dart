import 'package:flutter_test/flutter_test.dart';

/// Initialises the binding the harness runs under. On a device the runner
/// needs `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` from
/// `package:integration_test` here, which the pubspec does not yet depend on
/// (see the report of P1-36); until then the plain test binding serves the
/// runs on a computer.
void initPerfBinding() => TestWidgetsFlutterBinding.ensureInitialized();
