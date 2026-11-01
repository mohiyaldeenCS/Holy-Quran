import 'perf_result.dart';

/// The report of a set of runs: every check with its verdict, and the facts
/// about the devices the results came from.
Map<String, Object?> buildReport(List<PerfResult> results) => {
  'results': results.length,
  'devices': _devices(results),
  'outcomes': [for (final outcome in evaluate(results)) outcome.toJson()],
};

List<Map<String, Object?>> _devices(List<PerfResult> results) {
  const keys = [
    'os',
    'processors',
    'refreshRateHz',
    'devicePixelRatio',
    'liveFrames',
  ];
  final seen = <String>{};
  final devices = <Map<String, Object?>>[];
  for (final result in results) {
    final device = <String, Object?>{
      'platform': result.platform,
      'buildMode': result.buildMode,
      for (final key in keys) key: result.details[key],
    };
    if (seen.add(device.toString())) devices.add(device);
  }
  return devices;
}

/// The report as text for a person: one line per check.
String formatReport(List<CheckOutcome> outcomes) {
  final lines = <String>[];
  for (final outcome in outcomes) {
    final check = outcome.check;
    final measured = outcome.median == null
        ? 'not measured'
        : 'median ${_number(outcome.median!)} ${check.unit} over '
              '${outcome.runs} run${outcome.runs == 1 ? '' : 's'}, '
              'worst ${_number(outcome.worst!)}';
    lines.add(
      '${outcome.verdict.name.toUpperCase().padRight(12)} ${check.id} '
      '${check.scenario}.${check.metric}: $measured '
      '(${check.comparison.words} ${check.limit} ${check.unit})',
    );
  }
  return lines.join('\n');
}

String _number(num value) => value == value.roundToDouble()
    ? '${value.round()}'
    : value.toStringAsFixed(1);

/// Whether the report should fail a script: a check was missed. A check that
/// was not measured or only informative never passes for a pass, but does not
/// fail a run that measured something else.
bool reportFails(List<CheckOutcome> outcomes) =>
    outcomes.any((outcome) => outcome.verdict == Verdict.missed);
