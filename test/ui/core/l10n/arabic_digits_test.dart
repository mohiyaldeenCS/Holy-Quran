import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/ui/core/l10n/arabic_digits.dart';

/// The Arabic-Indic digits for an ASCII numeral, built from code points.
String _expected(String ascii) =>
    String.fromCharCodes(ascii.codeUnits.map((unit) => 0x0660 + unit - 0x30));

void main() {
  test('writes every digit in Arabic-Indic form', () {
    for (var d = 0; d <= 9; d++) {
      expect(arabicDigits(d), String.fromCharCode(0x0660 + d), reason: '$d');
    }
  });

  test('keeps the order and count of digits', () {
    for (final n in [10, 100, 255, 604, 6236, 1234567890]) {
      expect(arabicDigits(n), _expected('$n'), reason: '$n');
    }
  });

  test('leaves no ASCII digit behind', () {
    expect(arabicDigits(9876543210), isNot(matches(RegExp('[0-9]'))));
  });

  test('rejects a negative number', () {
    expect(() => arabicDigits(-1), throwsArgumentError);
  });
}
