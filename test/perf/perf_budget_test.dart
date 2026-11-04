import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/perf/perf_budget.dart';

// The numbers the harness holds runs against come from the PRD and are
// repeated in docs/ARCHITECTURE.md ("Budgets"). A document that changes must
// change the harness with it.
void main() {
  final architecture = File('docs/ARCHITECTURE.md').readAsStringSync();
  final prd = File('docs/prd/PRD.ar.md').readAsStringSync();

  String row(String id) =>
      architecture.split('\n').firstWhere((line) => line.startsWith('| $id |'));

  List<PerfCheck> checksOf(String id) => [
    for (final check in perfChecks)
      if (check.id == id) check,
  ];

  test('every check names a requirement of the PRD', () {
    for (final check in perfChecks) {
      expect(prd, contains('| ${check.id} |'), reason: '$check');
    }
  });

  test('NF-01 is 2 s, as ARCHITECTURE.md gives it', () {
    expect(row('NF-01'), contains('2 s'));
    expect(checksOf('NF-01').single.limit, 2000);
    expect(checksOf('NF-01').single.unit, 'ms');
  });

  test('NF-02 is 99% of frames under 32 ms and 60 fps', () {
    expect(row('NF-02'), contains('60 fps'));
    expect(row('NF-02'), contains('99% of frames under 32 ms'));
    final share = checksOf('NF-02')
        .singleWhere((c) => c.metric == 'over32MsShare');
    expect(share.comparison, Comparison.atMost);
    expect(share.limit, 0.01);
    expect(share.holds(0.01), isTrue, reason: '1% over is 99% not over');
    expect(share.holds(0.011), isFalse);
  });

  test('NF-02 holds the frame rate to 60 less a stated tolerance', () {
    final fps = checksOf('NF-02')
        .singleWhere((c) => c.metric == 'framesPerSecond');
    expect(fps.comparison, Comparison.atLeast);
    expect(fps.limit, lessThan(60));
    expect(fps.limit, greaterThanOrEqualTo(58));
    expect(fps.source, contains('60 frames per second'));
    expect(fps.source, contains('tolerance'));
  });

  test('NF-03 is 300 ms, for the first search and the next', () {
    expect(row('NF-03'), contains('300 ms'));
    expect(
      [for (final c in checksOf('NF-03')) c.scenario],
      ['search', 'search_warm'],
    );
    for (final check in checksOf('NF-03')) {
      expect(check.limit, 300);
    }
  });

  test('NF-05 is 200 ms, for the word sheet and the ayah sheet', () {
    expect(row('NF-05'), contains('200 ms'));
    expect(
      [for (final c in checksOf('NF-05')) c.scenario],
      ['word_sheet', 'ayah_sheet'],
    );
    for (final check in checksOf('NF-05')) {
      expect(check.limit, 200);
    }
  });

  test('every check says where its number comes from and what it times', () {
    for (final check in perfChecks) {
      expect(check.source, contains(check.id));
      expect(check.measures, isNotEmpty);
    }
  });

  test(
    'a check holds a value on its side of the limit, the limit included',
    () {
      expect(Comparison.atMost.holds(10, 10), isTrue);
      expect(Comparison.atMost.holds(10.1, 10), isFalse);
      expect(Comparison.atLeast.holds(59, 59), isTrue);
      expect(Comparison.atLeast.holds(58.9, 59), isFalse);
    },
  );

  test('a scroll that did not last the span is refused', () {
    final share = checksOf('NF-02')
        .singleWhere((c) => c.metric == 'travelledShare');
    expect(share.comparison, Comparison.atLeast);
    expect(share.holds(1), isTrue);
    expect(share.holds(0.6), isFalse);
  });

  test('each check asks for the counts of the device protocol', () {
    final samples = {
      for (final check in perfChecks) check.scenario: check.minSamples,
    };

    expect(samples, {
      'cold_start': 10,
      'scroll': 3,
      'search': 5,
      'search_warm': 5,
      'word_sheet': 10,
      'ayah_sheet': 10,
    });
  });

  test('the README states the counts the checks ask for', () {
    final readme = File('integration_test/perf/README.md').readAsStringSync();

    expect(readme, contains('ten cold starts'));
    expect(readme, contains('five searches'));
    expect(readme, contains('three scrolls'));
    expect(readme, contains('ten openings'));
  });
}
