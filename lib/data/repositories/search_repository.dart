import '../../domain/models/edition_map.dart';
import '../../domain/models/pack_failure.dart';
import '../../domain/models/quran_address.dart';
import '../../domain/models/quran_range.dart';
import '../../domain/models/quran_structure.dart';
import '../../domain/models/search_hit.dart';
import '../../domain/models/search_query.dart';
import '../../utils/result.dart';
import '../services/search_index_service.dart';

/// Searches the Quran on the base pack's stored search forms (`SR-02`,
/// `SR-03`, `SR-06`). Results are addresses and word ranges; the text is
/// read from the pack by address.
abstract interface class SearchRepository {
  /// The search form kinds the pack provides, in name order; empty when it
  /// provides none.
  Future<Result<List<String>>> formKinds();

  /// The ayat that hold [query] in its mode and scope, in mushaf order; none
  /// for a query with no words. Completes with an [ArgumentError] for a
  /// form kind the pack does not provide, or a surah or juz outside the
  /// edition.
  Future<Result<SearchResults>> search(SearchQuery query);
}

/// Builds the index on the first call and keeps it for the session. A
/// failed build fails that call and every later one, and is passed to
/// `onFailed`, so that the pack's integrity can be reported; while the pack
/// is not [_serving], every call fails with [PackDisabled].
final class PackSearchRepository implements SearchRepository {
  PackSearchRepository({
    required this._pack,
    required this._build,
    required this._structure,
    required this._serving,
    this._onFailed,
  });

  final String _pack;
  final Future<Result<SearchIndex>> Function() _build;
  final QuranStructure _structure;
  final bool Function() _serving;
  final void Function(Exception error)? _onFailed;
  Future<Result<SearchIndex>>? _index;

  Future<Result<SearchIndex>> _ready() => _index ??= _build().then((built) {
    if (built case Failure(:final error)) _onFailed?.call(error);
    return built;
  });

  @override
  Future<Result<List<String>>> formKinds() async {
    if (!_serving()) return Failure(PackDisabled(_pack));
    return switch (await _ready()) {
      Ok(:final value) => Ok(value.kinds),
      Failure(:final error) => Failure(error),
    };
  }

  @override
  Future<Result<SearchResults>> search(SearchQuery query) async {
    final within = _range(query.scope);
    if (!_serving()) return Failure(PackDisabled(_pack));
    return switch (await _ready()) {
      Ok(:final value) => Ok(
        SearchResults(
          query: query,
          hits: value.search(
            query.kind,
            query.words,
            query.mode,
            within: within,
          ),
        ),
      ),
      Failure(:final error) => Failure(error),
    };
  }

  QuranRange? _range(SearchScope scope) => switch (scope) {
    WholeQuran() => null,
    SurahScope(:final surah) => QuranRange(
      _ayah(surah, 1),
      _ayah(surah, _structure.ayahCount(surah)),
    ),
    JuzScope(:final juz) => QuranRange(
      _structure.firstAyah(Division.juz, juz),
      juz < _structure.count(Division.juz)
          ? _before(_structure.firstAyah(Division.juz, juz + 1))
          : _lastAyah(),
    ),
  };

  QuranAddress _ayah(int surah, int ayah) =>
      QuranAddress(_structure.riwaya, surah, ayah);

  QuranAddress _before(QuranAddress ayah) => ayah.ayah > 1
      ? _ayah(ayah.surah, ayah.ayah - 1)
      : _ayah(ayah.surah - 1, _structure.ayahCount(ayah.surah - 1));

  QuranAddress _lastAyah() {
    final surah = _structure.surahCount;
    return _ayah(surah, _structure.ayahCount(surah));
  }
}
