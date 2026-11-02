import 'dart:convert';
import 'dart:io';

import '../integration_test/perf/perf_report.dart';
import '../integration_test/perf/perf_result.dart';

const _usage = '''
Collects the results of the performance harness from the logs of its runs and
holds them against the budgets of PRD §11.

  dart run test_driver/perf_summary.dart [--out report.json] LOG [LOG...]

A LOG is any text that holds the harness's PERF_RESULT lines: the output of
`flutter test`, or `adb logcat -d -s flutter`. Exit code 0 when no budget was
missed, 1 when one was, 2 when a log cannot be read or holds no result.''';

Future<void> main(List<String> arguments) async {
  exitCode = await collect(arguments, report: stdout, errors: stderr);
}

/// Runs the driver over [arguments], writing the report to [report] and
/// problems to [errors], and returns the exit code.
Future<int> collect(
  List<String> arguments, {
  required StringSink report,
  required StringSink errors,
}) async {
  String? out;
  final logs = <String>[];
  for (var i = 0; i < arguments.length; i++) {
    if (arguments[i] == '--out' && i + 1 < arguments.length) {
      out = arguments[++i];
    } else {
      logs.add(arguments[i]);
    }
  }
  if (logs.isEmpty) {
    errors.writeln(_usage);
    return 2;
  }
  final results = <PerfResult>[];
  try {
    for (final path in logs) {
      results.addAll(parsePerfLog(await File(path).readAsString()));
    }
  } on FileSystemException catch (error) {
    errors.writeln('Cannot read ${error.path}: ${error.message}');
    return 2;
  } on FormatException catch (error) {
    errors.writeln(error.message);
    return 2;
  }
  if (results.isEmpty) {
    errors.writeln('No $perfResultMarker line in ${logs.join(', ')}');
    return 2;
  }
  final outcomes = evaluate(results);
  report.writeln(formatReport(outcomes));
  if (out != null) {
    await File(out).writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(buildReport(results))}\n',
    );
  }
  return reportFails(outcomes) ? 1 : 0;
}
