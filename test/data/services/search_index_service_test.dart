import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/models/pack_manifest_json.dart';
import 'package:holyquran/data/services/search_index_service.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_range.dart';
import 'package:holyquran/domain/models/search_form.dart';
import 'package:holyquran/domain/models/search_hit.dart';
import 'package:holyquran/domain/models/search_query.dart';
import 'package:holyquran/domain/models/verified_pack.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/packs/synthetic_pack.dart';

// Every form is synthetic: Latin placeholder words, never Quran text.

const _kind = 'synthetic-plain';

QuranAddress _ayah(int surah, int ayah) => QuranAddress('hafs', surah, ayah);

QuranRange _words(int surah, int ayah, int first, int last) => QuranRange(
  QuranAddress('hafs', surah, ayah, first),
  QuranAddress('hafs', surah, ayah, last),
);

/// The forms of [kind] for each ayah, keyed `(surah, ayah)`, in key order.
List<SearchForm> _forms(
  Map<(int, int), List<String>> ayat, {
  String kind = _kind,
}) => [
  for (final MapEntry(key: (surah, ayah), value: words) in ayat.entries)
    for (final (i, word) in words.indexed)
      SearchForm(
        word: QuranAddress('hafs', surah, ayah, i + 1),
        kind: kind,
        form: PackText.fromPack(word),
      ),
];

final _ayat = {
  (1, 1): ['alpha', 'beta', 'gamma'],
  (1, 2): ['beta', 'alpha', 'delta', 'alpha', 'beta', 'alpha', 'beta'],
  (1, 3): ['gamma', 'epsilon', 'beta', 'zeta', 'alpha'],
  (2, 1): ['alpha', 'beta'],
  (2, 2): ['alphabet', 'alp', 'beta gamma', 'delta'],
};

