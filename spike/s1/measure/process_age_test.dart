import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'process_age.dart';

/// A `/proc/<pid>/stat` line with [name] as field 2 and [start] as field
/// 22; the other fields are made up but of the right count (52).
String _stat(String name, int start) {
  final fields = [
    'S', // 3
    for (var f = 4; f <= 21; f++) '$f',
    '$start', // 22
    for (var f = 23; f <= 52; f++) '$f',
  ];
  return '4242 ($name) ${fields.join(' ')}\n';
}

void main() {
  test('field 22 is read after the last parenthesis', () {
    expect(processStartTicks(_stat('com.example.app', 123456)), 123456);
    expect(processStartTicks(_stat('a) (b c', 77)), 77);
    expect(processStartTicks(_stat('', 5)), 5);
  });

  test('a line that is cut short or has no name does not parse', () {
    expect(processStartTicks('4242 (app) S 1 2 3\n'), isNull);
    expect(processStartTicks('4242 app S 1 2 3'), isNull);
    expect(processStartTicks(_stat('app', 9).replaceAll(' 9 ', ' z ')), isNull);
  });

  test('the age is uptime less the start in ticks', () {
    expect(
      processAgeFrom(
        stat: _stat('app', 123456),
        uptime: '1239.56 4321.00\n',
        ticksPerSecond: 100,
      ),
      const Duration(milliseconds: 5000),
    );
    expect(
      processAgeFrom(
        stat: _stat('app', 2500),
        uptime: '12.5 1.0\n',
        ticksPerSecond: 250,
      ),
      const Duration(milliseconds: 2500),
    );
  });

  test('bad input gives null, not a guess', () {
    expect(
      processAgeFrom(stat: 'x', uptime: '1.00 1.00', ticksPerSecond: 100),
      isNull,
    );
    expect(
      processAgeFrom(stat: _stat('a', 1), uptime: 'up', ticksPerSecond: 100),
      isNull,
    );
    expect(
      processAgeFrom(
        stat: _stat('a', 1),
        uptime: '1.00 1.00',
        ticksPerSecond: 0,
      ),
      isNull,
    );
    expect(
      processAgeFrom(
        stat: _stat('a', 500),
        uptime: '1.00 1.00',
        ticksPerSecond: 100,
      ),
      isNull,
      reason: 'a start after the uptime',
    );
  });

  test('null off Android; the C library gives a tick rate', () {
    if (!Platform.isAndroid) expect(processAge(), isNull);
    expect(clockTicksPerSecond(), greaterThan(0));
  });
}
