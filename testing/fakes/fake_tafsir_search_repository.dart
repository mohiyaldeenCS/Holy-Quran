import 'package:holyquran/data/repositories/tafsir_search_repository.dart';
import 'package:holyquran/domain/models/search_hit.dart';
import 'package:holyquran/utils/result.dart';

/// Answers each search with the hits [hits] holds for the query as typed,
/// kept to the books asked for, in their order; every call fails with
/// [failure] when it is set.
final class FakeTafsirSearchRepository implements TafsirSearchRepository {
  FakeTafsirSearchRepository({this.hits = const {}, this.failure});

  final Map<String, List<TafsirHit>> hits;
  Exception? failure;

  /// The searches made, in order.
  final searches = <(String query, List<String> books)>[];

  @override
  Future<Result<List<TafsirHit>>> search(
    String query,
    List<String> books,
  ) async {
    searches.add((query, books));
    if (failure case final failure?) return Failure(failure);
    final found = hits[query] ?? const [];
    return Ok([
      for (final book in books) ...found.where((hit) => hit.book == book),
    ]);
  }
}
