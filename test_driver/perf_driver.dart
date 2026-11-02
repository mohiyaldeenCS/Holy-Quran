// The host side of `flutter drive --profile`: it receives what the harness
// published on the device and writes it where `perf_summary.dart` reads it.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

import 'perf_collect.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final file = await saveResults(data, folder: Directory('build/perf'));
    print('Performance results written to ${file.path}');
  },
);
