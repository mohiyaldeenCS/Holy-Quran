import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/go_to_error.dart';
import 'package:holyquran/domain/models/go_to_target.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/search_hit.dart';
import 'package:holyquran/domain/models/search_match.dart';
import 'package:holyquran/domain/models/search_query.dart';
import 'package:holyquran/domain/models/word_span.dart';
import 'package:holyquran/ui/features/search/view_models/search_view_model.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../testing/fakes/fake_address_input_repository.dart';
import '../../../../testing/fakes/fake_search_history_repository.dart';
import '../../../../testing/fakes/fake_search_repository.dart';
import '../index/index_fixture.dart';
import 'search_fixture.dart';

typedef _Opened = ({
  SearchViewModel viewModel,
  FakeSearchRepository search,
  FakeSearchHistoryRepository history,
});

void main() {
  late Directory root;
  late IndexFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('search_view_model_test');
    fixture = await IndexFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  Future<_Opened> open({
    List<String> kinds = const [SearchKinds.word, SearchKinds.bare],
    List<SearchHit>? hits,
    FakeSearchHistoryRepository? history,
  }) async {
    final search = FakeSearchRepository(
      kinds: kinds,
      hits: {
        query: hits ?? [hit(fixture, 2, 3), hit(fixture, 2, 12)],
      },
    );
    final stored = history ?? FakeSearchHistoryRepository();
    final viewModel = SearchViewModel(
      search: search,
      text: fixture.text,
      index: fixture.index,
      words: jumpWords,
      addresses: FakeAddressInputRepository(names: {'named': 2}),
      history: stored,
    );
    addTearDown(viewModel.dispose);
    await viewModel.load();
    return (viewModel: viewModel, search: search, history: stored);
  }

  group('the chips', () {
    test('are the kinds the pack has data for, in the chips order', () async {
      final both = await open(
        kinds: ['other', SearchKinds.bare, SearchKinds.word],
      );
      expect(both.viewModel.kinds, [SearchKinds.word, SearchKinds.bare]);
      final one = await open(kinds: [SearchKinds.bare]);
      expect(one.viewModel.kinds, [SearchKinds.bare]);
      final none = await open(kinds: ['other']);
      expect(none.viewModel.kinds, isEmpty);
    });

    test('choosing one searches again with its kind', () async {
      final it = await open();
      await it.viewModel.submit(query);
      await it.viewModel.selectKind(1);

      expect(
        [for (final q in it.search.queries) q.kind],
        [SearchKinds.word, SearchKinds.bare],
      );
    });

    test('a pack with no kind of its own searches nothing', () async {
      final it = await open(kinds: ['other']);
      await it.viewModel.submit(query);

      expect(it.search.queries, isEmpty);
      expect(it.viewModel.searched, isFalse);
    });
  });

  group('a search', () {
    test('counts the places and the ayat, and records the query', () async {
      final it = await open(
        hits: [
          hit(fixture, 2, 3, ranges: [(2, 3), (5, 5)]),
          hit(fixture, 2, 12),
        ],
      );
      expect(await it.viewModel.submit('  $query '), isNull);

      expect(it.viewModel.query, query);
      expect(it.viewModel.occurrences, 3);
      expect(it.viewModel.ayat, 2);
      expect(it.search.queries.single.mode, SearchMode.scattered);
      expect(it.viewModel.history, [query]);
    });

    test('with no hit says so by counting none', () async {
      final it = await open(hits: const []);
      await it.viewModel.submit(query);

      expect(it.viewModel.searched, isTrue);
      expect(it.viewModel.ayat, 0);
      expect(it.viewModel.cardCount, 0);
    });

    test('emptying the field forgets the results, not the history', () async {
      final it = await open();
      await it.viewModel.submit(query);
      it.viewModel.edit('');

      expect(it.viewModel.searched, isFalse);
      expect(it.viewModel.history, [query]);
    });

    test('a failed search shows no results', () async {
      final it = await open();
      it.search.failure = Exception('broken');
      await it.viewModel.submit(query);

      expect(it.viewModel.searched, isFalse);
    });
  });

  group('the order', () {
    final hits = [
      (surah: 2, ayah: 3, exact: false, gaps: 2, ranges: [(2, 2)]),
      (surah: 2, ayah: 5, exact: true, gaps: 0, ranges: [(2, 3), (5, 6)]),
      (surah: 2, ayah: 7, exact: false, gaps: 1, ranges: [(2, 2), (4, 4)]),
      (surah: 3, ayah: 1, exact: true, gaps: 0, ranges: [(2, 3)]),
    ];

    Future<SearchViewModel> opened() async {
      final it = await open(
        hits: [
          for (final h in hits)
            hit(
              fixture,
              h.surah,
              h.ayah,
              exact: h.exact,
              gaps: h.gaps,
              ranges: h.ranges,
            ),
        ],
      );
      await it.viewModel.submit(query);
      return it.viewModel;
    }

    List<String> shown(SearchViewModel viewModel) => [
      for (var i = 0; i < viewModel.cardCount; i++)
        '${viewModel.ayahAt(i).surah}:${viewModel.ayahAt(i).ayah}',
    ];

    test('starts in mushaf order', () async {
      final viewModel = await opened();

      expect(viewModel.order, SearchOrder.mushaf);
      expect(shown(viewModel), ['2:3', '2:5', '2:7', '3:1']);
    });

    test('goes to the nearest, the most frequent, then round', () async {
      final viewModel = await opened();

      viewModel.nextOrder();
      expect(viewModel.order, SearchOrder.closeness);
      expect(shown(viewModel), ['2:5', '3:1', '2:7', '2:3']);
      viewModel.nextOrder();
      expect(viewModel.order, SearchOrder.frequency);
      expect(shown(viewModel), ['2:5', '2:7', '2:3', '3:1']);
      viewModel.nextOrder();
      expect(viewModel.order, SearchOrder.mushaf);
    });
  });

  group('the scope', () {
    test('is the whole Quran until a surah or a juz is chosen', () async {
      final it = await open();
      await it.viewModel.submit(query);

      expect(it.search.queries.single.scope, const WholeQuran());
    });

    test('a surah or a juz is searched once its number is valid', () async {
      final it = await open();
      await it.viewModel.submit(query);
      await it.viewModel.selectScope(ScopeChoice.surah);
      await it.viewModel.setScopeText('2');
      await it.viewModel.selectScope(ScopeChoice.juz);
      await it.viewModel.setScopeText('٣');

      expect(
        [for (final q in it.search.queries) q.scope],
        [const WholeQuran(), const SurahScope(2), const JuzScope(3)],
      );
    });

    test(
      'a number the edition lacks is refused and searches nothing',
      () async {
        final it = await open();
        await it.viewModel.submit(query);
        await it.viewModel.selectScope(ScopeChoice.surah);
        final before = it.search.queries.length;
        await it.viewModel.setScopeText('115');

        expect(it.viewModel.scopeError, isA<NoSuchSurah>());
        expect(it.viewModel.searched, isFalse);
        expect(it.search.queries, hasLength(before));
        await it.viewModel.selectScope(ScopeChoice.juz);
        await it.viewModel.setScopeText('31');
        expect(it.viewModel.scopeError, isA<DivisionOutOfRange>());
        await it.viewModel.setScopeText('x');
        expect(it.viewModel.scopeError, isA<UnreadableGoTo>());
      },
    );
  });

  group('a card', () {
    test('holds the ayah as the pack stores it, matches as offsets', () async {
      final it = await open(
        hits: [
          hit(fixture, 2, 3, ranges: [(2, 3), (5, 5)]),
        ],
      );
      await it.viewModel.submit(query);
      await it.viewModel.loadCard(0);

      final address = QuranAddress(fixture.index.riwaya, 2, 3);
      final card = it.viewModel.cardAt(0)!;
      final stored =
          (await fixture.text.ayahText(address) as Ok<PackText>).value;
      final spans =
          (await fixture.text.words(address) as Ok<List<WordSpan>>).value;
      expect(card.text, stored);
      expect(card.surahName, fixture.surahs[1].name);
      expect(card.matches, [
        SearchMatch(start: spans[1].start, end: spans[2].end),
        SearchMatch(start: spans[4].start, end: spans[4].end),
      ]);
    });

    test('is not made for an ayah that cannot be read', () async {
      final it = await open(
        hits: [
          SearchHit(
            ayah: QuranAddress(fixture.index.riwaya, 2, 99),
            matches: [hit(fixture, 2, 99).matches.single],
            exact: true,
            gaps: 0,
          ),
        ],
      );
      await it.viewModel.submit(query);
      await it.viewModel.loadCard(0);

      expect(it.viewModel.cardAt(0), isNull);
    });

    test('shown whole stays whole through a new order, not a search', () async {
      final it = await open();
      await it.viewModel.submit(query);
      expect(it.viewModel.isWhole(1), isFalse);
      it.viewModel.showWhole(1);
      it.viewModel.nextOrder();

      expect(it.viewModel.isWhole(1), isTrue);
      await it.viewModel.submit(query);
      expect(it.viewModel.isWhole(1), isFalse);
    });
  });

  group('a place typed in the field', () {
    test('opens the reader there and searches nothing', () async {
      final it = await open();
      final target = await it.viewModel.submit('2:3');

      expect(target, isA<GoToAyah>());
      expect(target!.start, QuranAddress(fixture.index.riwaya, 2, 3));
      expect(it.search.queries, isEmpty);
      expect(it.viewModel.history, isEmpty);
    });

    test('names a surah, a page, a juz or a surah by its name', () async {
      final it = await open();

      expect(
        (await it.viewModel.submit('surah 3'))!.start,
        QuranAddress(fixture.index.riwaya, 3, 1),
      );
      expect(await it.viewModel.submit('page 2'), isA<GoToDivision>());
      expect(
        await it.viewModel.submit('juz ٢'),
        isA<GoToDivision>().having((d) => d.division, 'division', Division.juz),
      );
      expect(
        (await it.viewModel.submit('named 3'))!.start,
        QuranAddress(fixture.index.riwaya, 2, 3),
      );
      expect(it.search.queries, isEmpty);
    });

    test('that the edition lacks is refused, and searches nothing', () async {
      final it = await open();

      expect(await it.viewModel.submit('9:1'), isNull);
      expect(it.viewModel.refusal, isA<NoSuchSurah>());
      expect(await it.viewModel.submit('2:99'), isNull);
      expect(it.viewModel.refusal, isA<NoSuchAyah>());
      expect(it.search.queries, isEmpty);
      await it.viewModel.submit(query);
      expect(it.viewModel.refusal, isNull);
    });
  });

  group('the history', () {
    test('lists the queries newest first, each once', () async {
      final it = await open(history: FakeSearchHistoryRepository(['old']));
      await it.viewModel.submit(query);
      await it.viewModel.submit('beta');
      await it.viewModel.submit(query);

      expect(it.viewModel.history, [query, 'beta', 'old']);
    });

    test('is cleared', () async {
      final it = await open(history: FakeSearchHistoryRepository(['old']));
      expect(it.viewModel.history, ['old']);
      await it.viewModel.clearHistory();

      expect(it.viewModel.history, isEmpty);
      expect(await it.history.queries(), isA<Ok<List<String>>>());
    });
  });
}
