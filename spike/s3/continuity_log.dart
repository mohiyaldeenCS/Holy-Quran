import 'dart:async';
import 'dart:convert';
import 'dart:io';

const continuitySampleInterval = Duration(seconds: 5);
const nf09Target = Duration(minutes: 60);
const _listedIssues = 10;

class ContinuitySample {
  const ContinuitySample({
    required this.wall,
    required this.elapsed,
    required this.position,
    required this.playing,
    required this.state,
    required this.track,
  });

  factory ContinuitySample.fromJson(Map<String, Object?> json) =>
      ContinuitySample(
        wall: DateTime.fromMillisecondsSinceEpoch(
          json['wall_ms']! as int,
          isUtc: true,
        ),
        elapsed: Duration(milliseconds: json['elapsed_ms']! as int),
        position: Duration(milliseconds: json['position_ms']! as int),
        playing: json['playing']! as bool,
        state: json['state']! as String,
        track: json['track']! as int,
      );

  final DateTime wall;

  /// Monotonic time since the run started. It does not advance while the
  /// device is suspended, so a wall clock that runs ahead of it while playing
  /// means suspension or a manual clock change.
  final Duration elapsed;
  final Duration position;
  final bool playing;

  /// just_audio's processing state name: idle, loading, buffering, ready,
  /// completed.
  final String state;
  final int track;

  bool get advancing => playing && state != 'completed' && state != 'idle';

  Map<String, Object> toJson() => {
    'kind': 'sample',
    'wall_ms': wall.millisecondsSinceEpoch,
    'elapsed_ms': elapsed.inMilliseconds,
    'position_ms': position.inMilliseconds,
    'playing': playing,
    'state': state,
    'track': track,
  };
}

class ContinuityEvent {
  const ContinuityEvent({
    required this.wall,
    required this.elapsed,
    required this.name,
  });

  factory ContinuityEvent.fromJson(Map<String, Object?> json) =>
      ContinuityEvent(
        wall: DateTime.fromMillisecondsSinceEpoch(
          json['wall_ms']! as int,
          isUtc: true,
        ),
        elapsed: Duration(milliseconds: json['elapsed_ms']! as int),
        name: json['name']! as String,
      );

  final DateTime wall;
  final Duration elapsed;
  final String name;

  Map<String, Object> toJson() => {
    'kind': 'event',
    'wall_ms': wall.millisecondsSinceEpoch,
    'elapsed_ms': elapsed.inMilliseconds,
    'name': name,
  };
}

({List<ContinuitySample> samples, List<ContinuityEvent> events})
parseContinuityLog(String jsonl) {
  final samples = <ContinuitySample>[];
  final events = <ContinuityEvent>[];
  for (final line in const LineSplitter().convert(jsonl)) {
    if (line.isEmpty) continue;
    final json = jsonDecode(line) as Map<String, Object?>;
    switch (json['kind']) {
      case 'sample':
        samples.add(ContinuitySample.fromJson(json));
      case 'event':
        events.add(ContinuityEvent.fromJson(json));
      default:
        throw FormatException('Unknown log line kind', line);
    }
  }
  return (samples: samples, events: events);
}

String eventTally(List<ContinuityEvent> events) {
  final counts = <String, int>{};
  for (final event in events) {
    counts[event.name] = (counts[event.name] ?? 0) + 1;
  }
  final names = counts.keys.toList()..sort();
  return [for (final name in names) 'event $name ${counts[name]}'].join('\n');
}

class ContinuityIssue {
  const ContinuityIssue({required this.at, required this.amount});

  /// Offset of the interval's first sample from the first sample of the run.
  final Duration at;
  final Duration amount;
}

class ContinuityReport {
  const ContinuityReport({
    required this.samples,
    required this.span,
    required this.playing,
    required this.longestRun,
    required this.longestRunStart,
    required this.gaps,
    required this.stalls,
    required this.positionJumps,
    required this.clockJumps,
    required this.trackChanges,
    required this.discontinuousTrackChanges,
  });

  final int samples;
  final Duration span;
  final Duration playing;
  final Duration longestRun;
  final Duration longestRunStart;

  /// Intervals in which the logger itself ran late; playback may still have
  /// been continuous.
  final List<ContinuityIssue> gaps;

  /// Playing intervals in which the position advanced less than time did.
  final List<ContinuityIssue> stalls;

  /// Playing intervals in which the position advanced more than time did.
  final List<ContinuityIssue> positionJumps;

  /// Intervals in which the wall clock and the monotonic clock disagree.
  final List<ContinuityIssue> clockJumps;
  final int trackChanges;
  final int discontinuousTrackChanges;

  bool get meetsTarget => longestRun >= nf09Target;

  String get summary {
    final lines = <String>[
      'samples $samples',
      'span_s ${_s(span)}',
      'playing_s ${_s(playing)}',
      'longest_run_s ${_s(longestRun)}',
      'longest_run_start_s ${_s(longestRunStart)}',
      'target_s ${_s(nf09Target)}',
      'meets_target ${meetsTarget ? 1 : 0}',
      'track_changes $trackChanges discontinuous $discontinuousTrackChanges',
      ..._issues('gap', gaps),
      ..._issues('stall', stalls),
      ..._issues('position_jump', positionJumps),
      ..._issues('clock_jump', clockJumps),
    ];
    return lines.join('\n');
  }

  static List<String> _issues(String name, List<ContinuityIssue> issues) {
    var largest = Duration.zero;
    for (final issue in issues) {
      if (issue.amount.abs() > largest.abs()) largest = issue.amount;
    }
    return [
      '${name}s ${issues.length} largest_s ${_s(largest)}',
      for (final issue in issues.take(_listedIssues))
        '${name}_at_s ${_s(issue.at)} amount_s ${_s(issue.amount)}',
    ];
  }

