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
    'device',
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

/// The report as text for a person: one line per check, and per device when
/// results came from more than one.
String formatReport(List<CheckOutcome> outcomes) {
  final several = {for (final outcome in outcomes) outcome.device}.length > 1;
  final lines = <String>[];
  for (final outcome in outcomes) {
    final check = outcome.check;
    final failed = outcome.failures == 0
        ? ''
        : '${outcome.failures} failed run${outcome.failures == 1 ? '' : 's'}';
    final measured = outcome.median == null
        ? (failed.isEmpty ? 'not measured' : failed)
        : 'median ${_number(outcome.median!)} ${check.unit} over '
              '${outcome.runs} run${outcome.runs == 1 ? '' : 's'}, '
              'worst ${_number(outcome.worst!)}'
              '${failed.isEmpty ? '' : ', $failed'}'
              '${outcome.verdict == Verdict.incomplete ? ', only '
                        '${outcome.samples} of the ${check.minSamples} '
                        'measurements the protocol asks for' : ''}';
    lines.add(
      '${outcome.verdict.name.toUpperCase().padRight(12)} '
      '${several ? '[${outcome.device}] ' : ''}${check.id} '
      '${check.scenario}.${check.metric}: $measured '
      '(${check.comparison.words} ${check.limit} ${check.unit})',
    );
  }
  return lines.join('\n');
}

String _number(num value) => value == value.roundToDouble()
    ? '${value.round()}'
    : value.toStringAsFixed(1);

/// Whether the report should fail a script: a check was missed, which a failed
/// run is. A check that was not measured, is incomplete or only informative
/// never passes for a pass, but does not fail a run that measured something
/// else.
bool reportFails(List<CheckOutcome> outcomes) =>
    outcomes.any((outcome) => outcome.verdict == Verdict.missed);
