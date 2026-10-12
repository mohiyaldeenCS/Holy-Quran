import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/search_repository.dart';
import 'package:holyquran/data/services/search_index_service.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_range.dart';
import 'package:holyquran/domain/models/search_form.dart';
import 'package:holyquran/domain/models/search_hit.dart';
import 'package:holyquran/domain/models/search_query.dart';
import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_quran_index_repository.dart';

// Every form is synthetic: Latin placeholder words, never Quran text. The
// ayat are those of the synthetic structure: 4, 3 and 1 ayat, juz 2 from 2:1.

const _kind = 'synthetic-plain';

const _ayat = {
  (1, 1): ['alpha', 'beta'],
  (1, 2): ['beta', 'alpha'],
  (1, 3): ['alpha', 'other', 'beta'],
  (1, 4): ['gamma'],
  (2, 1): ['alpha', 'beta', 'alpha', 'beta'],
  (2, 2): ['other'],
  (2, 3): ['beta', 'delta', 'alpha'],
  (3, 1): ['alpha', 'beta'],
};

SearchIndex _index() => SearchIndex.fromForms('synthetic-text', [
  for (final MapEntry(key: (surah, ayah), value: words) in _ayat.entries)
    for (final (i, word) in words.indexed)
      SearchForm(
        word: QuranAddress('hafs', surah, ayah, i + 1),
        kind: _kind,
        form: PackText.fromPack(word),
      ),
]);

QuranAddress _ayah(int surah, int ayah) => QuranAddress('hafs', surah, ayah);

SearchQuery _query(
  String text, {
  SearchMode mode = SearchMode.phrase,
  SearchScope scope = const WholeQuran(),
  String kind = _kind,
}) => SearchQuery(text: text, kind: kind, mode: mode, scope: scope);

