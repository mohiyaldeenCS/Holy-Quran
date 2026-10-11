import 'dart:ui';

/// Percentiles of one phase of a run of frames, in milliseconds.
typedef PhaseStats = ({double p50, double p90, double p99, double max});

/// Frame timings of one run (NF-02), from the engine's [FrameTiming]s.
final class FrameStats {
  const FrameStats._({
    required this.frames,
    required this.refreshRate,
    required this.build,
    required this.raster,
    required this.total,
    required this.over16,
    required this.over32,
    required this.overBudget,
    required this.janky,
  });

  /// Statistics of [timings] on a display refreshing [refreshRate] times a
  /// second. Throws an [ArgumentError] when there are no timings or the
  /// rate is not positive.
  factory FrameStats.from(
    List<FrameTiming> timings, {
    required double refreshRate,
  }) {
    if (timings.isEmpty) throw ArgumentError.value(timings, 'timings', 'empty');
    if (!(refreshRate > 0)) {
      throw ArgumentError.value(refreshRate, 'refreshRate', 'not positive');
    }
    final budget = 1000 / refreshRate;
    double ms(Duration d) => d.inMicroseconds / 1000;
    final build = [for (final t in timings) ms(t.buildDuration)];
    final raster = [for (final t in timings) ms(t.rasterDuration)];
    final total = [for (final t in timings) ms(t.totalSpan)];
    double share(bool Function(int i) over) {
      var n = 0;
      for (var i = 0; i < timings.length; i++) {
        if (over(i)) n++;
      }
      return n / timings.length;
    }

    return FrameStats._(
      frames: timings.length,
      refreshRate: refreshRate,
      build: _phase(build),
      raster: _phase(raster),
      total: _phase(total),
      over16: share((i) => total[i] > frameBudget60Hz),
      over32: share((i) => total[i] > 32),
      overBudget: share((i) => total[i] > budget),
      janky: share((i) => build[i] > budget || raster[i] > budget),
    );
  }

  /// One frame at 60 Hz, as NF-02 counts it.
  static const frameBudget60Hz = 16.7;

  final int frames;
  final double refreshRate;
  final PhaseStats build;
  final PhaseStats raster;

  /// From the vsync to the end of rasterising.
  final PhaseStats total;

  /// Shares of frames whose total span is over 16.7 ms, over 32 ms, and over
  /// one refresh interval of [refreshRate].
  final double over16;
  final double over32;
  final double overBudget;

  /// Share of frames whose build or raster phase alone is over one refresh
  /// interval, which is how DevTools marks a frame as janky.
  final double janky;

  Map<String, Object> toJson() => {
    'frames': frames,
    'refreshRate': refreshRate,
    'build': _json(build),
    'raster': _json(raster),
    'total': _json(total),
    'over16ms': over16,
    'over32ms': over32,
    'overBudget': overBudget,
    'janky': janky,
  };
}

PhaseStats _phase(List<double> values) {
  final sorted = [...values]..sort();
  return (
    p50: nearestRank(sorted, 0.50),
    p90: nearestRank(sorted, 0.90),
    p99: nearestRank(sorted, 0.99),
    max: sorted.last,
  );
}

Map<String, double> _json(PhaseStats s) => {
  'p50': s.p50,
  'p90': s.p90,
  'p99': s.p99,
  'max': s.max,
};

/// The nearest-rank [fraction] percentile of [sorted], ascending and not
/// empty.
double nearestRank(List<double> sorted, double fraction) {
  final rank = (fraction * sorted.length).ceil();
  return sorted[(rank < 1 ? 1 : rank) - 1];
}
