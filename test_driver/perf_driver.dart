// The host side of `flutter drive --profile`: it receives what the harness
// published on the device and writes it where `perf_summary.dart` reads it.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

import 'perf_collect.dart';

// A run that fails part-way still writes the runs that finished and the
// failure it published, which the summary counts as a miss.
Future<void> main() => integrationDriver(
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    final written = await writeRunResults(
      data,
      folder: Directory('build/perf'),
      output: stdout,
    );
    if (!written) exit(1);
  },
);
