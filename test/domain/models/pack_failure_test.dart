import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/quran_address.dart';

void main() {
  test('every failure names its pack and what failed', () {
    final address = QuranAddress('x', 2, 3);
    final failures = <PackFailure, String>{
      const ManifestUnreadable('p', 'unknown field'):
          'ManifestUnreadable(p): unknown field',
      const SignatureRejected('p'): 'SignatureRejected(p)',
      const UnsupportedPackFormat('p', 9):
          'UnsupportedPackFormat(p): version 9',
      const UnsupportedPackFormat('p', null):
          'UnsupportedPackFormat(p): version null',
      const FileHashMismatch('p', 'text.sqlite'):
          'FileHashMismatch(p): text.sqlite',
      const SurahHashMismatch('p', 4): 'SurahHashMismatch(p): surah 4',
      const TextEncodingRejected('p', 2, 3):
          'TextEncodingRejected(p): surah 2 ayah 3',
      const TextEncodingRejected('p', 2, null):
          'TextEncodingRejected(p): surah 2',
      const PackInconsistent('p', 'counts.ayat'):
          'PackInconsistent(p): counts.ayat',
      AddressNotInPack('p', address): 'AddressNotInPack(p): x:2:3',
      const PackDisabled('p'): 'PackDisabled(p)',
    };
    for (final MapEntry(key: failure, value: text) in failures.entries) {
      expect(failure, isA<Exception>());
      expect(failure.pack, 'p');
      expect(failure.toString(), text);
    }
  });
}
