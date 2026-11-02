import 'dart:io';

import '../integration_test/perf/perf_result.dart';

/// Turns the report data of a run (`flutter drive` hands it over when the
/// target ends) into the log lines [parsePerfLog] reads. Throws a
/// [FormatException] when the data holds no result.
List<String> resultLines(Map<String, Object?>? data) {
  final published = data?[perfReportKey];
  if (published is! List<Object?> || published.isEmpty) {
    throw const FormatException('The run reported no performance result');
  }
  return [for (final json in published) PerfResult.fromJson(json).toLogLine()];
}

/// Writes the results of a run to a new file of [folder], named after its
/// first scenario and the time, so that repeated runs (ten cold starts) add up
/// instead of replacing each other. Returns the file.
Future<File> saveResults(
  Map<String, Object?>? data, {
  required Directory folder,
  DateTime? now,
}) async {
  final lines = resultLines(data);
  final first = PerfResult.fromJson(
    (data![perfReportKey]! as List<Object?>)[0],
  );
  final stamp = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
  await folder.create(recursive: true);
  final file = File('${folder.path}/${first.scenario}-$stamp.log');
  await file.writeAsString('${lines.join('\n')}\n');
  return file;
}