  static String _s(Duration d) => (d.inMilliseconds / 1000).toStringAsFixed(1);
}

/// Reads a run of samples taken every [interval] from a playlist whose tracks
/// are all [trackLength] long. A run is a sequence of playing intervals in
/// which the position kept pace with the monotonic clock within [tolerance],
/// across track changes, and the wall clock did not jump.
ContinuityReport analyse(
  List<ContinuitySample> samples, {
  required Duration trackLength,
  Duration tolerance = const Duration(seconds: 1),
  Duration interval = continuitySampleInterval,
}) {
  final gaps = <ContinuityIssue>[];
  final stalls = <ContinuityIssue>[];
  final jumps = <ContinuityIssue>[];
  final clockJumps = <ContinuityIssue>[];
  var trackChanges = 0;
  var discontinuous = 0;
  var playing = Duration.zero;
  var run = Duration.zero;
  var runStart = Duration.zero;
  var longest = Duration.zero;
  var longestStart = Duration.zero;
  final origin = samples.isEmpty ? Duration.zero : samples.first.elapsed;

  for (var i = 1; i < samples.length; i++) {
    final a = samples[i - 1];
    final b = samples[i];
    final at = a.elapsed - origin;
    final elapsed = b.elapsed - a.elapsed;
    final wall = b.wall.difference(a.wall);

    if (elapsed > interval + tolerance) {
      gaps.add(ContinuityIssue(at: at, amount: elapsed - interval));
    }
    final clockJumped = (wall - elapsed).abs() > tolerance;
    if (clockJumped) {
      clockJumps.add(ContinuityIssue(at: at, amount: wall - elapsed));
    }
    final trackChanged = b.track != a.track;
    if (trackChanged) trackChanges++;

    var good = false;
    if (a.advancing && b.advancing) {
      playing += elapsed;
      final Duration? advanced;
      if (!trackChanged) {
        advanced = b.position - a.position;
      } else if (b.track == a.track + 1) {
        advanced = trackLength - a.position + b.position;
      } else {
        advanced = null;
      }
      final kept = advanced != null && (advanced - elapsed).abs() <= tolerance;
      if (trackChanged && !kept) discontinuous++;
      if (advanced != null && !kept) {
        if (advanced < elapsed) {
          stalls.add(ContinuityIssue(at: at, amount: elapsed - advanced));
        } else {
          jumps.add(ContinuityIssue(at: at, amount: advanced - elapsed));
        }
      }
      good = kept && !clockJumped;
    }

    if (good) {
      run += elapsed;
      if (run > longest) {
        longest = run;
        longestStart = runStart;
      }
    } else {
      run = Duration.zero;
      runStart = b.elapsed - origin;
    }
  }

  return ContinuityReport(
    samples: samples.length,
    span: samples.isEmpty ? Duration.zero : samples.last.elapsed - origin,
    playing: playing,
    longestRun: longest,
    longestRunStart: longestStart,
    gaps: gaps,
    stalls: stalls,
    positionJumps: jumps,
    clockJumps: clockJumps,
    trackChanges: trackChanges,
    discontinuousTrackChanges: discontinuous,
  );
}

typedef PlayerProbe = ({
  Duration position,
  bool playing,
  String state,
  int track,
});

/// Appends a sample every [interval], and every event recorded, to [file] as
/// JSON lines, so a run survives the process being killed.
class ContinuityLogger {
  ContinuityLogger({
    required this.file,
    required this.probe,
    this.interval = continuitySampleInterval,
  });

  final File file;
  final PlayerProbe Function() probe;
  final Duration interval;
  final List<ContinuitySample> samples = [];
  final List<ContinuityEvent> events = [];
  final _stopwatch = Stopwatch();
  final _updates = StreamController<void>.broadcast();
  Timer? _timer;
  Future<void> _writes = Future.value();
  int _writeFailures = 0;

  Stream<void> get updates => _updates.stream;
  bool get running => _timer != null;
  int get writeFailures => _writeFailures;

  Future<void> start() async {
    await stop();
    await file.parent.create(recursive: true);
    await file.writeAsString('', flush: true);
    samples.clear();
    events.clear();
    _writeFailures = 0;
    _stopwatch
      ..reset()
      ..start();
    _timer = Timer.periodic(interval, (_) => _sample());
    _sample();
  }

  void record(String name) {
    if (!running) return;
    final event = ContinuityEvent(
      wall: DateTime.now().toUtc(),
      elapsed: _stopwatch.elapsed,
      name: name,
    );
    events.add(event);
    _append(event.toJson());
  }

  Future<void> stop() async {
    if (running) _sample();
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();
    await _writes;
    _updates.add(null);
  }

  Future<void> dispose() async {
    await stop();
    await _updates.close();
  }

  void _sample() {
    final p = probe();
    final sample = ContinuitySample(
      wall: DateTime.now().toUtc(),
      elapsed: _stopwatch.elapsed,
      position: p.position,
      playing: p.playing,
      state: p.state,
      track: p.track,
    );
    samples.add(sample);
    _append(sample.toJson());
  }

  void _append(Map<String, Object> json) {
    final line = '${jsonEncode(json)}\n';
    _writes = _writes
        .then(
          (_) => file.writeAsString(line, mode: FileMode.append, flush: true),
        )
        .then<void>((_) {}, onError: (Object _) => _writeFailures++);
    _updates.add(null);
  }
}
