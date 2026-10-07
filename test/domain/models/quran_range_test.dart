import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_range.dart';

QuranAddress _a(String source) => QuranAddress.parse(source);

void main() {
  group('constructor', () {
    test('accepts an ayah range, a word range and a single address', () {
      expect(QuranRange(_a('hafs:2:255'), _a('hafs:2:260')).end.ayah, 260);
      expect(QuranRange(_a('hafs:2:255:3'), _a('hafs:3:1:1')).start.word, 3);
      expect(QuranRange(_a('hafs:2:255'), _a('hafs:2:255')).start.ayah, 255);
    });

    test('rejects mixed riwayat, mixed granularity and a reversed range', () {
      expect(
        () => QuranRange(_a('hafs:2:255'), _a('warsh:2:260')),
        throwsArgumentError,
      );
      expect(
        () => QuranRange(_a('hafs:2:255'), _a('hafs:2:260:1')),
        throwsArgumentError,
      );
      expect(
        () => QuranRange(_a('hafs:2:255:1'), _a('hafs:2:260')),
        throwsArgumentError,
      );
      expect(
        () => QuranRange(_a('hafs:2:260'), _a('hafs:2:255')),
        throwsArgumentError,
      );
      expect(
        () => QuranRange(_a('hafs:2:255:7'), _a('hafs:2:255:3')),
        throwsArgumentError,
      );
    });
  });

  group('parse', () {
    test('reads the canonical forms', () {
      expect(
        QuranRange.parse('hafs:2:255-2:260'),
        QuranRange(_a('hafs:2:255'), _a('hafs:2:260')),
      );
      expect(
        QuranRange.parse('hafs:2:255:3-2:255:7'),
        QuranRange(_a('hafs:2:255:3'), _a('hafs:2:255:7')),
      );
      expect(
        QuranRange.parse('warsh_2:1:1-3:4'),
        QuranRange(_a('warsh_2:1:1'), _a('warsh_2:3:4')),
      );
    });

    const malformed = [
      '',
      '-',
      'hafs:2:255',
      'hafs:2:255-',
      '-2:260',
      'hafs:2:255-hafs:2:260',
      'hafs:2:255-warsh:2:260',
      'hafs:2:255--2:260',
      'hafs:2:255-2:260-2:270',
      'hafs:2:255 -2:260',
      'hafs:2:255- 2:260',
      'hafs:2:255-2:260 ',
      'hafs:2:255-2:260:1',
      'hafs:2:255:1-2:260',
      'hafs:2:260-2:255',
      'hafs:2:255:7-2:255:3',
      'hafs:2:255-2',
      'hafs:2:255-02:260',
      'hafs:2:255-2:0',
      'hafs:2:255-2:\u0662\u0666\u0660',
      'hafs:2:255\u20132:260',
      'Hafs:2:255-2:260',
    ];

    for (final source in malformed) {
      test('rejects ${Uri.encodeComponent(source)}', () {
        expect(QuranRange.tryParse(source), isNull);
        expect(
          () => QuranRange.parse(source),
          throwsA(
            isA<FormatException>().having((e) => e.source, 'source', source),
          ),
        );
      });
    }
  });

  test('toString is canonical and round-trips', () {
    expect(
      QuranRange(_a('hafs:2:255'), _a('hafs:2:260')).toString(),
      'hafs:2:255-2:260',
    );
    expect(
      QuranRange(_a('hafs:2:255:3'), _a('hafs:2:255:7')).toString(),
      'hafs:2:255:3-2:255:7',
    );
    for (final source in [
      'hafs:2:255-2:260',
      'hafs:2:255:3-2:255:7',
      'hafs:1:1-1:1',
      'warsh_2:3:4:5-6:7:8',
    ]) {
      expect(QuranRange.parse(source).toString(), source);
    }
  });

  group('contains', () {
    final ayat = QuranRange.parse('hafs:2:255-2:260');
    final words = QuranRange.parse('hafs:2:255:3-2:256:2');

    test('an ayah range contains its ayat and their words', () {
      expect(ayat.contains(_a('hafs:2:255')), isTrue);
      expect(ayat.contains(_a('hafs:2:258')), isTrue);
      expect(ayat.contains(_a('hafs:2:260')), isTrue);
      expect(ayat.contains(_a('hafs:2:255:1')), isTrue);
      expect(ayat.contains(_a('hafs:2:260:99')), isTrue);
      expect(ayat.contains(_a('hafs:2:254')), isFalse);
      expect(ayat.contains(_a('hafs:2:254:9')), isFalse);
      expect(ayat.contains(_a('hafs:2:261')), isFalse);
      expect(ayat.contains(_a('hafs:2:261:1')), isFalse);
      expect(ayat.contains(_a('hafs:3:255')), isFalse);
    });

    test('a word range contains only the words between its ends', () {
      expect(words.contains(_a('hafs:2:255:3')), isTrue);
      expect(words.contains(_a('hafs:2:255:40')), isTrue);
      expect(words.contains(_a('hafs:2:256:1')), isTrue);
      expect(words.contains(_a('hafs:2:256:2')), isTrue);
      expect(words.contains(_a('hafs:2:255:2')), isFalse);
      expect(words.contains(_a('hafs:2:256:3')), isFalse);
      expect(words.contains(_a('hafs:2:255')), isFalse);
      expect(words.contains(_a('hafs:2:256')), isFalse);
    });

    test('an address in another riwaya is not contained', () {
      expect(ayat.contains(_a('warsh:2:255')), isFalse);
      expect(words.contains(_a('warsh:2:255:3')), isFalse);
    });
  });

  group('compareTo', () {
    test('orders by start, then by end', () {
      final ordered = [
        QuranRange.parse('hafs:1:1-1:7'),
        QuranRange.parse('hafs:2:1-2:5'),
        QuranRange.parse('hafs:2:1-2:9'),
        QuranRange.parse('hafs:2:1-3:1'),
        QuranRange.parse('hafs:2:2-2:3'),
      ];
      expect([...ordered.reversed]..sort(), ordered);
      expect(ordered[1].compareTo(QuranRange.parse('hafs:2:1-2:5')), 0);
    });

    test('throws across riwayat', () {
      expect(
        () => QuranRange.parse(
          'hafs:1:1-1:2',
        ).compareTo(QuranRange.parse('warsh:1:1-1:2')),
        throwsArgumentError,
      );
    });
  });

  test('equality and hash code are by value', () {
    expect(
      QuranRange.parse('hafs:2:255-2:260'),
      QuranRange(_a('hafs:2:255'), _a('hafs:2:260')),
    );
    expect(
      QuranRange.parse('hafs:2:255-2:260').hashCode,
      QuranRange(_a('hafs:2:255'), _a('hafs:2:260')).hashCode,
    );
    expect(
      QuranRange.parse('hafs:2:255-2:260'),
      isNot(QuranRange.parse('hafs:2:255-2:261')),
    );
    expect(
      QuranRange.parse('hafs:2:255-2:260'),
      isNot(QuranRange.parse('hafs:2:254-2:260')),
    );
  });
}