void main() {
  late int builds;
  late bool serving;
  late List<Exception> failures;
  late Result<SearchIndex> built;
  late PackSearchRepository repository;

  setUp(() {
    builds = 0;
    serving = true;
    failures = [];
    built = Ok(_index());
    repository = PackSearchRepository(
      pack: 'synthetic-text',
      build: () async {
        builds++;
        return built;
      },
      structure: FakeQuranIndexRepository.synthetic(),
      serving: () => serving,
      onFailed: failures.add,
    );
  });

  Future<SearchResults> search(SearchQuery query) async =>
      (await repository.search(query) as Ok<SearchResults>).value;

  List<QuranAddress> ayatOf(Iterable<SearchHit> hits) => [
    for (final hit in hits) hit.ayah,
  ];

  test('lists the form kinds of the pack', () async {
    expect(await repository.formKinds(), isA<Ok<List<String>>>());
    expect((await repository.formKinds() as Ok<List<String>>).value, [_kind]);
  });

  test('counts occurrences and ayat, hits in mushaf order', () async {
    final results = await search(_query('alpha beta'));
    expect(ayatOf(results.hits), [_ayah(1, 1), _ayah(2, 1), _ayah(3, 1)]);
    expect(results.occurrences, 4);
    expect(results.ayat, 3);
    expect(results.query.text, 'alpha beta');
  });

  test('a query with no words finds nothing', () async {
    final results = await search(_query(' \t'));
    expect(results.hits, isEmpty);
    expect(results.occurrences, 0);
  });

  group('scope', () {
    test('a surah', () async {
      final results = await search(
        _query('alpha beta', scope: const SurahScope(2)),
      );
      expect(ayatOf(results.hits), [_ayah(2, 1)]);
    });

    test('a juz, up to the ayah before the next juz', () async {
      final first = await search(_query('alpha', scope: const JuzScope(1)));
      expect(ayatOf(first.hits), [_ayah(1, 1), _ayah(1, 2), _ayah(1, 3)]);
    });

    test('the last juz, up to the last ayah', () async {
      final last = await search(_query('alpha', scope: const JuzScope(2)));
      expect(ayatOf(last.hits), [_ayah(2, 1), _ayah(2, 3), _ayah(3, 1)]);
    });

    test('a juz that starts inside a surah', () async {
      final synthetic = FakeQuranIndexRepository.synthetic();
      final split = PackSearchRepository(
        pack: 'synthetic-text',
        build: () async => Ok(_index()),
        structure: FakeQuranIndexRepository(
          surahs: synthetic.surahs,
          map: EditionMap(
            edition: 'synthetic-edition',
            starts: {
              Division.juz: [_ayah(1, 1), _ayah(1, 3), _ayah(2, 2)],
              Division.page: [_ayah(1, 1)],
            },
            sajdas: const {},
          ),
        ),
        serving: () => true,
      );
      Future<List<QuranAddress>> found(String text, int juz) async => ayatOf(
        (await split.search(_query(text, scope: JuzScope(juz)))
                as Ok<SearchResults>)
            .value
            .hits,
      );
      expect(await found('alpha', 1), [_ayah(1, 1), _ayah(1, 2)]);
      expect(await found('alpha', 2), [_ayah(1, 3), _ayah(2, 1)]);
      expect(await found('gamma', 2), [_ayah(1, 4)]);
      expect(await found('other', 3), [_ayah(2, 2)]);
      expect(await found('alpha', 3), [_ayah(2, 3), _ayah(3, 1)]);
    });

    test('a surah or juz outside the edition is an argument error', () {
      expect(
        repository.search(_query('alpha', scope: const SurahScope(4))),
        throwsArgumentError,
      );
      expect(
        repository.search(_query('alpha', scope: const JuzScope(3))),
        throwsArgumentError,
      );
    });
  });

  group('order', () {
    late SearchResults results;

    setUp(() async {
      results = await search(_query('alpha beta', mode: SearchMode.scattered));
    });

    test('mushaf', () {
      expect(ayatOf(results.ordered(SearchOrder.mushaf)), [
        _ayah(1, 1),
        _ayah(1, 2),
        _ayah(1, 3),
        _ayah(2, 1),
        _ayah(2, 3),
        _ayah(3, 1),
      ]);
    });

    test('closeness: in order and together, then fewer words between', () {
      expect(ayatOf(results.ordered(SearchOrder.closeness)), [
        _ayah(1, 1),
        _ayah(2, 1),
        _ayah(3, 1),
        _ayah(1, 2),
        _ayah(1, 3),
        _ayah(2, 3),
      ]);
    });

    test('frequency: most occurrences first, then mushaf', () {
      expect(ayatOf(results.ordered(SearchOrder.frequency)), [
        _ayah(2, 1),
        _ayah(1, 1),
        _ayah(1, 2),
        _ayah(1, 3),
        _ayah(2, 3),
        _ayah(3, 1),
      ]);
    });
  });

  test('matches are word ranges of the ayah', () async {
    final hit = (await search(_query('alpha beta'))).hits[1];
    expect(hit.matches, [
      QuranRange(QuranAddress('hafs', 2, 1, 1), QuranAddress('hafs', 2, 1, 2)),
      QuranRange(QuranAddress('hafs', 2, 1, 3), QuranAddress('hafs', 2, 1, 4)),
    ]);
  });

  test('builds the index once', () async {
    await repository.formKinds();
    await search(_query('alpha'));
    await search(_query('beta'));
    expect(builds, 1);
  });

  test('a form kind the pack does not provide is an argument error', () {
    expect(
      repository.search(_query('alpha', kind: 'absent')),
      throwsArgumentError,
    );
  });

  test('a pack that is not serving fails with PackDisabled', () async {
    serving = false;
    expect(
      await repository.search(_query('alpha')),
      isA<Failure<SearchResults>>().having(
        (f) => f.error,
        'error',
        isA<PackDisabled>().having((f) => f.pack, 'pack', 'synthetic-text'),
      ),
    );
    expect(await repository.formKinds(), isA<Failure<List<String>>>());
    expect(builds, 0);
  });

  test('a failed build fails every call and is reported once', () async {
    const failure = PackInconsistent('synthetic-text', 'synthetic');
    built = const Failure(failure);
    for (var i = 0; i < 2; i++) {
      expect(
        await repository.search(_query('alpha')),
        isA<Failure<SearchResults>>().having((f) => f.error, 'error', failure),
      );
    }
    expect(await repository.formKinds(), isA<Failure<List<String>>>());
    expect(failures, [failure]);
    expect(builds, 1);
  });

  group('the 300 ms budget (NF-03)', () {
    // A full-size synthetic Quran: 6,236 ayat in 114 surahs and 30 juz, of
    // about 78,000 placeholder words drawn log-uniformly from 14,000, so that
    // the first few are very frequent, as the commonest words are.
    const budget = Duration(milliseconds: 300);
    final ayatPerSurah = [...List.filled(110, 55), 46, 46, 47, 47];
    late PackSearchRepository full;
    late List<String> longAyah;

    setUpAll(() async {
      final random = Random(1);
      String word() => 'w${(pow(14001, random.nextDouble()) - 1).floor()}';
      final forms = <SearchForm>[];
      final ayat = <QuranAddress>[];
      longAyah = [];
      for (final (s, count) in ayatPerSurah.indexed) {
        for (var a = 1; a <= count; a++) {
          final words = [for (var w = random.nextInt(24); w >= 0; w--) word()];
          if (words.length > longAyah.length) longAyah = words;
          ayat.add(_ayah(s + 1, a));
          for (final (i, form) in words.indexed) {
            for (final kind in [_kind, 'synthetic_spelled']) {
              forms.add(
                SearchForm(
                  word: QuranAddress('hafs', s + 1, a, i + 1),
                  kind: kind,
                  form: PackText.fromPack(form),
                ),
              );
            }
          }
        }
      }
      expect(ayat.length, 6236);
      final stopwatch = Stopwatch()..start();
      final index = SearchIndex.fromForms('synthetic-text', forms);
      debugPrint(
        'NF-03: index of ${ayat.length} ayat, ${index.count(_kind)} words '
        'per kind, 2 kinds, built in ${stopwatch.elapsedMilliseconds} ms',
      );
      full = PackSearchRepository(
        pack: 'synthetic-text',
        build: () async => Ok(index),
        structure: FakeQuranIndexRepository(
          surahs: [
            for (final (s, count) in ayatPerSurah.indexed)
              SurahInfo(
                number: s + 1,
                name: PackText.fromPack('Synthetic surah ${s + 1}'),
                ayahCount: count,
              ),
          ],
          map: EditionMap(
            edition: 'synthetic-edition',
            starts: {
              Division.juz: [for (var j = 0; j < 30; j++) ayat[j * 207]],
              Division.page: [ayat.first],
            },
            sajdas: const {},
          ),
        ),
        serving: () => true,
      );
      await full.formKinds();
    });

    Future<void> answersWithin(SearchQuery query, SearchOrder order) async {
      final stopwatch = Stopwatch()..start();
      final results = (await full.search(query) as Ok<SearchResults>).value;
      final ordered = results.ordered(order);
      final elapsed = stopwatch.elapsed;
      debugPrint(
        'NF-03: ${query.mode.name} "${query.text}" in ${query.scope}, '
        '${order.name}: ${results.ayat} ayat, ${results.occurrences} '
        'occurrences in ${elapsed.inMicroseconds / 1000} ms',
      );
      expect(ordered, isNotEmpty);
      expect(elapsed, lessThan(budget));
    }

    test('the commonest phrase', () async {
      await answersWithin(_query('w0 w1'), SearchOrder.frequency);
    });

    test('the commonest scattered words, nearest first', () async {
      await answersWithin(
        _query('w2 w0 w1', mode: SearchMode.scattered),
        SearchOrder.closeness,
      );
    });

    test('the longest whole ayah', () async {
      await answersWithin(
        _query(longAyah.join(' '), mode: SearchMode.wholeAyah),
        SearchOrder.mushaf,
      );
    });

    test('a common word within a juz', () async {
      await answersWithin(
        _query('w0', scope: const JuzScope(30)),
        SearchOrder.frequency,
      );
    });
  });
}
