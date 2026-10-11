import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'frame_stats.dart';

/// A frame starting at [at] us with [build] and [raster] us of work, the
/// raster starting [queue] us after the build ends.
FrameTiming _frame(int at, int build, int raster, {int queue = 0}) {
  final rasterStart = at + build + queue;
  return FrameTiming(
    vsyncStart: at,
    buildStart: at,
    buildFinish: at + build,
    rasterStart: rasterStart,
    rasterFinish: rasterStart + raster,
    rasterFinishWallTime: rasterStart + raster,
  );
}

void main() {
  test('percentiles are nearest rank', () {
    final sorted = [for (var i = 1; i <= 100; i++) i.toDouble()];
    expect(nearestRank(sorted, 0.50), 50);
    expect(nearestRank(sorted, 0.90), 90);
    expect(nearestRank(sorted, 0.99), 99);
    expect(nearestRank([7], 0.5), 7);
    expect(nearestRank([1, 2, 3], 0), 1);
  });

  test('phases and shares of 100 frames', () {
    final timings = [
      // 90 frames of 5 ms build and 6 ms raster: 11 ms in all.
      for (var i = 0; i < 90; i++) _frame(i * 100000, 5000, 6000),
      // 8 frames of 10 + 10 ms: over 16.7 ms in all, but no phase over it.
      for (var i = 90; i < 98; i++) _frame(i * 100000, 10000, 10000),
      // 2 frames with a 40 ms raster.
      for (var i = 98; i < 100; i++) _frame(i * 100000, 2000, 40000),
    ];
    final stats = FrameStats.from(timings, refreshRate: 60);
    expect(stats.frames, 100);
    expect(stats.build.p50, 5);
    expect(stats.build.p90, 5);
    expect(stats.build.p99, 10);
    expect(stats.build.max, 10);
    expect(stats.raster.p50, 6);
    expect(stats.raster.p99, 40);
    expect(stats.total.p50, 11);
    expect(stats.total.p90, 11);
    expect(stats.total.p99, 42);
    expect(stats.total.max, 42);
    expect(stats.over16, closeTo(0.10, 1e-9));
    expect(stats.over32, closeTo(0.02, 1e-9));
    expect(stats.overBudget, closeTo(0.10, 1e-9));
    expect(stats.janky, closeTo(0.02, 1e-9));
  });

  test('the budget follows the refresh rate', () {
    final timings = [
      _frame(0, 4000, 4000),
      _frame(100000, 6000, 6000),
      _frame(200000, 9000, 4000),
    ];
    final at60 = FrameStats.from(timings, refreshRate: 60);
    final at120 = FrameStats.from(timings, refreshRate: 120);
    expect(at60.overBudget, 0);
    expect(at60.janky, 0);
    expect(at120.overBudget, closeTo(2 / 3, 1e-9));
    expect(at120.janky, closeTo(1 / 3, 1e-9));
    expect(at120.over16, 0);
  });

  test('time queued before the raster counts in the total only', () {
    final stats = FrameStats.from([
      _frame(0, 5000, 5000, queue: 30000),
    ], refreshRate: 60);
    expect(stats.total.max, 40);
    expect(stats.over32, 1);
    expect(stats.janky, 0);
  });

  test('the JSON form holds numbers only', () {
    final json = FrameStats.from([
      _frame(0, 1000, 2000),
    ], refreshRate: 90).toJson();
    expect(json['frames'], 1);
    expect(json['refreshRate'], 90);
    expect(json['total'], {'p50': 3, 'p90': 3, 'p99': 3, 'max': 3});
    expect(json.keys, containsAll(['over16ms', 'over32ms', 'janky']));
  });

  test('refuses no frames and a rate that is not positive', () {
    expect(
      () => FrameStats.from(const [], refreshRate: 60),
      throwsArgumentError,
    );
    expect(
      () => FrameStats.from([_frame(0, 1, 1)], refreshRate: 0),
      throwsArgumentError,
    );
  });
}
