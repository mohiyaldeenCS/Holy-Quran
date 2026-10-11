import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'continuity_log.dart';

const _track = Duration(seconds: 350);
final _t0 = DateTime.utc(2026, 10, 7, 12);

Duration _d(num seconds) => Duration(milliseconds: (seconds * 1000).round());

ContinuitySample _sample(
  num elapsed, {
  num? wall,
  required num position,
  int track = 0,
  bool playing = true,
  String state = 'ready',
}) => ContinuitySample(
  wall: _t0.add(_d(wall ?? elapsed)),
  elapsed: _d(elapsed),
  position: _d(position),
  playing: playing,
  state: state,
  track: track,
);

/// Continuous playback from [from] to [to] seconds of playlist time, sampled
/// every 5 s, with elapsed and wall clock equal to playlist time plus
/// [offset].
List<ContinuitySample> _steady(int from, int to, {num offset = 0}) => [
  for (var t = from; t < to; t += 5)
    _sample(t + offset, position: t % 350, track: t ~/ 350),
];

ContinuityReport _analyse(List<ContinuitySample> samples) =>
    analyse(samples, trackLength: _track);

void main() {
  test('a clean 70-minute playlist is one run across every track change', () {
    final report = _analyse(_steady(0, 4200));
    expect(report.samples, 840);
    expect(report.longestRun, _d(4195));
    expect(report.longestRunStart, Duration.zero);
    expect(report.playing, _d(4195));
    expect(report.trackChanges, 11);
    expect(report.discontinuousTrackChanges, 0);
    expect(report.gaps, isEmpty);
    expect(report.stalls, isEmpty);
    expect(report.positionJumps, isEmpty);
    expect(report.clockJumps, isEmpty);
    expect(report.meetsTarget, isTrue);
  });

  test('a late sample is a gap but does not break a continuous run', () {
    final samples = _steady(0, 4200)..removeRange(20, 23);
    final report = _analyse(samples);
    expect(report.gaps, hasLength(1));
    expect(report.gaps.single.at, _d(95));
    expect(report.gaps.single.amount, _d(15));
    expect(report.longestRun, _d(4195));
  });

  test('a stalled position is a stall and splits the run', () {
    final samples = [
      ..._steady(0, 1800),
      _sample(1800, position: 50, track: 5),
      _sample(1805, position: 50, track: 5),
      _sample(1810, position: 50, track: 5, state: 'buffering'),
      ..._steady(1800, 4200, offset: 15),
    ];
    final report = _analyse(samples);
    expect(report.stalls.map((s) => s.amount), [_d(5), _d(5), _d(5)]);
    expect(report.stalls.first.at, _d(1800));
    expect(report.longestRun, _d(2395));
    expect(report.longestRunStart, _d(1815));
    expect(report.meetsTarget, isFalse);
  });

  test('a skipped track is a discontinuous track change', () {
    final samples = [
      _sample(0, position: 340, track: 2),
      _sample(5, position: 345, track: 2),
      _sample(10, position: 0, track: 4),
      _sample(15, position: 5, track: 4),
      _sample(20, position: 348, track: 4),
    ];
    final report = _analyse(samples);
    expect(report.trackChanges, 1);
    expect(report.discontinuousTrackChanges, 1);
    expect(report.positionJumps.single.at, _d(15));
    expect(report.positionJumps.single.amount, _d(338));
    expect(report.longestRun, _d(5));
  });

  test('a track change that loses time is a stall at the boundary', () {
    final samples = [
      _sample(0, position: 340),
      _sample(5, position: 345),
      _sample(15, position: 1, track: 1),
    ];
    final report = _analyse(samples);
    expect(report.discontinuousTrackChanges, 1);
    expect(report.stalls.single.amount, _d(4));
    expect(report.gaps.single.amount, _d(5));
  });

  test('a wall-clock jump is reported and splits the run', () {
    final samples = [
      _sample(0, position: 0),
      _sample(5, position: 5),
      _sample(10, wall: 70, position: 10),
      _sample(15, wall: 75, position: 15),
      _sample(20, wall: 80, position: 20),
    ];
    final report = _analyse(samples);
    expect(report.clockJumps.single.at, _d(5));
    expect(report.clockJumps.single.amount, _d(60));
    expect(report.stalls, isEmpty);
    expect(report.longestRun, _d(10));
    expect(report.longestRunStart, _d(10));
  });

  test('pauses and completion are not playing time and split the run', () {
    final samples = [
      _sample(0, position: 0),
      _sample(5, position: 5),
      _sample(10, position: 5, playing: false),
      _sample(15, position: 5, playing: false),
      _sample(20, position: 5),
      _sample(25, position: 10),
      _sample(30, position: 15),
      _sample(35, position: 350, state: 'completed'),
    ];
    final report = _analyse(samples);
    expect(report.playing, _d(15));
    expect(report.longestRun, _d(10));
    expect(report.longestRunStart, _d(20));
    expect(report.stalls, isEmpty);
  });

  test('an empty log gives a zero report', () {
    final report = _analyse(const []);
    expect(report.samples, 0);
    expect(report.longestRun, Duration.zero);
    expect(report.meetsTarget, isFalse);
  });

  test('the summary is key and number pairs only', () {
    final samples = [
      ..._steady(0, 600),
      _sample(600, position: 250, track: 1),
      ..._steady(600, 4200, offset: 5),
    ];
    final summary = _analyse(samples).summary;
    expect(summary, contains('meets_target 0'));
    expect(summary, contains('stalls 1 largest_s 5.0'));
    for (final line in summary.split('\n')) {
      final tokens = line.split(' ');
      expect(tokens.length.isEven, isTrue, reason: line);
      for (var i = 0; i < tokens.length; i += 2) {
        expect(tokens[i], matches(RegExp(r'^[a-z0-9_]+$')), reason: line);
        expect(num.tryParse(tokens[i + 1]), isNotNull, reason: line);
      }
    }
  });

  test('log lines round-trip and unknown kinds are refused', () {
    final sample = _sample(12.5, position: 3.25, track: 7, state: 'buffering');
    final event = ContinuityEvent(
      wall: _t0,
      elapsed: _d(1),
      name: 'click-double',
    );
    final log = parseContinuityLog(
      '${jsonEncode(sample.toJson())}\n\n${jsonEncode(event.toJson())}\n',
    );
    final back = log.samples.single;
    expect(back.wall, sample.wall);
    expect(back.elapsed, sample.elapsed);
    expect(back.position, sample.position);
    expect(back.playing, isTrue);
    expect(back.state, 'buffering');
    expect(back.track, 7);
    expect(log.events.single.name, 'click-double');
    expect(log.events.single.elapsed, _d(1));
    expect(() => parseContinuityLog('{"kind":"other"}'), throwsFormatException);
  });

  test('event tally counts names in order', () {
    ContinuityEvent e(String name) =>
        ContinuityEvent(wall: _t0, elapsed: Duration.zero, name: name);
    expect(
      eventTally([e('pause'), e('noisy'), e('pause')]),
      'event noisy 1\nevent pause 2',
    );
  });

  test('the logger appends samples and events to its file', () async {
    final dir = await Directory.systemTemp.createTemp('s3-log');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/nested/s3-log.jsonl');
    var position = Duration.zero;
    final logger = ContinuityLogger(
      file: file,
      interval: const Duration(milliseconds: 20),
      probe: () {
        position += const Duration(milliseconds: 20);
        return (position: position, playing: true, state: 'ready', track: 0);
      },
    );
    await logger.start();
    logger.record('play');
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await logger.dispose();
    logger.record('ignored');

    final log = parseContinuityLog(await file.readAsString());
    expect(log.samples.length, logger.samples.length);
    expect(log.samples.length, greaterThanOrEqualTo(3));
    expect(log.events.map((e) => e.name), ['play']);
    expect(logger.writeFailures, 0);
    for (var i = 1; i < log.samples.length; i++) {
      expect(log.samples[i].elapsed, greaterThan(log.samples[i - 1].elapsed));
    }

    final next = ContinuityLogger(
      file: file,
      probe: () =>
          (position: Duration.zero, playing: false, state: 'idle', track: -1),
    );
    await next.start();
    await next.dispose();
    expect(await file.readAsString(), isNot(contains('"play"')));
  });
}
