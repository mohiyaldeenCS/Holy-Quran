import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/address_input_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/repositories/search_history_repository.dart';
import 'package:holyquran/data/repositories/search_repository.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/go_to_error.dart';
import 'package:holyquran/domain/models/go_to_target.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/search_hit.dart';
import 'package:holyquran/domain/models/search_match.dart';
import 'package:holyquran/domain/models/search_query.dart';
import 'package:holyquran/domain/models/word_span.dart';
import 'package:holyquran/domain/use_cases/parse_direct_jump.dart';
import 'package:holyquran/domain/use_cases/parse_go_to.dart';
import 'package:holyquran/ui/features/search/view_models/search_card.dart';
import 'package:holyquran/utils/result.dart';

/// The form kinds the search chips stand for, in the chips' order (`SR-01`).
/// A chip shows only when the pack provides its kind. These two names are an
/// assumption: the real ones are decided with the pack's search forms (B0.2,
/// B0.4), and this is the one place to change then.
abstract final class SearchKinds {
  static const word = 'word';
  static const bare = 'bare';
  static const all = [word, bare];
}

/// Where the scope chips say a search looks (`SR-06`).
enum ScopeChoice { whole, surah, juz }

/// The search screen's state (`SR-01` to `SR-07`, `SR-10`): the chips the
/// pack has data for, what was searched and found, the order and the scope,
/// the cards that are shown whole, and the history. Matching is the engine's;
/// this reads each card's ayah and word spans from the pack by address and
/// turns the engine's word ranges into offsets, touching no text.
final class SearchViewModel extends ChangeNotifier {
  SearchViewModel({
    required this._search,
    required this._text,
    required this._index,
    required this._words,
    this._addresses,
    this._history,
    this._integrity,
  }) {
    _history?.addListener(_loadHistory);
    _integrity?.addListener(_packChanged);
  }

  final SearchRepository _search;
  final QuranTextRepository _text;
  final QuranIndexRepository _index;
  final DirectJumpWords _words;
  final AddressInputRepository? _addresses;
  final SearchHistoryRepository? _history;
  final PackIntegrityRepository? _integrity;

  List<String> _kinds = const [];
  int _kindIndex = 0;
  ScopeChoice _scopeChoice = ScopeChoice.whole;
  String _scopeText = '';
  SearchOrder _order = SearchOrder.mushaf;
  String _typed = '';
  String? _query;
  SearchResults? _results;
  List<SearchHit> _ordered = const [];
  GoToError? _refusal;
  List<String> _queries = const [];
  final _cards = <QuranAddress, SearchCard>{};
  final _loading = <QuranAddress>{};
  final _whole = <QuranAddress>{};
  String? _unrecorded;
  bool _failed = false;
  bool _historyClearFailed = false;
  int _generation = 0;
  bool _disposed = false;

  /// Reads which chips the pack has data for and the history.
  Future<void> load() async {
    if (await _search.formKinds() case Ok(:final value)) {
      _kinds = [
        for (final kind in SearchKinds.all)
          if (value.contains(kind)) kind,
      ];
    }
    await _loadHistory();
    _notify();
  }

  /// Whether the pack serves its text. While it does not, nothing of it is
  /// shown (PRD §9.5): no results, no cards.
  bool get hasData => _index.surahs.isNotEmpty;

  /// The form kinds that have a chip, in the chips' order.
  List<String> get kinds => _kinds;

  /// Whether the pack has a search form kind this screen knows. Without one,
  /// nothing can be searched.
  bool get canSearch => _kinds.isNotEmpty;

  /// Whether the last search failed: the engine could not answer.
  bool get failed => _failed;

  /// Whether the last clearing of the history failed.
  bool get historyClearFailed => _historyClearFailed;

  int get kindIndex => _kindIndex;

  ScopeChoice get scopeChoice => _scopeChoice;

  SearchOrder get order => _order;

  /// The text of the field, as last reported by [edit].
  String get typed => _typed;

