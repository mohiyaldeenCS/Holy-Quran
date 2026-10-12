import 'package:holyquran/data/repositories/search_repository.dart';
import 'package:holyquran/domain/models/search_hit.dart';
import 'package:holyquran/domain/models/search_query.dart';
import 'package:holyquran/utils/result.dart';

/// Answers each search with the hits [hits] holds for its folded words
/// joined by a space, none for any other; every call fails with [failure]
/// when it is set.
final class FakeSearchRepository implements SearchRepository {
  FakeSearchRepository({
    this.kinds = const ['synthetic-plain'],
    this.hits = const {},
    this.failure,
  });

  final List<String> kinds;
  final Map<String, List<SearchHit>> hits;
  Exception? failure;

  /// The queries searched, in order.
  final queries = <SearchQuery>[];

  @override
  Future<Result<List<String>>> formKinds() async {
    if (failure case final failure?) return Failure(failure);
    return Ok(kinds);
  }

  @override
  Future<Result<SearchResults>> search(SearchQuery query) async {
    queries.add(query);
    if (failure case final failure?) return Failure(failure);
    return Ok(
      SearchResults(query: query, hits: hits[query.words.join(' ')] ?? []),
    );
  }
}
