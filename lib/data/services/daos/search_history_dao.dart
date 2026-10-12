import 'package:drift/drift.dart';

import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/data/services/user_tables.dart';

part 'search_history_dao.g.dart';

/// The local search history (`SR-10`). Its rows are never synced, so they
/// are removed rather than marked deleted.
@DriftAccessor(tables: [SearchHistory])
class SearchHistoryDao extends DatabaseAccessor<UserDatabase>
    with _$SearchHistoryDaoMixin {
  SearchHistoryDao(super.attachedDatabase);

  /// The queries, newest first: by id, which only grows, so a change of the
  /// device clock cannot reorder them.
  Future<List<String>> queries() async => [
    for (final row in await (select(
      searchHistory,
    )..orderBy([(h) => OrderingTerm.desc(h.id)])).get())
      row.query,
  ];

  /// Stores [query] as the newest, removing its older rows.
  Future<void> record(String query, {required int at}) => transaction(() async {
    await (delete(searchHistory)..where((h) => h.query.equals(query))).go();
    await into(
      searchHistory,
    ).insert(SearchHistoryCompanion.insert(query: query, searchedAt: at));
  });

  Future<void> clear() => delete(searchHistory).go();
}
