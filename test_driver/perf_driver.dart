// The host side of `flutter drive --profile`: it receives what the harness
// published on the device and writes it where `perf_summary.dart` reads it.

import 'package:integration_test/integration_test_driver.dart';

import 'perf_collect.dart';

Future<void> main() => runPerfDriver(integrationDriver);
