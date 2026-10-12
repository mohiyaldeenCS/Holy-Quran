import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_range.dart';
import 'package:holyquran/domain/models/search_hit.dart';
import 'package:holyquran/domain/models/search_match.dart';
import 'package:holyquran/domain/models/tafsir_passage.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_tafsir_search_repository.dart';

final class _Failed implements Exception {
  const _Failed();
}

TafsirHit _hit(String book) => TafsirHit(
  book: book,
  passage: TafsirPassage(
    number: 1,
    range: QuranRange(QuranAddress('hafs', 1, 1), QuranAddress('hafs', 1, 2)),
    text: const PackText.fromPack('Synthetic passage'),
  ),
  matches: const [SearchMatch(start: 0, end: 9)],
);

void main() {
  final a = _hit('synthetic-a');
  final b = _hit('synthetic-b');

  test(
    'answers from its hits, kept to the books asked for, in order',
    () async {
      final fake = FakeTafsirSearchRepository(
        hits: {
          'Synthetic': [a, b],
        },
      );
      Future<List<TafsirHit>> search(String query, List<String> books) async =>
          (await fake.search(query, books) as Ok<List<TafsirHit>>).value;
      expect(await search('Synthetic', ['synthetic-b', 'synthetic-a']), [b, a]);
      expect(await search('Synthetic', ['synthetic-a']), [a]);
      expect(await search('other', ['synthetic-a']), isEmpty);
      expect(fake.searches.first.$1, 'Synthetic');
      expect(fake.searches.first.$2, ['synthetic-b', 'synthetic-a']);
    },
  );

  test('fails every call while a failure is set', () async {
    final fake = FakeTafsirSearchRepository(failure: const _Failed());
    expect(
      await fake.search('Synthetic', ['synthetic-a']),
      isA<Failure<List<TafsirHit>>>().having(
        (f) => f.error,
        'error',
        const _Failed(),
      ),
    );
  });
}