  /// What the last search was for; null before one, and after the field was
  /// emptied.
  String? get query => _query;

  bool get searched => _results != null;

  int get occurrences => _results?.occurrences ?? 0;

  int get ayat => _results?.ayat ?? 0;

  /// Why the typed place or scope was refused, if it was.
  GoToError? get refusal => _refusal ?? scopeError;

  /// Recent queries, newest first.
  List<String> get history => _queries;

  bool get canClearHistory => _history != null;

  /// The scope typed, when it does not name a surah or juz of the edition.
  GoToError? get scopeError {
    if (_scopeChoice == ScopeChoice.whole || _scopeText.trim().isEmpty) {
      return null;
    }
    final number = readNumber(_scopeText.trim());
    if (number == null) return const UnreadableGoTo();
    return switch (_scopeChoice) {
      ScopeChoice.surah when number < 1 || number > _index.surahCount =>
        NoSuchSurah(surah: number, surahCount: _index.surahCount),
      ScopeChoice.juz when number < 1 || number > _index.count(Division.juz) =>
        DivisionOutOfRange(
          division: Division.juz,
          number: number,
          count: _index.count(Division.juz),
        ),
      _ => null,
    };
  }

  /// The name of [surah] in the pack, or null when it has none.
  PackText? surahName(int surah) {
    final surahs = _index.surahs;
    return surah >= 1 && surah <= surahs.length ? surahs[surah - 1].name : null;
  }

  /// The field's text changed. Emptying it shows the history again.
  void edit(String text) {
    _typed = text;
    _refusal = null;
    if (text.trim().isEmpty) _forget();
    _notify();
  }

  /// The place [text] names, to be opened in the reader, or null when it is
  /// not one: then it is searched for and kept in the history. A place the
  /// edition lacks is refused, as [refusal] says.
  Future<GoToTarget?> submit(String text) async {
    _typed = text;
    final query = text.trim();
    if (query.isEmpty) {
      _forget();
      _notify();
      return null;
    }
    // A later edit or submit makes this one stale while its lookup runs.
    final generation = ++_generation;
    final jump = await parseDirectJump(
      query,
      words: _words,
      structure: _index,
      surahNamed: _addresses?.surahNamed ?? _noNames,
    );
    if (generation != _generation) return null;
    switch (jump) {
      case Ok(:final value):
        _forget();
        _notify();
        return value;
      case Failure(:final error) when error is GoToError:
        _forget();
        _refusal = error;
        _notify();
        return null;
      case _:
        // Not a place, or the name lookup failed: the text is searched for.
        break;
    }
    _refusal = null;
    _query = query;
    _unrecorded = query;
    _whole.clear();
    await _run();
    return null;
  }

  Future<void> selectKind(int index) async {
    if (index == _kindIndex) return;
    _kindIndex = index;
    _notify();
    await _rerun();
  }

  Future<void> selectScope(ScopeChoice choice) async {
    if (choice == _scopeChoice) return;
    _scopeChoice = choice;
    _scopeText = '';
    _notify();
    await _rerun();
  }

  Future<void> setScopeText(String text) async {
    _scopeText = text;
    _notify();
    await _rerun();
  }

  /// Shows the next of the three orders (`SR-05`).
  void nextOrder() {
    _order = SearchOrder.values[(_order.index + 1) % SearchOrder.values.length];
    _arrange();
    _notify();
  }

  int get cardCount => _ordered.length;

  QuranAddress ayahAt(int index) => _ordered[index].ayah;

  /// The card for the result at [index], once [loadCard] has read it.
  SearchCard? cardAt(int index) => _cards[_ordered[index].ayah];

  /// Whether the long ayah of the result at [index] is shown whole. It is
  /// kept here, not in the card, so that scrolling the card away and back
  /// keeps it.
  bool isWhole(int index) => _whole.contains(_ordered[index].ayah);

  void showWhole(int index) {
    if (_whole.add(_ordered[index].ayah)) _notify();
  }

