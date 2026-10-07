import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/quran_address.dart';

void main() {
  const max = 2147483647;

  group('constructor', () {
    test('keeps its parts', () {
      final address = QuranAddress('hafs', 2, 255, 3);
      expect(address.riwaya, 'hafs');
      expect(address.surah, 2);
      expect(address.ayah, 255);
      expect(address.word, 3);
    });

    test('has no upper bound below the 32-bit limit', () {
      expect(QuranAddress('hafs', 115, 287).surah, 115);
      expect(QuranAddress('hafs', max, max, max).word, max);
    });

    test('rejects a malformed riwaya', () {
      for (final riwaya in ['', 'Hafs', '1hafs', '_hafs', 'ha-fs', 'ha fs']) {
        expect(
          () => QuranAddress(riwaya, 1, 1),
          throwsArgumentError,
          reason: riwaya,
        );
      }
      expect(QuranAddress('warsh_2', 1, 1).riwaya, 'warsh_2');
    });

    test('accepts a riwaya exactly when riwayaPattern matches it', () {
      for (final riwaya in ['hafs', 'warsh_2', 'q1', '', 'Hafs', '_x', 'a-b']) {
        expect(
          () => QuranAddress(riwaya, 1, 1),
          QuranAddress.riwayaPattern.hasMatch(riwaya)
              ? returnsNormally
              : throwsArgumentError,
          reason: riwaya,
        );
        expect(
          QuranAddress.tryParse('$riwaya:1:1') != null,
          QuranAddress.riwayaPattern.hasMatch(riwaya),
          reason: riwaya,
        );
      }
      expect(QuranAddress.riwayaPattern.pattern, r'^[a-z][a-z0-9_]*$');
    });

    test('rejects numbers that are not positive or exceed the limit', () {
      expect(() => QuranAddress('hafs', 0, 1), throwsArgumentError);
      expect(() => QuranAddress('hafs', 1, 0), throwsArgumentError);
      expect(() => QuranAddress('hafs', 1, 1, 0), throwsArgumentError);
      expect(() => QuranAddress('hafs', -1, 1), throwsArgumentError);
      expect(() => QuranAddress('hafs', max + 1, 1), throwsArgumentError);
      expect(() => QuranAddress('hafs', 1, 1, max + 1), throwsArgumentError);
    });
  });

  group('parse', () {
    test('reads the canonical ayah and word forms', () {
      expect(QuranAddress.parse('hafs:2:255'), QuranAddress('hafs', 2, 255));
      expect(
        QuranAddress.parse('hafs:2:255:3'),
        QuranAddress('hafs', 2, 255, 3),
      );
      expect(QuranAddress.parse('warsh_2:1:1'), QuranAddress('warsh_2', 1, 1));
      expect(
        QuranAddress.parse('hafs:$max:$max:$max'),
        QuranAddress('hafs', max, max, max),
      );
    });

    const malformed = [
      '',
      'hafs',
      'hafs:2',
      'hafs:2:',
      'hafs:2:255:',
      'hafs:2:255:3:1',
      ':2:255',
      'Hafs:2:255',
      'HAFS:2:255',
      '1hafs:2:255',
      'ha-fs:2:255',
      'hafs:0:1',
      'hafs:1:0',
      'hafs:1:1:0',
      'hafs:02:255',
      'hafs:2:0255',
      'hafs:2:255:03',
      'hafs:+2:255',
      'hafs:-2:255',
      'hafs:2:-255',
      'hafs:2.0:255',
      'hafs:2e1:255',
      'hafs:0x2:255',
      ' hafs:2:255',
      'hafs:2:255 ',
      'hafs: 2:255',
      'hafs:2 :255',
      'hafs:2:255\n',
      'hafs::2:255',
      'hafs:2::255',
      'hafs;2:255',
      'hafs:2/255',
      'hafs:\u0662:255',
      'hafs:2:\u0662\u0665\u0665',
      'hafs:\u06F2:255',
      'hafs:\uFF12:255',
      'hafs:2147483648:1',
      'hafs:1:1:2147483648',
      'hafs:99999999999:1',
      'hafs:99999999999999999999999:1',
    ];

    for (final source in malformed) {
      test('rejects ${Uri.encodeComponent(source)}', () {
        expect(QuranAddress.tryParse(source), isNull);
        expect(
          () => QuranAddress.parse(source),
          throwsA(
            isA<FormatException>().having((e) => e.source, 'source', source),
          ),
        );
      });
    }
  });

  test('toString is canonical and round-trips', () {
    for (final address in [
      QuranAddress('hafs', 2, 255),
      QuranAddress('hafs', 2, 255, 3),
      QuranAddress('warsh_2', 1, 7, 12),
      QuranAddress('hafs', max, max, max),
    ]) {
      expect(QuranAddress.parse(address.toString()), address);
    }
    expect(QuranAddress('hafs', 2, 255).toString(), 'hafs:2:255');
    expect(QuranAddress('hafs', 2, 255, 3).toString(), 'hafs:2:255:3');
  });

  test('isWord and ayahAddress', () {
    final ayah = QuranAddress('hafs', 2, 255);
    final word = QuranAddress('hafs', 2, 255, 3);
    expect(ayah.isWord, isFalse);
    expect(word.isWord, isTrue);
    expect(word.ayahAddress, ayah);
    expect(word.ayahAddress.isWord, isFalse);
    expect(ayah.ayahAddress, same(ayah));
  });

  group('compareTo', () {
    test('orders by surah, ayah, then word, an ayah before its words', () {
      final ordered = [
        QuranAddress('hafs', 1, 7, 2),
        QuranAddress('hafs', 2, 9),
        QuranAddress('hafs', 2, 10),
        QuranAddress('hafs', 2, 10, 1),
        QuranAddress('hafs', 2, 10, 2),
        QuranAddress('hafs', 2, 10, 10),
        QuranAddress('hafs', 2, 11),
        QuranAddress('hafs', 10, 1),
      ];
      final shuffled = [...ordered.reversed]..sort();
      expect(shuffled, ordered);
      expect(ordered[3].compareTo(QuranAddress('hafs', 2, 10, 1)), 0);
    });

    test('throws across riwayat', () {
      expect(
        () => QuranAddress('hafs', 1, 1).compareTo(QuranAddress('warsh', 1, 1)),
        throwsArgumentError,
      );
    });
  });

  test('equality and hash code are by value', () {
    expect(QuranAddress('hafs', 2, 255, 3), QuranAddress('hafs', 2, 255, 3));
    expect(
      QuranAddress('hafs', 2, 255, 3).hashCode,
      QuranAddress('hafs', 2, 255, 3).hashCode,
    );
    expect(
      QuranAddress('hafs', 2, 255),
      isNot(QuranAddress('hafs', 2, 255, 1)),
    );
    expect(QuranAddress('hafs', 2, 255), isNot(QuranAddress('warsh', 2, 255)));
    expect(QuranAddress('hafs', 2, 255), isNot(QuranAddress('hafs', 2, 256)));
    expect(QuranAddress('hafs', 2, 255), isNot(QuranAddress('hafs', 3, 255)));
  });
}
