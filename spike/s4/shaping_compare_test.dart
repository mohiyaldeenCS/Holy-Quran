import 'package:flutter_test/flutter_test.dart';

import 'native_shaping_probe.dart';
import 'shaping_compare.dart';

// Flutter's side of the shaping comparison, on the synthetic samples with the
// Quran font the test config loads, and the comparison itself.

const ShapingMeasure _measure = (
  width: 200,
  height: 90,
  lineCount: 2,
  lineStarts: [0, 12],
  lineWidths: [200, 80],
);

void main() {
  group('compareShaping', () {
    test('gives zero deltas when the layouts are equal', () {
      final c = compareShaping(_measure, _measure, fontMatches: true);
      expect(c.widthDelta, 0);
      expect(c.heightDelta, 0);
      expect(c.lineCountDelta, 0);
      expect(c.firstMovedLine, isNull);
      expect(c.lineWidthDeltas, [0, 0]);
      expect(c.fontMatches, isTrue);
    });

    test('reports a moved line start', () {
      final native = (
        width: 200.0,
        height: 90.0,
        lineCount: 2,
        lineStarts: [0, 10],
        lineWidths: [200.0, 80.0],
      );
      expect(
        compareShaping(_measure, native, fontMatches: true).firstMovedLine,
        1,
      );
    });

    test('reports an extra line as moved', () {
      final native = (
        width: 200.0,
        height: 135.0,
        lineCount: 3,
        lineStarts: [0, 12, 20],
        lineWidths: [200.0, 80.0, 40.0],
      );
      final c = compareShaping(_measure, native, fontMatches: true);
      expect(c.firstMovedLine, 2);
      expect(c.lineCountDelta, 1);
      expect(c.heightDelta, 45);
      expect(c.lineWidthDeltas, [0, 0]);
    });

    test('reports width deltas as native minus Flutter', () {
      final native = (
        width: 203.5,
        height: 90.0,
        lineCount: 2,
        lineStarts: [0, 12],
        lineWidths: [203.5, 79.0],
      );
      final c = compareShaping(_measure, native, fontMatches: true);
      expect(c.widthDelta, 3.5);
      expect(c.lineWidthDeltas, [3.5, -1]);
      expect(c.firstMovedLine, isNull);
    });

    test('reports a font mismatch', () {
      expect(
        compareShaping(_measure, _measure, fontMatches: false).fontMatches,
        isFalse,
      );
    });
  });

  group('measureFlutterShaping', () {
    for (final sample in ShapingSample.values) {
      test('${sample.name}: lines start at 0 and rise', () {
        final m = measureFlutterShaping(sample, fontSize: 24, maxWidth: 160);
        expect(m.lineCount, greaterThanOrEqualTo(1));
        expect(m.lineStarts, hasLength(m.lineCount));
        expect(m.lineWidths, hasLength(m.lineCount));
        expect(m.lineStarts.first, 0);
        for (var i = 1; i < m.lineStarts.length; i++) {
          expect(m.lineStarts[i], greaterThan(m.lineStarts[i - 1]));
        }
        expect(m.lineStarts.last, lessThan(shapingSampleText(sample).length));
        expect(m.width, m.lineWidths.reduce((a, b) => a > b ? a : b));
        expect(m.width, lessThanOrEqualTo(160));
        expect(m.height, greaterThan(0));
      });
    }

    test('the long sample wraps when narrow and not when wide', () {
      final narrow = measureFlutterShaping(
        ShapingSample.long,
        fontSize: 24,
        maxWidth: 160,
      );
      final wide = measureFlutterShaping(
        ShapingSample.long,
        fontSize: 24,
        maxWidth: 100000,
      );
      expect(narrow.lineCount, greaterThan(2));
      expect(wide.lineCount, 1);
      expect(narrow.height, greaterThan(wide.height));
    });

    test('a line starts after the space that ends the line before', () {
      final text = shapingSampleText(ShapingSample.long);
      final m = measureFlutterShaping(
        ShapingSample.long,
        fontSize: 24,
        maxWidth: 160,
      );
      for (final start in m.lineStarts.skip(1)) {
        expect(text.codeUnitAt(start - 1), 0x20);
      }
    });
  });
}
