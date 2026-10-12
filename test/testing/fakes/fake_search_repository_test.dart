import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_range.dart';
import 'package:holyquran/domain/models/search_hit.dart';
import 'package:holyquran/domain/models/search_query.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_search_repository.dart';

final class _Failed implements Exception {
  const _Failed();
}

final _hit = SearchHit(
  ayah: QuranAddress('hafs', 1, 2),
  matches: [
    QuranRange(QuranAddress('hafs', 1, 2, 1), QuranAddress('hafs', 1, 2, 2)),
  ],
  exact: true,
  gaps: 0,
);

SearchQuery _query(String text) =>
    SearchQuery(text: text, kind: 'synthetic-plain', mode: SearchMode.phrase);

void main() {
  test('answers from its hits by folded words, recording each query', () async {
    final fake = FakeSearchRepository(
      hits: {
        'alpha beta': [_hit],
      },
    );
    final found =
        (await fake.search(_query(' alpha \u064E beta')) as Ok<SearchResults>)
            .value;
    expect(found.hits, [_hit]);
    expect(found.occurrences, 1);
    final none = await fake.search(_query('gamma')) as Ok<SearchResults>;
    expect(none.value.hits, isEmpty);
    expect(
      [for (final q in fake.queries) q.text],
      [' alpha \u064E beta', 'gamma'],
    );
    expect((await fake.formKinds() as Ok<List<String>>).value, [
      'synthetic-plain',
    ]);
  });

  test('fails every call while a failure is set', () async {
    final fake = FakeSearchRepository(failure: const _Failed());
    expect(
      await fake.search(_query('alpha')),
      isA<Failure<SearchResults>>().having(
        (f) => f.error,
        'error',
        const _Failed(),
      ),
    );
    expect(await fake.formKinds(), isA<Failure<List<String>>>());
    fake.failure = null;
    expect(await fake.search(_query('alpha')), isA<Ok<SearchResults>>());
  });
}
