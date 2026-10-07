import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/word_span.dart';

void main() {
  test('allows an empty span and rejects a reversed or negative one', () {
    expect(const WordSpan(number: 1, start: 3, end: 3).end, 3);
    expect(() => WordSpan(number: 1, start: 4, end: 3), throwsAssertionError);
    expect(() => WordSpan(number: 1, start: -1, end: 3), throwsAssertionError);
  });

  test('equality and hash code are by value', () {
    expect(
      const WordSpan(number: 2, start: 3, end: 7),
      const WordSpan(number: 2, start: 3, end: 7),
    );
    expect(
      const WordSpan(number: 2, start: 3, end: 7).hashCode,
      const WordSpan(number: 2, start: 3, end: 7).hashCode,
    );
    expect(
      const WordSpan(number: 2, start: 3, end: 7),
      isNot(const WordSpan(number: 2, start: 3, end: 8)),
    );
  });
}
