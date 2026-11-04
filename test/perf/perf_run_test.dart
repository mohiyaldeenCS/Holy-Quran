import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/perf/perf_result.dart';
import '../../integration_test/perf/perf_run.dart';

void main() {
  testWidgets('each result of a process has its own run id', (tester) async {
    final first = resultOf(tester, 'scroll', const {});
    final second = resultOf(tester, 'scroll', const {});
    final other = resultOf(tester, 'search', const {});

    final ids = [first.runId, second.runId, other.runId];
    expect(ids.whereType<String>(), hasLength(3));
    expect(ids.toSet(), hasLength(3));
    expect(first.runId, contains('scroll'));
    expect(first.runId!.split('-').first, second.runId!.split('-').first);
  });

  testWidgets('the run id is on the line the harness prints', (tester) async {
    final result = resultOf(tester, 'scroll', const {'frames': 1});

    final back = parsePerfLog(result.toLogLine()).single;

    expect(back.runId, result.runId);
  });

  testWidgets('the run id carries the device label', (tester) async {
    final result = resultOf(tester, 'scroll', const {});

    expect(result.runId, contains('-$perfDeviceLabel-scroll-'));
  });
}
