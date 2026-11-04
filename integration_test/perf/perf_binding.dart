import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';

import 'perf_result.dart';

IntegrationTestWidgetsFlutterBinding? _binding;
final _published = <PerfResult>[];

/// What the run has published so far.
List<PerfResult> get publishedResults => List.unmodifiable(_published);

/// Initialises the binding the harness runs under. Its frames are drawn at the
/// display's pace, which the frame timings of the scroll need.
void initPerfBinding() {
  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
}

/// Prints [result] as a line of the run's log and hands it to the host driver
/// (`test_driver/perf_driver.dart`) through the binding's report data.
void publish(PerfResult result) {
  debugPrint(result.toLogLine());
  _published.add(result);
  _binding?.reportData = {
    perfReportKey: [for (final published in _published) published.toJson()],
  };
}
