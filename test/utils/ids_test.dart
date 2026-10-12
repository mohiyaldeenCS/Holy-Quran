import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/utils/ids.dart';

void main() {
  test('an id is 128 bits as 32 lower-case hexadecimal digits', () {
    final id = newId();

    expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(BigInt.parse(id, radix: 16).bitLength, lessThanOrEqualTo(128));
  });

  test('ids do not repeat', () {
    final ids = {for (var i = 0; i < 10000; i++) newId()};

    expect(ids, hasLength(10000));
  });

  test('every bit position varies', () {
    final ids = [
      for (var i = 0; i < 256; i++) BigInt.parse(newId(), radix: 16),
    ];
    final ones = ids.reduce((a, b) => a | b);
    final zeros = ids.reduce((a, b) => a & b);

    expect(ones, (BigInt.one << 128) - BigInt.one);
    expect(zeros, BigInt.zero);
  });
}