void main() {
  final index = SearchIndex.fromForms('p', [
    ..._forms(_ayat),
    ..._forms({
      (1, 1): ['other', 'kind', 'here'],
    }, kind: 'synthetic_spelled'),
  ]);

  List<SearchHit> search(String query, SearchMode mode, {QuranRange? within}) =>
      index.search(
        _kind,
        SearchQuery(text: query, kind: _kind, mode: mode).words,
        mode,
        within: within,
      );

  List<QuranAddress> ayatOf(List<SearchHit> hits) => [
    for (final hit in hits) hit.ayah,
  ];

  group('fromForms', () {
    test('holds each kind and counts its forms', () {
      expect(index.kinds, ['synthetic-plain', 'synthetic_spelled']);
      expect(index.count(_kind), 21);
      expect(index.count('synthetic_spelled'), 3);
      expect(index.count('absent'), 0);
    });

    test('refuses forms out of mushaf order', () {
      final forms = _forms({
        (1, 2): ['a'],
        (1, 1): ['b'],
      });
      expect(
        () => SearchIndex.fromForms('p', forms),
        throwsA(isA<PackInconsistent>().having((f) => f.pack, 'pack', 'p')),
      );
    });

    test('refuses a word with no form, or a form given twice', () {
      final gap = _forms({
        (1, 1): ['a', 'b', 'c'],
      })..removeAt(1);
      final twice =
          _forms({
            (1, 1): ['a', 'b'],
          })..insert(
            1,
            _forms({
              (1, 1): ['a'],
            }).single,
          );
      final late = _forms({
        (1, 1): ['a', 'b'],
      })..removeAt(0);
      for (final forms in [gap, twice, late]) {
        expect(
          () => SearchIndex.fromForms('p', forms),
          throwsA(isA<PackInconsistent>()),
        );
      }
    });
  });

  group('search', () {
    test('whole ayah: the words are the whole ayah, in order', () {
      final hits = search('alpha beta', SearchMode.wholeAyah);
      expect(ayatOf(hits), [_ayah(2, 1)]);
      expect(hits.single.matches, [_words(2, 1, 1, 2)]);
      expect(hits.single.exact, isTrue);
      expect(search('beta alpha', SearchMode.wholeAyah), isEmpty);
      expect(
        search('alpha beta gamma', SearchMode.wholeAyah).single.ayah,
        _ayah(1, 1),
      );
    });

    test('phrase: every occurrence of consecutive words, not overlapping', () {
      final hits = search('alpha beta', SearchMode.phrase);
      expect(ayatOf(hits), [_ayah(1, 1), _ayah(1, 2), _ayah(2, 1)]);
      expect(hits[1].matches, [_words(1, 2, 4, 5), _words(1, 2, 6, 7)]);
      expect(hits[1].occurrences, 2);
      expect(hits.every((hit) => hit.exact && hit.gaps == 0), isTrue);
      expect(search('beta alpha beta', SearchMode.phrase)[0].matches, [
        _words(1, 2, 5, 7),
      ]);
    });

    test('phrase: never across two ayat', () {
      expect(search('gamma beta', SearchMode.phrase), isEmpty);
    });

    test('scattered: each word anywhere in one ayah, in any order', () {
      final hits = search('gamma alpha', SearchMode.scattered);
      expect(ayatOf(hits), [_ayah(1, 1), _ayah(1, 3)]);
      expect(hits[0].matches, [_words(1, 1, 1, 1), _words(1, 1, 3, 3)]);
      expect(hits[1].matches, [_words(1, 3, 1, 1), _words(1, 3, 5, 5)]);
      expect(search('zeta delta', SearchMode.scattered), isEmpty);
    });

    test('scattered: exactness and the fewest words between', () {
      final apart = search('alpha gamma', SearchMode.scattered);
      expect(
        [for (final hit in apart) (hit.exact, hit.gaps)],
        [(false, 1), (false, 3)],
      );
      final together = search('beta alpha', SearchMode.scattered);
      expect(ayatOf(together), [
        _ayah(1, 1),
        _ayah(1, 2),
        _ayah(1, 3),
        _ayah(2, 1),
      ]);
      expect(
        [for (final hit in together) (hit.exact, hit.gaps)],
        [(false, 0), (true, 0), (false, 1), (false, 0)],
      );
      expect(together[1].occurrences, 6);
    });

    test('a word matches only a whole form, exactly as stored', () {
      expect(search('alp', SearchMode.phrase).single.matches, [
        _words(2, 2, 2, 2),
      ]);
      expect(search('alph', SearchMode.phrase), isEmpty);
      expect(search('Alpha', SearchMode.phrase), isEmpty);
      expect(search('alphabet', SearchMode.phrase).single.ayah, _ayah(2, 2));
    });

    test('a form holding a space stands for that many words', () {
      expect(search('beta gamma', SearchMode.phrase).map((h) => h.matches), [
        [_words(1, 1, 2, 3)],
        [_words(2, 2, 3, 3)],
      ]);
      expect(search('alp beta gamma delta', SearchMode.phrase)[0].matches, [
        _words(2, 2, 2, 4),
      ]);
      expect(
        search('alphabet alp beta gamma delta', SearchMode.wholeAyah).single,
        isA<SearchHit>().having((h) => h.matches, 'matches', [
          _words(2, 2, 1, 4),
        ]),
      );
      expect(search('delta gamma', SearchMode.scattered), isEmpty);
      final scattered = search('delta beta gamma', SearchMode.scattered);
      expect(ayatOf(scattered), [_ayah(2, 2)]);
      expect(scattered.single.matches, [
        _words(2, 2, 3, 3),
        _words(2, 2, 4, 4),
      ]);
      expect(
        search('beta', SearchMode.phrase).map((h) => h.ayah),
        isNot(contains(_ayah(2, 2))),
      );
    });

    test('keeps to the range it is given', () {
      final within = QuranRange(_ayah(1, 2), _ayah(2, 1));
      expect(ayatOf(search('alpha beta', SearchMode.phrase, within: within)), [
        _ayah(1, 2),
        _ayah(2, 1),
      ]);
    });

    test('a query with no words finds nothing', () {
      expect(index.search(_kind, const [], SearchMode.phrase), isEmpty);
    });

    test('refuses a kind it does not hold', () {
      expect(
        () => index.search('absent', const ['alpha'], SearchMode.phrase),
        throwsArgumentError,
      );
    });
  });

  group('SearchIndexService', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('search_index'));
    tearDown(() => root.deleteSync(recursive: true));

    VerifiedPack verified(SyntheticPack pack) => VerifiedPack(
      directory: pack.directory.path,
      manifest:
          (parsePackManifest(pack.manifestFile.readAsBytesSync(), pack: 'p')
                  as Ok<PackManifest>)
              .value,
      signatureChecked: false,
    );

    Future<Result<SearchIndex>> build(SyntheticPack pack) =>
        SearchIndexService(verified(pack)).build();

    test(
      'builds the index of every stored form, off the main isolate',
      () async {
        final pack = await buildSyntheticPack(root, formatVersion: 2);
        final built = (await build(pack) as Ok<SearchIndex>).value;
        expect(built.kinds, defaultSyntheticSearchFormKinds);
        for (final kind in built.kinds) {
          expect(
            built.count(kind),
            pack.searchForms.where((form) => form.kind == kind).length,
          );
        }
        // A stored form of several words is found by those words.
        final stored = pack.searchForms.firstWhere(
          (form) => form.surah == 2 && form.ayah == 3 && form.word == 1,
        );
        final query = SearchQuery(
          text: stored.form,
          kind: stored.kind,
          mode: SearchMode.phrase,
        );
        expect(query.words.length, greaterThan(1));
        final hits = built.search(stored.kind, query.words, query.mode);
        expect(hits.single.matches, [_words(2, 3, 1, 1)]);
      },
    );

    test('a format 1 pack holds no kinds', () async {
      // Format 1, the synthetic default, has no search_form table.
      final pack = await buildSyntheticPack(root);
      expect((await build(pack) as Ok<SearchIndex>).value.kinds, isEmpty);
    });

    test('a missing form is an inconsistency of the pack', () async {
      final pack = await buildSyntheticPack(
        root,
        formatVersion: 2,
        searchFormFault: SyntheticSearchFormFault.missing,
      );
      expect(
        await build(pack),
        isA<Failure<SearchIndex>>().having(
          (f) => f.error,
          'error',
          isA<PackInconsistent>().having(
            (f) => f.pack,
            'pack',
            'synthetic-text',
          ),
        ),
      );
    });

    test('a kind the manifest does not count is an inconsistency', () async {
      final pack = await buildSyntheticPack(
        root,
        formatVersion: 2,
        searchFormFault: SyntheticSearchFormFault.unlistedKind,
      );
      expect(
        await build(pack),
        isA<Failure<SearchIndex>>().having(
          (f) => f.error,
          'error',
          isA<PackInconsistent>(),
        ),
      );
    });

    test('a pack whose file is missing fails, naming the pack', () async {
      final pack = await buildSyntheticPack(
        root,
        fault: SyntheticFault.missingFile,
      );
      expect(
        await build(pack),
        isA<Failure<SearchIndex>>().having(
          (f) => f.error,
          'error',
          isA<FileHashMismatch>().having(
            (f) => f.pack,
            'pack',
            'synthetic-text',
          ),
        ),
      );
    });
  });
}
