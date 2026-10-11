import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show DeviceGestureSettings, kTouchSlop;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';

import 'gesture_log.dart';

// The S7 gesture log (NF-05, D-095): numbers, enum names and addresses only;
// latency from the finger's last up; nearest-rank statistics. Addresses are
// addresses, never text.

final QuranAddress _word = QuranAddress('hafs', 2, 255, 3);
final QuranAddress _ayah = QuranAddress('hafs', 2, 255);

const GestureLogContext _context = (
  touchSlop: 18,
  touchSlopFromPlatform: false,
  devicePixelRatio: 2.75,
  textScale: 1,
  view: Size(392, 850),
  disableAnimations: false,
  platform: TargetPlatform.android,
);

/// A log on a clock the test sets.
({GestureLog log, void Function(int) at}) _fakeLog({int capacity = 100}) {
  var now = 0;
  return (
    log: GestureLog(capacity: capacity, clockMs: () => now),
    at: (ms) => now = ms,
  );
}

void _expectNoNulls(Object? json) {
  switch (json) {
    case null:
      fail('null in the log');
    case Map<String, Object?>():
      json.values.forEach(_expectNoNulls);
    case List<Object?>():
      json.forEach(_expectNoNulls);
  }
}

void main() {
  group('timing', () {
    testWidgets('at, the first down, the last up, the frame after', (
      tester,
    ) async {
      final (:log, :at) = _fakeLog();
      at(10);
      log.pointerDown();
      at(12);
      log.pointerDown();
      at(30);
      log.pointerUp();
      at(40);
      log.pointerUp();
      at(45);
      final tap = log.record(gesture: LoggedGesture.tap)!;
      expect(tap.atMs, 45);
      expect(tap.downMs, 10);
      expect(tap.upMs, 40);
      expect(tap.frameMs, isNull);

      at(61);
      await tester.pump();
      expect(tap.frameMs, 61);
      expect(tap.toJson()['frame_ms'], 61);
    });

    testWidgets('no up before the finger lifts', (tester) async {
      final (:log, :at) = _fakeLog();
      at(100);
      log.pointerDown();
      at(600);
      final press = log.record(gesture: LoggedGesture.longPress)!;
      expect(press.downMs, 100);
      expect(press.upMs, isNull);
      expect(press.toJson().containsKey('up_ms'), isFalse);

      at(700);
      log.pointerUp();
      at(705);
      final later = log.record(gesture: LoggedGesture.tap)!;
      expect(later.downMs, 100);
      expect(later.upMs, 700);
      await tester.pump();
    });

    testWidgets('the up is the last lift; the next down clears it', (
      tester,
    ) async {
      final (:log, :at) = _fakeLog();
      at(10);
      log.pointerDown();
      at(12);
      log.pointerDown();
      at(20);
      log.pointerUp();
      at(21);
      expect(log.record(gesture: LoggedGesture.textPinch)!.upMs, isNull);
      at(30);
      log.pointerUp();
      at(31);
      expect(log.record(gesture: LoggedGesture.textPinch)!.upMs, 30);
      at(40);
      log.pointerDown();
      at(41);
      final next = log.record(gesture: LoggedGesture.longPress)!;
      expect(next.downMs, 40);
      expect(next.upMs, isNull);
      await tester.pump();
    });
  });

  group('JSON', () {
    testWidgets('exact keys, no nulls, addresses that parse back, ASCII', (
      tester,
    ) async {
      final (:log, :at) = _fakeLog();
      log.setContext(_context);
      at(1);
      log.pointerDown();
      at(2);
      log.pointerUp();
      at(3);
      log.record(
        gesture: LoggedGesture.tap,
        target: LoggedTarget.word,
        address: _word,
        mark: 1,
        rule: 'priorityZonesWithSlop',
        page: 3,
        toPage: 4,
        line: 5,
        scale: 1.5,
        textSize: 1.15,
        point: const Offset(1.5, 2.5),
        expectedTarget: LoggedTarget.waqfMark,
        expectedAddress: _ayah,
        expectedMark: 2,
      );
      at(4);
      await tester.pump();

      final json = jsonDecode(jsonEncode(log.toJson())) as Map<String, Object?>;
      expect(json.keys, [
        'format',
        'version',
        'capacity',
        'dropped',
        'contexts',
        'entries',
        'summary',
      ]);
      expect(json['format'], 's7-gesture-log');
      expect(json['version'], 1);
      expect(json['capacity'], 100);
      expect(json['dropped'], 0);
      expect(json['contexts'], [
        {
          'touch_slop': 18,
          'touch_slop_from_platform': false,
          'device_pixel_ratio': 2.75,
          'text_scale': 1,
          'view_width': 392,
          'view_height': 850,
          'disable_animations': false,
          'platform': 'android',
        },
      ]);
      final entry = (json['entries']! as List<Object?>).single! as Map;
      expect(entry, {
        'at_ms': 3,
        'context': 0,
        'down_ms': 1,
        'up_ms': 2,
        'frame_ms': 4,
        'gesture': 'tap',
        'target': 'word',
        'address': 'hafs:2:255:3',
        'mark': 1,
        'rule': 'priorityZonesWithSlop',
        'page': 3,
        'to_page': 4,
        'line': 5,
        'scale': 1.5,
        'text_size': 1.15,
        'point_x': 1.5,
        'point_y': 2.5,
        'expected_target': 'waqfMark',
        'expected_address': 'hafs:2:255',
        'expected_mark': 2,
      });
      expect(QuranAddress.parse(entry['address']! as String), _word);
      expect(QuranAddress.parse(entry['expected_address']! as String), _ayah);
      _expectNoNulls(json);
      expect(jsonEncode(log.toJson()).codeUnits.every((u) => u < 0x80), isTrue);
    });

    testWidgets('nulls are omitted', (tester) async {
      final (:log, :at) = _fakeLog();
      at(7);
      final bare = log.record(gesture: LoggedGesture.pageZoom)!;
      expect(bare.toJson(), {'at_ms': 7, 'gesture': 'pageZoom'});
      _expectNoNulls(jsonDecode(jsonEncode(log.toJson())));
      await tester.pump();
    });

    test('a rule must be an enum name', () {
      final (:log, at: _) = _fakeLog();
      for (final rule in ['Exact', 'nearest line', '', '1st', 'a-b']) {
        expect(
          () => log.record(gesture: LoggedGesture.tap, rule: rule),
          throwsArgumentError,
          reason: rule,
        );
      }
      expect(log.entries, isEmpty);
    });
  });

  group('capacity and contexts', () {
    testWidgets('a full log keeps the first entries and counts the rest', (
      tester,
    ) async {
      final (:log, at: _) = _fakeLog(capacity: 3);
      final recorded = [
        for (var page = 0; page < 5; page++)
          log.record(gesture: LoggedGesture.pageTurn, page: page),
      ];
      expect(recorded.map((e) => e != null), [true, true, true, false, false]);
      expect(log.entries.map((e) => e.page), [0, 1, 2]);
      expect(log.dropped, 2);
      expect(log.toJson()['dropped'], 2);
      expect(log.summary()['entries'], 3);
      await tester.pump();
    });

    testWidgets('a context is kept only when it changes', (tester) async {
      final (:log, at: _) = _fakeLog();
      log
        ..setContext(_context)
        ..setContext(_context);
      final first = log.record(gesture: LoggedGesture.tap)!;
      log.setContext((
        touchSlop: _context.touchSlop,
        touchSlopFromPlatform: _context.touchSlopFromPlatform,
        devicePixelRatio: _context.devicePixelRatio,
        textScale: 2,
        view: _context.view,
        disableAnimations: _context.disableAnimations,
        platform: _context.platform,
      ));
      final second = log.record(gesture: LoggedGesture.tap)!;
      expect(log.toJson()['contexts'], hasLength(2));
      expect(first.context, 0);
      expect(second.context, 1);
      await tester.pump();
    });

    for (final slop in [8.0, null]) {
      testWidgets('the context of a view, touch slop $slop', (tester) async {
        late GestureLogContext context;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: const Size(400, 800),
              devicePixelRatio: 2.75,
              textScaler: const TextScaler.linear(2),
              gestureSettings: DeviceGestureSettings(touchSlop: slop),
              disableAnimations: true,
            ),
            child: Builder(
              builder: (c) {
                context = gestureLogContextOf(c);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(context, (
          touchSlop: slop ?? kTouchSlop,
          touchSlopFromPlatform: slop != null,
          devicePixelRatio: 2.75,
          textScale: 2.0,
          view: const Size(400, 800),
          disableAnimations: true,
          platform: defaultTargetPlatform,
        ));
      });
    }
  });

  group('summary', () {
    test('nearest-rank statistics', () {
      expect(latencyStats([]), (n: 0, median: null, p95: null, max: null));
      expect(latencyStats([5]), (n: 1, median: 5, p95: 5, max: 5));
      expect(latencyStats([3, 1, 2]), (n: 3, median: 2, p95: 3, max: 3));
      expect(latencyStats([1, 2, 3, 4]), (n: 4, median: 2, p95: 4, max: 4));
      // Rank 10.45 is the 11th value; rounding would give the 10th.
      expect(latencyStats([for (var i = 1; i <= 11; i++) i]), (
        n: 11,
        median: 6,
        p95: 11,
        max: 11,
      ));
      expect(latencyStats([for (var i = 1; i <= 20; i++) i]), (
        n: 20,
        median: 10,
        p95: 19,
        max: 20,
      ));
      expect(latencyStats([for (var i = 100; i >= 1; i--) i]), (
        n: 100,
        median: 50,
        p95: 95,
        max: 100,
      ));
    });

    testWidgets('counts, latencies and practice hits', (tester) async {
      final (:log, :at) = _fakeLog();
      void tapAt(
        int up,
        int recorded, {
        required LoggedTarget target,
        QuranAddress? address,
        int? mark,
        LoggedTarget? expected,
        QuranAddress? expectedAddress,
        int? expectedMark,
      }) {
        at(up - 50);
        log.pointerDown();
        at(up);
        log.pointerUp();
        at(recorded);
        log.record(
          gesture: LoggedGesture.tap,
          target: target,
          address: address,
          mark: mark,
          rule: 'exact',
          expectedTarget: expected,
          expectedAddress: expectedAddress,
          expectedMark: expectedMark,
        );
      }

      tapAt(
        100,
        105,
        target: LoggedTarget.word,
        address: _word,
        expected: LoggedTarget.word,
        expectedAddress: _word,
      );
      tapAt(
        200,
        207,
        target: LoggedTarget.margin,
        expected: LoggedTarget.word,
        expectedAddress: _word,
      );
      tapAt(
        300,
        303,
        target: LoggedTarget.waqfMark,
        address: _ayah,
        mark: 1,
        expected: LoggedTarget.waqfMark,
        expectedAddress: _ayah,
        expectedMark: 1,
      );
      tapAt(
        400,
        409,
        target: LoggedTarget.waqfMark,
        address: _ayah,
        mark: 1,
        expected: LoggedTarget.waqfMark,
        expectedAddress: _ayah,
        expectedMark: 2,
      );
      tapAt(500, 504, target: LoggedTarget.margin);
      at(600);
      log.record(gesture: LoggedGesture.pageZoom, scale: 2);
      at(620);
      await tester.pump();

      final summary =
          jsonDecode(jsonEncode(log.summary())) as Map<String, Object?>;
      expect(summary['entries'], 6);
      expect(summary['by_gesture'], {'tap': 5, 'pageZoom': 1});
      expect(summary['by_target'], {'word': 1, 'margin': 2, 'waqfMark': 2});
      // at - up: 5, 7, 3, 9, 4 and 100 for the zoom after the last up.
      expect(summary['up_to_at_ms'], {
        'n': 6,
        'median': 5,
        'p95': 100,
        'max': 100,
      });
      // Every frame ended at 620: 520, 420, 320, 220, 120 and 120.
      expect(summary['up_to_frame_ms'], {
        'n': 6,
        'median': 220,
        'p95': 520,
        'max': 520,
      });
      expect(summary['practice'], {
        'trials': 4,
        'hits': 2,
        'by_target': {
          'word': {'trials': 2, 'hits': 1},
          'waqfMark': {'trials': 2, 'hits': 1},
        },
      });
    });
  });
}
