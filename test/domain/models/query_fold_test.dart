import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/query_fold.dart';

// Synthetic Arabic-script letters and marks, written as escapes: never Quran
// text. Each letter stands alone; together they spell nothing.
const _sin = '\u0633';
const _ya = '\u064A';
const _nun = '\u0646';
const _fatha = '\u064E';
const _sukun = '\u0652';
const _harakat = [
  0x064B,
  0x064C,
  0x064D,
  0x064E,
  0x064F,
  0x0650,
  0x0651,
  0x0652,
];

void main() {
  group('QueryFold.fold', () {
    test('drops each of the eight harakat', () {
      for (final mark in _harakat) {
        expect(
          QueryFold.fold('$_sin${String.fromCharCode(mark)}$_ya'),
          '$_sin$_ya',
          reason: mark.toRadixString(16),
        );
      }
    });

    test('keeps every other unit, the neighbours of the harakat included', () {
      const kept =
          '\u064A\u0653\u0654\u0655\u0670\u0640\u0623\u0625\u0622\u0671'
          '\u0629\u0649 Latin e\u0301 \u{1F600}';
      expect(QueryFold.fold(kept), kept);
    });

    test('folding twice is folding once', () {
      const query = '$_sin$_fatha$_ya$_sukun$_nun';
      expect(QueryFold.fold(QueryFold.fold(query)), QueryFold.fold(query));
      expect(QueryFold.fold(''), '');
    });
  });

  group('QueryFold.words', () {
    test('splits at runs of white space and folds each word', () {
      expect(QueryFold.words('  $_sin$_fatha$_ya \t\n x\u00A0y  '), [
        '$_sin$_ya',
        'x',
        'y',
      ]);
    });

    test('a query of white space or harakat only has no words', () {
      expect(QueryFold.words(' \t '), isEmpty);
      expect(QueryFold.words('$_fatha$_sukun'), isEmpty);
    });
  });

  group('QueryFold.findAll', () {
    const text = 'a $_sin$_fatha$_ya$_sukun$_nun b $_sin$_ya$_nun$_fatha';

    test('matches over the harakat of the text and keeps their offsets', () {
      final found = QueryFold.findAll(text, '$_sin$_ya$_nun');
      expect(found, [(start: 2, end: 7), (start: 10, end: 14)]);
      expect(text.substring(2, 7), '$_sin$_fatha$_ya$_sukun$_nun');
      expect(text.substring(10, 14), '$_sin$_ya$_nun$_fatha');
    });

    test('a match inside a word ends over the marks of its last letter', () {
      expect(QueryFold.findAll(text, _sin), [
        (start: 2, end: 4),
        (start: 10, end: 11),
      ]);
    });

    test('never starts on a dropped unit, and does not overlap', () {
      expect(QueryFold.findAll('aaa', 'aa'), [(start: 0, end: 2)]);
      expect(QueryFold.findAll('$_fatha$_sin', _sin), [(start: 1, end: 2)]);
    });

    test('finds nothing for an empty or absent query', () {
      expect(QueryFold.findAll(text, ''), isEmpty);
      expect(QueryFold.findAll(text, 'z'), isEmpty);
      expect(QueryFold.findAll('', 'a'), isEmpty);
      expect(QueryFold.findAll('a$_fatha', 'ab'), isEmpty);
    });

    test('is exact on every other unit', () {
      expect(QueryFold.findAll('e\u0301 \u00E9', '\u00E9'), [
        (start: 3, end: 4),
      ]);
      expect(QueryFold.findAll('A a', 'a'), [(start: 2, end: 3)]);
    });
  });
}
