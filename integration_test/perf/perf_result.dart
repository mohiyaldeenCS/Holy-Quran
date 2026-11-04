import 'dart:convert';

import 'perf_budget.dart';

/// The marker that starts a result line in a log, so that a run's output can
/// be mixed with any other text (`flutter test`, `logcat`).
const perfResultMarker = 'PERF_RESULT ';

/// The key of the integration test binding's report data that holds the
/// published results, one JSON object each.
const perfReportKey = 'perf';

/// What one run of one scenario measured, as JSON on one line.
final class PerfResult {
  const PerfResult({
    required this.scenario,
    required this.buildMode,
    required this.platform,
    required this.metrics,
    this.details = const {},
  });

  /// Reads the JSON [PerfResult.toJson] writes. Throws a [FormatException]
  /// for anything else.
  factory PerfResult.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw FormatException('A result is an object', json);
    }
    final metrics = json['metrics'];
    final scenario = json['scenario'];
    final buildMode = json['buildMode'];
    final platform = json['platform'];
    if (scenario is! String ||
        buildMode is! String ||
        platform is! String ||
        metrics is! Map<String, Object?>) {
      throw const FormatException(
        'A result needs its scenario, mode and metrics',
      );
    }
    final details = json['details'];
    return PerfResult(
      scenario: scenario,
      buildMode: buildMode,
      platform: platform,
      metrics: {
        for (final MapEntry(:key, :value) in metrics.entries)
          key: value is num
              ? value
              : throw FormatException('Metric $key is not a number', value),
      },
      details: details is Map<String, Object?> ? details : const {},
    );
  }

  final String scenario;

  /// `debug`, `profile` or `release`. Only the last two are held against the
  /// budgets: a debug build is much slower than the product.
  final String buildMode;

  /// `android`, `ios` or the host's name.
  final String platform;

  /// Named numbers, in the units their names end with (`Ms`, `PerSecond`).
  final Map<String, num> metrics;

  /// Facts about the run that are not budgets: the frame source, the refresh
  /// rate, the marks of a start.
  final Map<String, Object?> details;

  /// What names the run in every copy of its log line, so that a log read
  /// twice (the driver's and `adb logcat`'s) does not count it twice; null for
  /// a line written without one.
  String? get runId => switch (details['runId']) {
    final String id when id.isNotEmpty => id,
    _ => null,
  };

  /// The name the owner gave the phone (`--dart-define=PERF_DEVICE=`).
  String get deviceLabel => '${details['device'] ?? ''}'.trim();

  /// Whether the run stands for a reference device (PRD §11): a labelled
  /// phone, not a debug build, and not frames that were the cost of each pump
  /// of a widget test. A profile run on a computer is informative (D-157).
  bool get comparable =>
      (platform == 'android' || platform == 'ios') &&
      deviceLabel.isNotEmpty &&
      buildMode != 'debug' &&
      details['frameSource'] != 'pump-wall-clock';

  /// What the run's numbers are held apart by: two phones are two devices and
  /// each has to meet the budgets, even of the same platform and OS version.
  String get device =>
      deviceLabel.isEmpty ? '$platform ${details['os']}' : deviceLabel;

  /// Whether the run ended in an error before it measured. It is a miss of
  /// every check of its scenario.
  bool get failed => details['failed'] == true;

  /// How many measurements the run stands for: a sheet's median is of its
  /// repetitions, every other run is one.
  int get samples => failed
      ? 0
      : switch (details['repetitions']) {
          final num count => count.toInt(),
          _ => 1,
        };

  /// Whether the run is held against the budgets. The launch that built the
  /// pack is not: its caches are not those of a start that finds one.
  bool get counts => details['prepared'] != true;

  Map<String, Object?> toJson() => {
    'scenario': scenario,
    'buildMode': buildMode,
    'platform': platform,
    'metrics': metrics,
    'details': details,
  };

  /// The line the harness prints.
  String toLogLine() => '$perfResultMarker${jsonEncode(toJson())}';
}

/// The results found in [log], in order. Lines without the marker are
/// skipped; a marked line that is not a result throws a [FormatException]
/// naming it, since a lost run must not pass unnoticed.
List<PerfResult> parsePerfLog(String log) {
  final results = <PerfResult>[];
  for (final line in const LineSplitter().convert(log)) {
    final at = line.indexOf(perfResultMarker);
    if (at < 0) continue;
    final json = line.substring(at + perfResultMarker.length).trim();
    try {
      results.add(PerfResult.fromJson(jsonDecode(json)));
    } on FormatException catch (error) {
      throw FormatException('Unreadable result line: ${error.message}', json);
    }
  }
  return results;
}

