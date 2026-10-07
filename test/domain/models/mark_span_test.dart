import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/mark_span.dart';

void main() {
  test('allows an empty span and a mark before the first word', () {
    const mark = MarkSpan(number: 1, afterWord: 0, start: 3, end: 3);
    expect((mark.number, mark.afterWord, mark.start, mark.end), (1, 0, 3, 3));
  });

  test('rejects a reversed or negative span and a negative word', () {
    expect(
      () => MarkSpan(number: 1, afterWord: 0, start: 4, end: 3),
      throwsAssertionError,
    );
    expect(
      () => MarkSpan(number: 1, afterWord: 0, start: -1, end: 3),
      throwsAssertionError,
    );
    expect(
      () => MarkSpan(number: 1, afterWord: -1, start: 0, end: 3),
      throwsAssertionError,
    );
  });

  test('equality and hash code are by value', () {
    const mark = MarkSpan(number: 2, afterWord: 1, start: 3, end: 7);
    expect(mark, const MarkSpan(number: 2, afterWord: 1, start: 3, end: 7));
    expect(
      mark.hashCode,
      const MarkSpan(number: 2, afterWord: 1, start: 3, end: 7).hashCode,
    );
    for (final other in const [
      MarkSpan(number: 3, afterWord: 1, start: 3, end: 7),
      MarkSpan(number: 2, afterWord: 2, start: 3, end: 7),
      MarkSpan(number: 2, afterWord: 1, start: 4, end: 7),
      MarkSpan(number: 2, afterWord: 1, start: 3, end: 8),
    ]) {
      expect(mark, isNot(other));
    }
  });
}
