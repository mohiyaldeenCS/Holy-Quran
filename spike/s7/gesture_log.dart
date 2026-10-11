import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

/// Twenty minutes at a gesture a second is 1,200 entries; this many is
/// about 1 MB of JSON.
const int gestureLogCapacity = 5000;

enum LoggedGesture {
  tap,
  longPress,
  textPinch,
  pageTurn,
  pageTurnCancelled,
  pageZoom,
}

enum LoggedTarget { word, waqfMark, marker, margin, pageLine }

/// The device conditions a stretch of entries ran under.
typedef GestureLogContext = ({
  double touchSlop,
  bool touchSlopFromPlatform,
  double devicePixelRatio,
  double textScale,
  Size view,
  bool disableAnimations,
  TargetPlatform platform,
});

/// [context]'s conditions. The touch slop is the platform's when the view
/// reports one (Android's may differ from Flutter's), else [kTouchSlop]. The
/// text scale is the one `quranPage`'s size gets.
GestureLogContext gestureLogContextOf(BuildContext context) {
  final slop = MediaQuery.gestureSettingsOf(context).touchSlop;
  final size = AppTextStyles.quranPage.fontSize!;
  return (
    touchSlop: slop ?? kTouchSlop,
    touchSlopFromPlatform: slop != null,
    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    textScale: MediaQuery.textScalerOf(context).scale(size) / size,
    view: MediaQuery.sizeOf(context),
    disableAnimations: MediaQuery.disableAnimationsOf(context),
    platform: defaultTargetPlatform,
  );
}

/// Nearest-rank statistics of [ms]: the p-th percentile is the sorted value
/// at index ceil(p * n / 100) - 1; null when [ms] is empty.
({int n, int? median, int? p95, int? max}) latencyStats(Iterable<int> ms) {
  final sorted = ms.toList()..sort();
  final n = sorted.length;
  if (n == 0) return (n: 0, median: null, p95: null, max: null);
  int rank(int p) => sorted[(p * n + 99) ~/ 100 - 1];
  return (n: n, median: rank(50), p95: rank(95), max: sorted.last);
}

/// One gesture as S7 saw it: numbers, enum names and addresses only.
final class GestureLogEntry {
  GestureLogEntry._({
    required this.atMs,
    required this.context,
    required this.downMs,
    required this.upMs,
    required this.gesture,
    required this.target,
    required this.address,
    required this.mark,
    required this.rule,
    required this.page,
    required this.toPage,
    required this.line,
    required this.scale,
    required this.textSize,
    required this.point,
    required this.expectedTarget,
    required this.expectedAddress,
    required this.expectedMark,
  });

  final int atMs;

  /// The index of the context in force, null before any was set.
  final int? context;

  /// The first down of the touch sequence.
  final int? downMs;

  /// The sequence's last up, when it came before this entry.
  final int? upMs;

  /// The end of the first frame after this entry, rasterising excluded.
  int? get frameMs => _frameMs;
  int? _frameMs;

  final LoggedGesture gesture;
  final LoggedTarget? target;
  final QuranAddress? address;
  final int? mark;
  final String? rule;
  final int? page;
  final int? toPage;
  final int? line;
  final double? scale;
  final double? textSize;
  final Offset? point;
  final LoggedTarget? expectedTarget;
  final QuranAddress? expectedAddress;
  final int? expectedMark;

  bool get isTrial => expectedTarget != null;

  bool get isHit =>
      isTrial &&
      target == expectedTarget &&
      address == expectedAddress &&
      mark == expectedMark;

  Map<String, Object> toJson() => {
    'at_ms': atMs,
    'context': ?context,
    'down_ms': ?downMs,
    'up_ms': ?upMs,
    'frame_ms': ?frameMs,
    'gesture': gesture.name,
    'target': ?target?.name,
    'address': ?address?.toString(),
    'mark': ?mark,
    'rule': ?rule,
    'page': ?page,
    'to_page': ?toPage,
    'line': ?line,
    'scale': ?scale,
    'text_size': ?textSize,
    'point_x': ?point?.dx,
    'point_y': ?point?.dy,
    'expected_target': ?expectedTarget?.name,
    'expected_address': ?expectedAddress?.toString(),
    'expected_mark': ?expectedMark,
  };
}

/// The S7 gesture log (NF-05): what each gesture hit, how long it took from
/// the finger's last up, and the conditions it ran under. Callers feed
/// [pointerDown] and [pointerUp] from a Listener above their gesture
/// detector, which sees each event before any recogniser callback.
final class GestureLog {
  GestureLog({this.capacity = gestureLogCapacity, int Function()? clockMs})
    : _clock = clockMs ?? _stopwatch();

  final int capacity;
  final int Function() _clock;
  final List<GestureLogContext> _contexts = [];
  final List<GestureLogEntry> _entries = [];
  int _dropped = 0;
  int _pointers = 0;
  int? _downMs;
  int? _upMs;

