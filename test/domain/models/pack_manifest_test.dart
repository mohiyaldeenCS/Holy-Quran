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

  test('PackCounts has no search forms unless given, and keeps them '
      'unmodifiable', () {
    PackCounts counts([Map<String, int>? searchForms]) => searchForms == null
        ? PackCounts(
            surahs: 1,
            ayat: 1,
            words: 2,
            marks: 0,
            divisions: const {},
            sajdas: 0,
          )
        : PackCounts(
            surahs: 1,
            ayat: 1,
            words: 2,
            marks: 0,
            divisions: const {},
            sajdas: 0,
            searchForms: searchForms,
          );
    expect(counts().searchForms, isEmpty);
    final given = {'synthetic': 2};
    final withForms = counts(given).searchForms;
    given['synthetic-later'] = 2;
    expect(withForms, {'synthetic': 2});
    expect(() => withForms['x'] = 1, throwsUnsupportedError);
  });

  group('PackManifest', () {
    final textCounts = PackCounts(
      surahs: 1,
      ayat: 1,
      words: 1,
      marks: 0,
      divisions: const {},
      sajdas: 0,
    );
    const font = PackFont(family: 'Synthetic', version: '1', sha256: '');
    PackManifest manifest(
      PackKind kind,
      PackKindCounts counts, {
      bool textFields = false,
    }) => PackManifest(
      formatVersion: 2,
      id: 'synthetic',
      kind: kind,
      version: 1,
      changelog: const [],
      riwaya: 'hafs',
      edition: textFields ? 'synthetic-edition' : null,
      font: textFields ? font : null,
      sources: [_source(null)],
      files: const [],
      surahSha256: textFields ? const {1: 'synthetic'} : null,
      counts: counts,
      reviews: const [],
    );

    test('of a text pack gives its edition, font, digests and counts', () {
      final text = manifest(PackKind.text, textCounts, textFields: true);
      expect(text.edition, 'synthetic-edition');
      expect(text.font, same(font));
      expect(text.surahSha256, {1: 'synthetic'});
      expect(text.counts, same(textCounts));
      expect(text.kindCounts, same(textCounts));
      expect(() => text.surahSha256[2] = '', throwsUnsupportedError);
    });

    test('of a tafsir or recitation pack has its own counts and no text '
        'fields', () {
      const tafsirCounts = TafsirCounts(passages: 3);
      const recitationCounts = RecitationCounts(files: 4);
      for (final (kind, counts) in [
        (PackKind.tafsir, tafsirCounts),
        (PackKind.recitation, recitationCounts),
      ]) {
        final other = manifest(kind, counts);
        expect(other.kindCounts, same(counts));
        expect(() => other.edition, throwsStateError, reason: kind.name);
        expect(() => other.font, throwsStateError, reason: kind.name);
        expect(() => other.surahSha256, throwsStateError, reason: kind.name);
        expect(() => other.counts, throwsStateError, reason: kind.name);
      }
      expect(tafsirCounts.passages, 3);
      expect(recitationCounts.files, 4);
    });

    test('refuses fields that do not match its kind', () {
      const tafsirCounts = TafsirCounts(passages: 1);
      for (final (kind, counts, textFields) in [
        (PackKind.text, textCounts, false),
        (PackKind.text, tafsirCounts, true),
        (PackKind.tafsir, tafsirCounts, true),
        (PackKind.tafsir, textCounts, false),
        (PackKind.recitation, tafsirCounts, false),
      ]) {
        expect(
          () => manifest(kind, counts, textFields: textFields),
          throwsArgumentError,
          reason: '$kind $counts $textFields',
        );
      }
    });
  });
}
