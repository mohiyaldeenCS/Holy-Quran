import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'frame_stats.dart';
import 'perf_result.dart';

/// `debug`, `profile` or `release`.
String get perfBuildMode => kReleaseMode
    ? 'release'
    : kProfileMode
    ? 'profile'
    : 'debug';

/// Whether frames are really drawn at the display's pace, as on a device
/// under the integration test binding; under a plain widget test they are
/// built at once and only their build cost is real.
bool isLiveBinding(WidgetTester tester) =>
    tester.binding is LiveTestWidgetsFlutterBinding;

/// Pumps frames, letting real input and output finish between them, until
/// [done] holds, and returns the time since [clock] started when the frame
/// that satisfied it was built. Throws when [timeout] passes first.
Future<Duration> pumpUntilFrame(
  WidgetTester tester,
  Stopwatch clock,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 60),
}) async {
  do {
    if (clock.elapsed > timeout) {
      throw TimeoutException('A frame did not satisfy the condition', timeout);
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    await tester.pump(const Duration(milliseconds: 2));
  } while (!done());
  return clock.elapsed;
}

/// Marks [name] on the timeline, so that a trace taken on a device by other
/// means can be lined up with the harness's numbers.
void markTimeline(String name) => developer.Timeline.instantSync('perf:$name');

double millis(Duration duration) => duration.inMicroseconds / 1000;

/// What a run knows about its device, for the result's details.
Map<String, Object?> deviceDetails(WidgetTester tester) {
  final view = tester.view;
  return {
    'os': Platform.operatingSystemVersion,
    'processors': Platform.numberOfProcessors,
    'refreshRateHz': view.display.refreshRate,
    'devicePixelRatio': view.devicePixelRatio,
    'logicalWidth': view.physicalSize.width / view.devicePixelRatio,
    'logicalHeight': view.physicalSize.height / view.devicePixelRatio,
    'liveFrames': isLiveBinding(tester),
  };
}

PerfResult resultOf(
  WidgetTester tester,
  String scenario,
  Map<String, num> metrics, [
  Map<String, Object?> details = const {},
]) => PerfResult(
  scenario: scenario,
  buildMode: perfBuildMode,
  platform: Platform.operatingSystem,
  metrics: metrics,
  details: {...deviceDetails(tester), ...details},
);

/// Collects the frames of a run. The engine's timings (build and raster,
/// from vsync) are used when [engineTimings] says the run has real frames;
/// otherwise the cost of each pump is, which is informative only and says so
/// in the result.
final class FrameRecorder {
  FrameRecorder({required this.engineTimings});

  final bool engineTimings;
  final _timed = <FrameSample>[];
  final _pumped = <FrameSample>[];

  void start() {
    if (engineTimings) {
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
    }
  }

  void stop() {
    if (engineTimings) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    }
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _timed.add(
        FrameSample(
          vsyncMicros: timing.timestampInMicroseconds(FramePhase.vsyncStart),
          buildMicros: timing.buildDuration.inMicroseconds,
          rasterMicros: timing.rasterDuration.inMicroseconds,
          totalMicros: timing.totalSpan.inMicroseconds,
        ),
      );
    }
  }

  /// Records a pump that began at [startMicros] on a stopwatch and took
  /// [cost].
  void addPumped(int startMicros, Duration cost) => _pumped.add(
    FrameSample(
      vsyncMicros: startMicros,
      buildMicros: cost.inMicroseconds,
      rasterMicros: 0,
      totalMicros: cost.inMicroseconds,
    ),
  );

  String get source => engineTimings ? 'frame-timing' : 'pump-wall-clock';

  List<FrameSample> get frames => engineTimings ? _timed : _pumped;
}