/// [results] with each run once: a later line with the run id of an earlier
/// one is a copy of it. Lines without a run id are all kept.
List<PerfResult> withoutRepeats(Iterable<PerfResult> results) {
  final seen = <String>{};
  return [
    for (final result in results)
      if (result.runId == null || seen.add(result.runId!)) result,
  ];
}

/// How a check came out.
enum Verdict {
  /// Measured in a profile or release build, within the limit.
  met,

  /// Measured in a profile or release build, outside the limit.
  missed,

  /// Measured only in a debug build, on a computer, without a device label,
  /// or with a frame source that cannot stand for the device: the number is
  /// informative.
  informative,

  /// Within the limit, but from fewer runs than the protocol asks for.
  incomplete,

  /// No run of the scenario reported the metric.
  notMeasured,
}

/// A check with the runs that measured it.
final class CheckOutcome {
  const CheckOutcome({
    required this.check,
    required this.verdict,
    required this.runs,
    this.samples = 0,
    this.failures = 0,
    this.device,
    this.median,
    this.worst,
  });

  final PerfCheck check;

  /// The device of the runs ([PerfResult.device]); null when there are none.
  final String? device;
  final Verdict verdict;
  final int runs;

  /// The measurements behind the verdict ([PerfResult.samples]), against
  /// [PerfCheck.minSamples].
  final int samples;

  /// The runs of the scenario that ended in an error.
  final int failures;

  /// The median of the runs, which the verdict is given on.
  final num? median;

  /// The run furthest from the limit.
  final num? worst;

  Map<String, Object?> toJson() => {
    'device': device,
    'check': check.id,
    'scenario': check.scenario,
    'metric': check.metric,
    'limit': '${check.comparison.words} ${check.limit} ${check.unit}',
    'verdict': verdict.name,
    'runs': runs,
    'samples': samples,
    'neededSamples': check.minSamples,
    'failures': failures,
    'median': median,
    'worst': worst,
    'source': check.source,
    'measures': check.measures,
  };
}

/// Holds [results] against [checks], for each device that reported. The
/// verdict is given on the median of the runs of a scenario, so that one run
/// disturbed by the system does not decide, unless the check says every run
/// must hold; the worst run is reported beside it.
///
/// The runs of a device that cannot stand for it (a debug build, frames of a
/// widget test) are held apart from its comparable runs, under the device's
/// name followed by "(informative)", so that one stray debug run cannot turn
/// the device's miss into an informative figure.
List<CheckOutcome> evaluate(
  Iterable<PerfResult> results, {
  List<PerfCheck> checks = perfChecks,
}) {
  final comparable = {
    for (final result in results)
      if (result.comparable) result.device,
  };
  final groups = <String, List<PerfResult>>{};
  for (final result in results) {
    final apart = !result.comparable && comparable.contains(result.device);
    if (apart && !result.counts) continue;
    final group = apart ? '${result.device} (informative)' : result.device;
    groups.putIfAbsent(group, () => []).add(result);
  }
  if (groups.isEmpty) {
    return [for (final check in checks) _outcome(check, const [], null)];
  }
  return [
    for (final MapEntry(key: device, value: runs) in groups.entries)
      for (final check in checks) _outcome(check, runs, device),
  ];
}

CheckOutcome _outcome(
  PerfCheck check,
  Iterable<PerfResult> results,
  String? device,
) {
  final counted = [
    for (final result in results)
      if (result.counts && result.scenario == check.scenario) result,
  ];
  final failures = counted.where((run) => run.failed).length;
  final runs = [
    for (final run in counted)
      if (!run.failed && run.metrics.containsKey(check.metric)) run,
  ];
  if (runs.isEmpty && failures == 0) {
    return CheckOutcome(
      check: check,
      verdict: Verdict.notMeasured,
      runs: 0,
      device: device,
    );
  }
  final comparable = counted.every((run) => run.comparable);
  if (runs.isEmpty) {
    return CheckOutcome(
      check: check,
      verdict: comparable ? Verdict.missed : Verdict.informative,
      runs: 0,
      failures: failures,
      device: device,
    );
  }
  final values = [for (final run in runs) run.metrics[check.metric]!]..sort();
  final median = values.length.isOdd
      ? values[values.length ~/ 2]
      : (values[values.length ~/ 2 - 1] + values[values.length ~/ 2]) / 2;
  final worst = check.comparison == Comparison.atMost
      ? values.last
      : values.first;
  final samples = runs.fold<int>(0, (sum, run) => sum + run.samples);
  final holds = check.holds(check.everyRun ? worst : median);
  final verdict = !comparable
      ? Verdict.informative
      : failures > 0 || !holds
      ? Verdict.missed
      : samples < check.minSamples
      ? Verdict.incomplete
      : Verdict.met;
  return CheckOutcome(
    check: check,
    verdict: verdict,
    runs: runs.length,
    samples: samples,
    failures: failures,
    device: device,
    median: median,
    worst: worst,
  );
}
