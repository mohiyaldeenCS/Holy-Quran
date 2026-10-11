import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';

import 'gesture_log.dart';
import 'target_geometry.dart';
import 'target_practice.dart';

QuranAddress _ayah(int n) => QuranAddress('hafs', 1, n);
QuranAddress _word(int ayah, int n) => QuranAddress('hafs', 1, ayah, n);

const _visible = Rect.fromLTRB(0, 0, 300, 100);

TargetGeometry _geometry() => TargetGeometry(
  lineBands: const [
    Rect.fromLTRB(0, 0, 300, 50),
    Rect.fromLTRB(0, 50, 300, 100),
  ],
  words: {
    _word(1, 1): const [Rect.fromLTRB(200, 10, 260, 40)],
    // Drawn on two lines: never a target.
    _word(1, 2): const [
      Rect.fromLTRB(0, 10, 40, 40),
      Rect.fromLTRB(260, 60, 300, 90),
    ],
    // No width.
    _word(1, 3): const [Rect.fromLTRB(100, 60, 100, 90)],
    // Below the visible rect.
    _word(1, 4): const [Rect.fromLTRB(100, 90, 160, 120)],
  },
  marks: {(_ayah(1), 1): const Rect.fromLTRB(170, 10, 190, 40)},
  markers: {_ayah(1): const Rect.fromLTRB(120, 12, 146, 38)},
);

void main() {
  test('only whole, positive boxes inside the visible rect are picked, and '
      'every kind comes up', () {
    final random = Random(1);
    final seen = <(LoggedTarget, QuranAddress, int?)>{};
    for (var i = 0; i < 200; i++) {
      final target = pickPracticeTarget(_geometry(), _visible, random)!;
      seen.add((target.kind, target.address, target.mark));
    }
    expect(seen, {
      (LoggedTarget.word, _word(1, 1), null),
      (LoggedTarget.waqfMark, _ayah(1), 1),
      (LoggedTarget.marker, _ayah(1), null),
    });
  });

  test('the box is the target\'s own', () {
    final geometry = _geometry();
    for (var seed = 0; seed < 20; seed++) {
      final target = pickPracticeTarget(geometry, _visible, Random(seed))!;
      final box = switch (target.kind) {
        LoggedTarget.word => geometry.words[target.address]!.single,
        LoggedTarget.waqfMark => geometry.marks[(target.address, target.mark)],
        _ => geometry.markers[target.address],
      };
      expect(target.box, box);
    }
  });

  test('null when nothing qualifies', () {
    expect(
      pickPracticeTarget(
        _geometry(),
        const Rect.fromLTRB(0, 200, 300, 300),
        Random(1),
      ),
      isNull,
    );
    expect(
      pickPracticeTarget(
        TargetGeometry(lineBands: const []),
        _visible,
        Random(1),
      ),
      isNull,
    );
  });

  testWidgets('hit rates by kind and by rule count trials only', (
    tester,
  ) async {
    var now = 0;
    final log = GestureLog(clockMs: () => now++);
    log
      ..record(gesture: LoggedGesture.tap, target: LoggedTarget.margin)
      ..record(
        gesture: LoggedGesture.tap,
        target: LoggedTarget.word,
        address: _word(1, 1),
        rule: 'exact',
        expectedTarget: LoggedTarget.word,
        expectedAddress: _word(1, 1),
      )
      ..record(
        gesture: LoggedGesture.tap,
        target: LoggedTarget.margin,
        rule: 'exact',
        expectedTarget: LoggedTarget.marker,
        expectedAddress: _ayah(1),
      )
      ..record(
        gesture: LoggedGesture.tap,
        target: LoggedTarget.waqfMark,
        address: _ayah(1),
        mark: 1,
        rule: 'nearestOnLine',
        expectedTarget: LoggedTarget.waqfMark,
        expectedAddress: _ayah(1),
        expectedMark: 1,
      );
    expect(hitRatesByKind(log.entries), {
      LoggedTarget.word: (trials: 1, hits: 1),
      LoggedTarget.marker: (trials: 1, hits: 0),
      LoggedTarget.waqfMark: (trials: 1, hits: 1),
    });
    final byRule = hitRatesByRule(log.entries);
    expect(byRule, {
      'exact': (trials: 2, hits: 1),
      'nearestOnLine': (trials: 1, hits: 1),
    });
    expect(hitRatesJson(byRule), {
      'exact': {'trials': 2, 'hits': 1},
      'nearestOnLine': {'trials': 1, 'hits': 1},
    });
  });

  testWidgets('the ring lies 4 px outside the box and takes no touch', (
    tester,
  ) async {
    var tapped = 0;
    const box = Rect.fromLTRB(40, 40, 80, 70);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(ReadingTheme.paper),
        home: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => tapped++,
          child: const SizedBox.expand(
            child: Stack(children: [PracticeRing(box: box)]),
          ),
        ),
      ),
    );
    expect(tester.getRect(find.byType(DecoratedBox)), box.inflate(4));
    await tester.tapAt(box.center);
    expect(tapped, 1);
  });
}
