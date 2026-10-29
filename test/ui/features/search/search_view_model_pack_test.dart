import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/mark_span.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/search_hit.dart';
import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/domain/models/word_span.dart';
import 'package:holyquran/ui/features/search/view_models/search_view_model.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../testing/fakes/fake_pack_integrity_repository.dart';
import '../../../../testing/fakes/fake_search_history_repository.dart';
import '../../../../testing/fakes/fake_search_repository.dart';
import '../index/index_fixture.dart';
import 'search_fixture.dart';

/// The pack's text, with the reads of ayat held until the test lets them go.
final class _HeldText implements QuranTextRepository {
  _HeldText(this._inner);

  final QuranTextRepository _inner;
  final gates = <QuranAddress, Completer<void>>{};
  bool holding = false;

  @override
  String get riwaya => _inner.riwaya;

  @override
  PackFont get font => _inner.font;

  @override
  Future<Result<PackText>> ayahText(QuranAddress address) async {
    if (holding) await (gates[address] = Completer<void>()).future;
    return _inner.ayahText(address);
  }

  @override
  Future<Result<List<SurahInfo>>> surahs() => _inner.surahs();

  @override
  Future<Result<PackText?>> basmala(int surah) => _inner.basmala(surah);

  @override
  Future<Result<Set<int>>> basmalaSurahs() => _inner.basmalaSurahs();

  @override
  Future<Result<List<WordSpan>>> words(QuranAddress address) =>
      _inner.words(address);

  @override
  Future<Result<List<MarkSpan>>> marks(QuranAddress address) =>
      _inner.marks(address);

  @override
  Future<Result<EditionMap>> editionMap() => _inner.editionMap();

  @override
  Future<Result<bool>> contains(QuranAddress address) =>
      _inner.contains(address);
}

void main() {
  late Directory root;
  late IndexFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('search_view_model_pack_test');
    fixture = await IndexFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });
  tearDown(() => fixture.serving = true);

  SearchViewModel viewModelOf(
    FakeSearchRepository search, {
    QuranTextRepository? text,
    FakeSearchHistoryRepository? history,
    FakePackIntegrityRepository? integrity,
  }) {
    final viewModel = SearchViewModel(
      search: search,
      text: text ?? fixture.text,
      index: fixture.index,
      words: jumpWords,
      history: history,
      integrity: integrity,
    );
    addTearDown(viewModel.dispose);
    return viewModel;
  }

  FakeSearchRepository finding([List<SearchHit>? hits]) => FakeSearchRepository(
    kinds: const [SearchKinds.word, SearchKinds.bare],
    hits: {
      query: hits ?? [hit(fixture, 2, 3), hit(fixture, 3, 1)],
    },
  );

  test('a pack that stops serving takes the results and cards away', () async {
    final integrity = FakePackIntegrityRepository();
    final viewModel = viewModelOf(finding(), integrity: integrity);
    await viewModel.load();
    await viewModel.submit(query);
    await viewModel.loadCard(0);
    expect(viewModel.cardAt(0), isNotNull);
    expect(viewModel.hasData, isTrue);

    fixture.serving = false;
    integrity.report(
      'synthetic-text',
      const IntegrityFailed(PackInconsistent('synthetic-text', 'broken')),
    );

    expect(viewModel.hasData, isFalse);
    expect(viewModel.searched, isFalse);
    expect(viewModel.cardCount, 0);
  });

  test('a card read for results that were replaced is not kept', () async {
    final held = _HeldText(fixture.text);
    final viewModel = viewModelOf(finding(), text: held);
    await viewModel.load();
    await viewModel.submit(query);
    held.holding = true;
    final reading = viewModel.loadCard(0);
    await pumpEventQueue();
    expect(held.gates, hasLength(1));

    held.holding = false;
    await viewModel.selectKind(1);
    held.gates.values.single.complete();
    await reading;

    expect(viewModel.cardAt(0), isNull, reason: 'the old results are gone');
    await viewModel.loadCard(0);
    expect(viewModel.cardAt(0), isNotNull);
  });

  test(
    'a pack with no search form of a known kind cannot be searched',
    () async {
      final search = FakeSearchRepository(
        kinds: const ['synthetic-plain', 'synthetic_spelled'],
      );
      final viewModel = viewModelOf(search);
      await viewModel.load();

      expect(viewModel.canSearch, isFalse);
      await viewModel.submit(query);
      expect(search.queries, isEmpty);
    },
  );

  test(
    'a search superseded by a change of chip is kept once it is answered',
    () async {
      final history = FakeSearchHistoryRepository();
      final viewModel = viewModelOf(finding(), history: history);
      await viewModel.load();
      final first = viewModel.submit(query);
      final second = viewModel.selectKind(1);
      await Future.wait([first, second]);

      expect(viewModel.searched, isTrue);
      expect(viewModel.history, [query]);
    },
  );

  test('a failed search is a failure, not an empty answer', () async {
    final search = finding();
    final viewModel = viewModelOf(
      search,
      history: FakeSearchHistoryRepository(),
    );
    await viewModel.load();
    search.failure = Exception('broken');
    await viewModel.submit(query);

    expect(viewModel.failed, isTrue);
    expect(viewModel.searched, isFalse);
    expect(viewModel.history, isEmpty);
    search.failure = null;
    await viewModel.submit(query);
    expect(viewModel.failed, isFalse);
  });

  test('a history that cannot be cleared says so', () async {
    final history = FakeSearchHistoryRepository(['one'])
      ..clearFailure = Exception('not saved');
    final viewModel = viewModelOf(finding(), history: history);
    await viewModel.load();
    await viewModel.clearHistory();

    expect(viewModel.historyClearFailed, isTrue);
    expect(viewModel.history, ['one']);
  });

  test('a history that is cleared is empty', () async {
    final history = FakeSearchHistoryRepository(['one']);
    final viewModel = viewModelOf(finding(), history: history);
    await viewModel.load();
    await viewModel.clearHistory();

    expect(await history.queries(), isA<Ok<List<String>>>());
    expect((await history.queries() as Ok<List<String>>).value, isEmpty);
    expect(viewModel.historyClearFailed, isFalse);
  });
}