  /// Reads the ayah, its word spans and its surah's name for the result at
  /// [index]; a result whose ayah cannot be read has no card.
  Future<void> loadCard(int index) async {
    final generation = _generation;
    final hit = _ordered[index];
    final ayah = hit.ayah;
    if (_cards.containsKey(ayah) || !_loading.add(ayah)) return;
    final text = await _text.ayahText(ayah);
    final spans = await _text.words(ayah);
    if (generation != _generation) return;
    _loading.remove(ayah);
    final name = surahName(ayah.surah);
    if (name == null) return;
    if (text is Ok<PackText> && spans is Ok<List<WordSpan>>) {
      _cards[ayah] = SearchCard(
        ayah: ayah,
        surahName: name,
        text: text.value,
        matches: _offsets(hit, spans.value),
      );
      _notify();
    }
  }

  Future<void> clearHistory() async {
    final cleared = await _history?.clear();
    _historyClearFailed = cleared is Failure;
    _notify();
  }

  Future<void> _rerun() async {
    if (_query != null) await _run();
  }

  /// Searches for [_query] and, once the engine answers, keeps the query in
  /// the history, though a change of chip or scope may have made the search
  /// that asked for it stale.
  Future<void> _run() async {
    final query = _query;
    final scope = _scope;
    if (query == null || scope == null || _kinds.isEmpty) {
      _results = null;
      _resetCards();
      _notify();
      return;
    }
    _failed = false;
    final generation = ++_generation;
    final found = await _search.search(
      SearchQuery(
        text: query,
        kind: _kinds[_kindIndex],
        mode: SearchMode.scattered,
        scope: scope,
      ),
    );
    if (generation != _generation) return;
    _results = switch (found) {
      Ok(:final value) => value,
      Failure() => null,
    };
    _failed = _results == null;
    _resetCards();
    _notify();
    if (_results != null && _unrecorded != null) {
      final kept = _unrecorded!;
      _unrecorded = null;
      await _history?.record(kept);
    }
  }

  SearchScope? get _scope {
    if (_scopeChoice == ScopeChoice.whole) return const WholeQuran();
    final number = readNumber(_scopeText.trim());
    if (number == null || scopeError != null) return null;
    return switch (_scopeChoice) {
      ScopeChoice.surah => SurahScope(number),
      _ => JuzScope(number),
    };
  }

  void _arrange() {
    _ordered = _results?.ordered(_order) ?? const [];
  }

  /// The results changed, so the cards read for the old ones are dropped.
  void _resetCards() {
    // A card still being read belongs to the old results.
    _generation++;
    _arrange();
    _cards.clear();
    _loading.clear();
  }

  /// Ends the search and the refusal shown; the history and the chips stay.
  void _forget() {
    _generation++;
    _query = null;
    _unrecorded = null;
    _results = null;
    _failed = false;
    _refusal = null;
    _whole.clear();
    _resetCards();
  }

  /// A word range as the offsets of its first word's start and its last
  /// word's end in the ayah's text. A range the spans do not cover is not
  /// highlighted.
  List<SearchMatch> _offsets(SearchHit hit, List<WordSpan> spans) {
    WordSpan? span(int? number) {
      for (final candidate in spans) {
        if (candidate.number == number) return candidate;
      }
      return null;
    }

    return [
      for (final range in hit.matches)
        if (span(range.start.word) case final first?)
          if (span(range.end.word) case final last?)
            if (first.start < last.end)
              SearchMatch(start: first.start, end: last.end),
    ];
  }

  Future<void> _loadHistory() async {
    if (await _history?.queries() case Ok(:final value)) {
      _queries = value;
      _notify();
    }
  }

  static Future<Result<int?>> _noNames(String name) async => const Ok(null);

  void _packChanged() {
    if (!hasData) _forget();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _history?.removeListener(_loadHistory);
    _integrity?.removeListener(_packChanged);
    super.dispose();
  }
}
