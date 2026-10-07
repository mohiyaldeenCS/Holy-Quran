import 'package:flutter_test/flutter_test.dart';

import 'unicode_categories.dart';

void main() {
  Iterable<int> covered() sync* {
    for (final (first, last) in coveredBlocks) {
      for (var c = first; c <= last; c++) {
        yield c;
      }
    }
  }

  test('every assigned code point of the table has the category Dart '
      'RegExp gives it', () {
    final patterns = <String, RegExp>{};
    final wrong = [
      for (final c in covered())
        if (generalCategory(c) case final category?)
          if (!(patterns[category] ??= RegExp(
            '^\\p{$category}\$',
            unicode: true,
          )).hasMatch(String.fromCharCode(c)))
            '${codePointName(c)} is not $category',
    ];
    expect(wrong, isEmpty);
  });

  test('a letter is an assigned code point of the table in \\p{L}', () {
    final letter = RegExp(r'^\p{L}$', unicode: true);
    final wrong = [
      for (final c in covered())
        if (generalCategory(c) != null &&
            isLetter(c) != letter.hasMatch(String.fromCharCode(c)))
          codePointName(c),
    ];
    expect(wrong, isEmpty);
  });

  test('no code point the table leaves out of the covered blocks is \\p{L}, '
      'but those Unicode assigned after 15.1', () {
    // Lo since Unicode 16.0, in Arabic Extended-C. U+0897 ARABIC PEPET and
    // U+10EFC ARABIC COMBINING ALEF OVERLAY are also new in 16.0, as Mn, so
    // they need no entry: the check is about letters only.
    const assignedLater = {0x10EC2, 0x10EC3, 0x10EC4};
    final letter = RegExp(r'^\p{L}$', unicode: true);
    final missing = [
      for (final c in covered())
        if (generalCategory(c) == null &&
            !assignedLater.contains(c) &&
            letter.hasMatch(String.fromCharCode(c)))
          codePointName(c),
    ];
    expect(missing, isEmpty);
    for (final c in assignedLater) {
      expect(generalCategory(c), isNull, reason: codePointName(c));
    }
  });

  test('the letters of the synthetic and Arabic texts', () {
    for (final c in [0x41, 0x7A, 0xAA, 0xC0, 0xE9, 0xFF, 0x628, 0x671]) {
      expect(isLetter(c), isTrue, reason: codePointName(c));
    }
    expect(isLetter(0x640), isTrue, reason: 'tatweel is Lm');
    expect(isLetter(0x6E5), isTrue, reason: 'small waw is Lm');
    expect(isLetter(0x1EE00), isTrue, reason: 'Arabic mathematical alef');
  });

  test('marks, digits, punctuation, spaces and what lies outside the '
      'table are no letter', () {
    for (final c in [
      0x20,
      0x2D,
      0x31,
      0xA0,
      0xD7,
      0xF7,
      0x64E,
      0x660,
      0x670,
      0x6D6,
      0x6DC,
      0x6DE,
      0x6E9,
      0xFEFF,
    ]) {
      expect(isLetter(c), isFalse, reason: codePointName(c));
    }
    expect(generalCategory(0x301), isNull, reason: 'outside the table');
    expect(isLetter(0x301), isFalse);
    expect(generalCategory(0x1F600), isNull, reason: 'outside the table');
    expect(isLetter(0x1F600), isFalse);
    expect(generalCategory(0x88F), isNull, reason: 'unassigned');
  });

  test('the table ends where the covered blocks end', () {
    expect(generalCategory(0x0000), 'Cc');
    expect(generalCategory(0x00FF), 'Ll');
    expect(generalCategory(0x0100), isNull);
    expect(generalCategory(0x05FF), isNull);
    expect(generalCategory(0x1EEF1), 'Sm');
    expect(generalCategory(0x1EEFF), isNull);
  });

  test('codePointName', () {
    expect(codePointName(0x2D), 'U+002D');
    expect(codePointName(0x6DE), 'U+06DE');
    expect(codePointName(0x1F600), 'U+1F600');
  });
}
