import 'dart:math' as math;

/// One frame: when its vsync began and how long it took from there to the end
/// of its raster work (`FrameTiming.totalSpan`), split into the UI thread's
/// build and the raster thread's.
final class FrameSample {
  const FrameSample({
    required this.vsyncMicros,
    required this.buildMicros,
    required this.rasterMicros,
    required this.totalMicros,
  });

  final int vsyncMicros;
  final int buildMicros;
  final int rasterMicros;
  final int totalMicros;
}

/// The metrics of a run of frames, named as the checks of `perf_budget.dart`
/// name them; empty for fewer than two frames, which give no rate.
Map<String, num> summariseFrames(List<FrameSample> frames) {
  if (frames.length < 2) return const {};
  final ordered = [...frames]
    ..sort((a, b) => a.vsyncMicros.compareTo(b.vsyncMicros));
  final seconds = (ordered.last.vsyncMicros - ordered.first.vsyncMicros) / 1e6;
  double ms(List<int> micros, double fraction) =>
      _nearestRank(micros, fraction) / 1000;
  final totals = [for (final f in ordered) f.totalMicros];
  return {
    'frames': ordered.length,
    'framesPerSecond': seconds <= 0 ? 0 : (ordered.length - 1) / seconds,
    'p50FrameMs': ms(totals, 0.5),
    'p90FrameMs': ms(totals, 0.9),
    'p99FrameMs': ms(totals, 0.99),
    'maxFrameMs': totals.reduce(math.max) / 1000,
    'buildP99Ms': ms([for (final f in ordered) f.buildMicros], 0.99),
    'rasterP99Ms': ms([for (final f in ordered) f.rasterMicros], 0.99),
    'over32MsShare':
        totals.where((micros) => micros > 32000).length / totals.length,
  };
}

/// The smallest value that [fraction] of [values] do not exceed.
int _nearestRank(List<int> values, double fraction) {
  final sorted = [...values]..sort();
  return sorted[(fraction * sorted.length).ceil().clamp(1, sorted.length) - 1];
}
