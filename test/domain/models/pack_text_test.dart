import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';

/// Built at run time, so that equal values are not one canonical constant.
PackText _text(String value) => PackText.fromPack(value);

void main() {
  const samples = [
    '',
    'synthetic sample',
    '  leading, trailing  and double spaces  ',
    'e\u0301 and \u00E9 stay apart',
    'ab \u{1F600} cd',
    '\uFEFFsynthetic after a BOM',
  ];

  test('verbatim returns exactly the value it was given', () {
    for (final sample in samples) {
      final text = _text(sample);
      expect(identical(text.verbatim, sample), isTrue);
      expect(text.verbatim.codeUnits, sample.codeUnits);
    }
  });

  test('equality and hash code are by exact value', () {
    expect(_text('synthetic sample'), _text('synthetic sample'));
    expect(
      _text('synthetic sample').hashCode,
      _text('synthetic sample').hashCode,
    );
    expect(
      _text('e\u0301'),
      isNot(_text('\u00E9')),
      reason: 'canonically equivalent forms are different pack values',
    );
    expect(_text('a '), isNot(_text('a')));
    expect(_text('synthetic sample'), isNot('synthetic sample'));
  });

  test('toString gives the length in code units, never the value', () {
    expect(_text('ab \u{1F600} cd').toString(), 'PackText(8 code units)');
    expect(_text('').toString(), 'PackText(0 code units)');
    for (final sample in samples.where((s) => s.trim().isNotEmpty)) {
      expect(_text(sample).toString(), isNot(contains(sample)));
      expect('${_text(sample)}', isNot(contains('synthetic')));
    }
  });

  test('isSliceBoundary holds within the text, between characters', () {
    final text = _text('ab \u{1F600} cd');
    expect(
      [
        for (var offset = -1; offset <= 9; offset++)
          text.isSliceBoundary(offset),
      ],
      [false, true, true, true, true, false, true, true, true, true, false],
    );
    expect(_text('').isSliceBoundary(0), isTrue);
    expect(_text('').isSliceBoundary(1), isFalse);
    expect(_text('\u{1F600}').isSliceBoundary(1), isFalse);
    expect(_text('\u{1F600}').isSliceBoundary(2), isTrue);
  });

  test('isSliceBoundary allows a lone surrogate to be cut around', () {
    final text = _text('a\uD83Db');
    expect(
      [for (var i = 0; i <= 3; i++) text.isSliceBoundary(i)],
      [true, true, true, true],
    );
  });
}
