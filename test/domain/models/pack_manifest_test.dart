import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';

PackSource _source(Map<String, Object>? options) => PackSource(
  role: SourceRole.text,
  registryRow: 1,
  name: 'Synthetic source',
  publisher: 'Synthetic publisher',
  url: 'https://example.invalid/synthetic',
  version: '1',
  fetchedOn: '2026-01-01',
  fileSha256: '0' * 64,
  trustGrade: TrustGrade.a,
  options: options,
  licence: const PackLicence(
    text: null,
    permissionRef: 'Synthetic permission',
    notice: null,
    allowsExport: true,
  ),
);

void main() {
  group('PackSource options', () {
    test('may be null', () {
      expect(_source(null).options, isNull);
    });

    test('hold strings, numbers and booleans, unmodifiable', () {
      final given = <String, Object>{
        'synthetic text': 'synthetic',
        'synthetic count': 2,
        'synthetic ratio': 0.5,
        'synthetic flag': false,
      };
      final options = _source(given).options!;
      expect(options, given);
      given['synthetic later'] = 'x';
      expect(options, hasLength(4));
      expect(() => options['synthetic'] = 'x', throwsUnsupportedError);
    });

    test('refuse any other value', () {
      for (final value in <Object>[
        <Object>[],
        <String, Object>{},
        DateTime.utc(2026),
      ]) {
        expect(
          () => _source({'synthetic': value}),
          throwsArgumentError,
          reason: '$value',
        );
      }
    });
  });

  test('PackCounts carries the marks', () {
    final counts = PackCounts(
      surahs: 1,
      ayat: 2,
      words: 3,
      marks: 4,
      divisions: {Division.page: 1},
      sajdas: 0,
    );
    expect(counts.marks, 4);
    expect(() => counts.divisions[Division.juz] = 1, throwsUnsupportedError);
  });
}