  static final RegExp _enumName = RegExp(r'^[a-z][A-Za-z0-9]*$');

  static int Function() _stopwatch() {
    final watch = Stopwatch()..start();
    return () => watch.elapsedMilliseconds;
  }

  List<GestureLogEntry> get entries => List.unmodifiable(_entries);

  /// Entries refused because the log was full.
  int get dropped => _dropped;

  /// Starts a new context when [context] differs from the last one.
  void setContext(GestureLogContext context) {
    if (_contexts.isEmpty || _contexts.last != context) _contexts.add(context);
  }

  void pointerDown() {
    if (_pointers++ == 0) {
      _downMs = _clock();
      _upMs = null;
    }
  }

  void pointerUp() {
    if (_pointers == 0) return;
    if (--_pointers == 0) _upMs = _clock();
  }

  /// Adds an entry, or returns null and counts it dropped when the log is
  /// full. [rule] is an enum value's name, such as `TapRule.exact.name`.
  GestureLogEntry? record({
    required LoggedGesture gesture,
    LoggedTarget? target,
    QuranAddress? address,
    int? mark,
    String? rule,
    int? page,
    int? toPage,
    int? line,
    double? scale,
    double? textSize,
    Offset? point,
    LoggedTarget? expectedTarget,
    QuranAddress? expectedAddress,
    int? expectedMark,
  }) {
    if (rule != null && !_enumName.hasMatch(rule)) {
      throw ArgumentError.value(rule, 'rule', 'must be an enum name');
    }
    if (_entries.length >= capacity) {
      _dropped++;
      return null;
    }
    final entry = GestureLogEntry._(
      atMs: _clock(),
      context: _contexts.isEmpty ? null : _contexts.length - 1,
      downMs: _downMs,
      upMs: _upMs,
      gesture: gesture,
      target: target,
      address: address,
      mark: mark,
      rule: rule,
      page: page,
      toPage: toPage,
      line: line,
      scale: scale,
      textSize: textSize,
      point: point,
      expectedTarget: expectedTarget,
      expectedAddress: expectedAddress,
      expectedMark: expectedMark,
    );
    _entries.add(entry);
    // The post-frame callback runs once the frame this entry asks for is
    // built, laid out and painted; rasterising is not included.
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => entry._frameMs = _clock())
      ..scheduleFrame();
    return entry;
  }

  Map<String, Object> summary() {
    final byGesture = <String, int>{};
    final byTarget = <String, int>{};
    final toAt = <int>[];
    final toFrame = <int>[];
    var trials = 0;
    var hits = 0;
    final practice = <String, ({int trials, int hits})>{};
    for (final entry in _entries) {
      byGesture.update(entry.gesture.name, (n) => n + 1, ifAbsent: () => 1);
      if (entry.target case final target?) {
        byTarget.update(target.name, (n) => n + 1, ifAbsent: () => 1);
      }
      if (entry.upMs case final up?) {
        toAt.add(entry.atMs - up);
        if (entry.frameMs case final frame?) toFrame.add(frame - up);
      }
      if (entry.expectedTarget case final expected?) {
        final hit = entry.isHit ? 1 : 0;
        trials++;
        hits += hit;
        final last = practice[expected.name] ?? (trials: 0, hits: 0);
        practice[expected.name] = (
          trials: last.trials + 1,
          hits: last.hits + hit,
        );
      }
    }
    return {
      'entries': _entries.length,
      'by_gesture': byGesture,
      'by_target': byTarget,
      'up_to_at_ms': _statsJson(latencyStats(toAt)),
      'up_to_frame_ms': _statsJson(latencyStats(toFrame)),
      'practice': {
        'trials': trials,
        'hits': hits,
        'by_target': {
          for (final MapEntry(:key, :value) in practice.entries)
            key: {'trials': value.trials, 'hits': value.hits},
        },
      },
    };
  }

  Map<String, Object> toJson() => {
    'format': 's7-gesture-log',
    'version': 1,
    'capacity': capacity,
    'dropped': _dropped,
    'contexts': [for (final context in _contexts) _contextJson(context)],
    'entries': [for (final entry in _entries) entry.toJson()],
    'summary': summary(),
  };
}

Map<String, Object> _statsJson(({int n, int? median, int? p95, int? max}) s) =>
    {'n': s.n, 'median': ?s.median, 'p95': ?s.p95, 'max': ?s.max};

Map<String, Object> _contextJson(GestureLogContext c) => {
  'touch_slop': c.touchSlop,
  'touch_slop_from_platform': c.touchSlopFromPlatform,
  'device_pixel_ratio': c.devicePixelRatio,
  'text_scale': c.textScale,
  'view_width': c.view.width,
  'view_height': c.view.height,
  'disable_animations': c.disableAnimations,
  'platform': c.platform.name,
};
