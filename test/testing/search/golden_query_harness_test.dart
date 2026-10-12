import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/search_repository.dart';
import 'package:holyquran/data/services/search_index_service.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/search_form.dart';
import 'package:holyquran/domain/models/search_hit.dart';
import 'package:holyquran/domain/models/search_query.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_quran_index_repository.dart';
import '../../../testing/search/golden_query_harness.dart';

// A synthetic golden set over synthetic forms: Latin placeholder words,
// never Quran text, with counts worked out by hand.

const _kind = 'synthetic-plain';

const _ayat = {
  (1, 1): ['alpha', 'beta'],
  (1, 2): ['beta', 'alpha', 'beta'],
  (1, 3): ['gamma'],
  (1, 4): ['alpha', 'gamma'],
  (2, 1): ['alpha', 'beta', 'alpha', 'beta'],
  (2, 2): ['delta'],
  (2, 3): ['beta'],
  (3, 1): ['gamma', 'alpha', 'beta'],
};

const _golden = '''
alpha\t6
alpha beta\t5

beta alpha\t2
gamma alpha beta\t1
delta\t1
epsilon\t0
''';

void main() {
  late SearchRepository repository;

  setUp(() {
    final index = SearchIndex.fromForms('synthetic-text', [
      for (final MapEntry(key: (surah, ayah), value: words) in _ayat.entries)
        for (final (i, word) in words.indexed)
          SearchForm(
            word: QuranAddress('hafs', surah, ayah, i + 1),
            kind: _kind,
            form: PackText.fromPack(word),
          ),
    ]);
    repository = PackSearchRepository(
      pack: 'synthetic-text',
      build: () async => Ok(index),
      structure: FakeQuranIndexRepository.synthetic(),
      serving: () => true,
    );
  });

  Future<Result<SearchResults>> phrase(String query) => repository.search(
    SearchQuery(text: query, kind: _kind, mode: SearchMode.phrase),
  );

  test('reads one query and its count per line, skipping blank lines', () {
    final queries = parseGoldenQueries(_golden);
    expect(queries.length, 6);
    expect(queries.first, (line: 1, query: 'alpha', expected: 6));
    expect(queries[2], (line: 4, query: 'beta alpha', expected: 2));
  });

  test('refuses a malformed line, naming it', () {
    for (final source in [
      'alpha',
      'alpha\tsix',
      'alpha\t-1',
      'alpha\t1\t2',
      ' \t1',
    ]) {
      expect(
        () => parseGoldenQueries('beta\t1\n$source'),
        throwsA(isA<FormatException>().having((e) => e.offset, 'line', 2)),
        reason: source,
      );
    }
  });

  test('the synthetic golden set matches exactly', () async {
    expect(
      await runGoldenQueries(parseGoldenQueries(_golden), phrase),
      isEmpty,
    );
  });

  test('reports every mismatch, in file order', () async {
    final mismatches = await runGoldenQueries(
      parseGoldenQueries('alpha\t5\nbeta\t7\ngamma\t4\n'),
      phrase,
    );
    expect(
      [for (final m in mismatches) m.toString()],
      [
        'line 1: "alpha" expected 5, found 6',
        'line 3: "gamma" expected 4, found 3',
      ],
    );
  });

  test('reports a failed search', () async {
    const failure = PackDisabled('synthetic-text');
    final mismatches = await runGoldenQueries(
      parseGoldenQueries('alpha\t6\n'),
      (_) async => const Failure(failure),
    );
    expect(mismatches.single.error, failure);
    expect(
      mismatches.single.toString(),
      'line 1: "alpha" expected 6, failed with $failure',
    );
  });
}
