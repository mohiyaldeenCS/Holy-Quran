import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/perf/frame_stats.dart';

FrameSample _frame(int index, int totalMicros, {int interval = 16667}) =>
    FrameSample(
      vsyncMicros: index * interval,
      buildMicros: totalMicros ~/ 2,
      rasterMicros: totalMicros ~/ 2,
      totalMicros: totalMicros,
    );

void main() {
  test('fewer than two frames give no metrics', () {
    expect(summariseFrames(const []), isEmpty);
    expect(summariseFrames([_frame(0, 8000)]), isEmpty);
  });

  test('frames on every vsync of a 60 Hz display give 60 frames a second', () {
    final metrics = summariseFrames([
      for (var i = 0; i < 601; i++) _frame(i, 9000),
    ]);

    expect(metrics['frames'], 601);
    expect(metrics['framesPerSecond'], closeTo(60, 0.01));
    expect(metrics['p50FrameMs'], 9);
    expect(metrics['p99FrameMs'], 9);
    expect(metrics['over32MsShare'], 0);
  });

  test('the 99th percentile is the nearest rank: one slow frame in a '
      'hundred does not move it, two do', () {
    List<FrameSample> frames(int slow) => [
      for (var i = 0; i < 100; i++) _frame(i, i < slow ? 40000 : 10000),
    ];

    expect(summariseFrames(frames(1))['p99FrameMs'], 10);
    expect(summariseFrames(frames(2))['p99FrameMs'], 40);
    expect(summariseFrames(frames(2))['over32MsShare'], 0.02);
    expect(summariseFrames(frames(2))['maxFrameMs'], 40);
  });

  test('frames given out of order are taken in vsync order', () {
    final metrics = summariseFrames([
      _frame(2, 8000),
      _frame(0, 8000),
      _frame(1, 8000),
    ]);

    expect(metrics['framesPerSecond'], closeTo(60, 0.01));
  });

  test('build and raster percentiles are kept apart', () {
    final metrics = summariseFrames([
      for (var i = 0; i < 10; i++)
        FrameSample(
          vsyncMicros: i * 16667,
          buildMicros: 3000,
          rasterMicros: 12000,
          totalMicros: 15000,
        ),
    ]);

    expect(metrics['buildP99Ms'], 3);
    expect(metrics['rasterP99Ms'], 12);
  });

  test('a run that kept to 30 frames a second is seen as such', () {
    final metrics = summariseFrames([
      for (var i = 0; i < 100; i++) _frame(i, 30000, interval: 33333),
    ]);

    expect(metrics['framesPerSecond'], closeTo(30, 0.01));
  });
}
