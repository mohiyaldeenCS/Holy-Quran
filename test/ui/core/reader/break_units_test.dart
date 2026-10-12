import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/mark_span.dart';
import 'package:holyquran/domain/models/word_span.dart';
import 'package:holyquran/ui/core/reader/break_units.dart';

// Offsets of a synthetic layout, no text: ' w1 m w2  w3 m m ', with a mark
// before the first word too.
const _words = [
  WordSpan(number: 1, start: 3, end: 5),
  WordSpan(number: 2, start: 8, end: 10),
  WordSpan(number: 3, start: 12, end: 14),
  WordSpan(number: 4, start: 14, end: 16),
];
const _marks = [
  MarkSpan(number: 1, afterWord: 0, start: 1, end: 2),
  MarkSpan(number: 2, afterWord: 1, start: 6, end: 7),
  MarkSpan(number: 3, afterWord: 4, start: 17, end: 18),
];

void main() {
  test('units break only before words, keeping marks with the word before', () {
    final units = AyahUnits.of(20, _words, _marks);
    // Words 3 and 4 touch, with no space to break at, so they stay one unit.
    expect(
      [for (final u in units.units) (u.start, u.end)],
      [(0, 7), (8, 10), (12, 20)],
    );
    expect(units.gaps, [(7, 8), (10, 12)]);
    expect(units.units.first.tokens, [(1, 2), (3, 5), (6, 7)]);
    expect(units.units.last.tokens, [(12, 14), (14, 16), (17, 18)]);
  });

  test('units and gaps tile the text', () {
    final units = AyahUnits.of(20, _words, _marks);
    var at = 0;
    for (var k = 0; k < units.units.length; k++) {
      expect(units.units[k].start, at);
      at = units.units[k].end;
      if (k < units.gaps.length) {
        expect(units.gaps[k].$1, at);
        at = units.gaps[k].$2;
      }
    }
    expect(at, 20);
    expect(units.unitAt(9), 1);
    expect(units.unitAt(11), 1);
    expect(units.unitAt(0), 0);
  });

  test('an ayah of one word is one unit', () {
    final units = AyahUnits.of(4, const [
      WordSpan(number: 1, start: 0, end: 4),
    ], const []);
    expect(units.units, hasLength(1));
    expect(units.gaps, isEmpty);
  });
}
