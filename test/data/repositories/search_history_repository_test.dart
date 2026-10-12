import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/search_history_repository.dart';
import 'package:holyquran/data/services/daos/search_history_dao.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/utils/result.dart';

final class _FailingDao extends SearchHistoryDao {
  _FailingDao(super.attachedDatabase);

  static const _failure = FormatException('synthetic failure');

  @override
  Future<List<String>> queries() async => throw _failure;

  @override
  Future<void> record(String query, {required int at}) async => throw _failure;

  @override
  Future<void> clear() async => throw _failure;
}

List<String> _value(Result<List<String>> result) => switch (result) {
  Ok(:final value) => value,
  Failure(:final error) => throw error,
};

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late UserDatabase db;
  late LocalSearchHistoryRepository history;
  late int notified;

  setUp(() {
    db = UserDatabase(NativeDatabase.memory());
    var clock = 0;
    history = LocalSearchHistoryRepository(
      SearchHistoryDao(db),
      now: () => clock++,
    );
    notified = 0;
    history.addListener(() => notified++);
  });
  tearDown(() => db.close());

  test('records queries newest first and notifies', () async {
    await history.record('query-a');
    await history.record('query-b');

    expect(_value(await history.queries()), ['query-b', 'query-a']);
    expect(notified, 2);
  });

  test('moves a query searched again to the top', () async {
    await history.record('query-a');
    await history.record('query-b');
    await history.record('query-a');

    expect(_value(await history.queries()), ['query-a', 'query-b']);
    expect(await db.select(db.searchHistory).get(), hasLength(2));
  });

  test('keeps a query as typed and skips an empty one', () async {
    await history.record(' query-a');
    await history.record('query-a');
    expect(await history.record(''), isA<Ok<void>>());

    expect(_value(await history.queries()), ['query-a', ' query-a']);
    expect(notified, 2);
  });

  test('clear removes the rows', () async {
    await history.record('query-a');

    expect(await history.clear(), isA<Ok<void>>());
    expect(_value(await history.queries()), isEmpty);
    expect(await db.select(db.searchHistory).get(), isEmpty);
    expect(notified, 2);
  });

  test('a failing database returns Failures and does not notify', () async {
    final failing = LocalSearchHistoryRepository(_FailingDao(db));
    var heard = 0;
    failing.addListener(() => heard++);

    expect(await failing.queries(), isA<Failure<List<String>>>());
    expect(await failing.record('query-a'), isA<Failure<void>>());
    expect(await failing.clear(), isA<Failure<void>>());
    expect(heard, 0);
  });

  test('the history survives closing and reopening a file database', () async {
    final directory = await Directory.systemTemp.createTemp('history_test');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/${UserDatabase.fileName}');

    final first = UserDatabase(NativeDatabase(file));
    final stored = LocalSearchHistoryRepository(
      SearchHistoryDao(first),
      now: () => 1,
    );
    await stored.record('query-a');
    await first.close();

    final second = UserDatabase(NativeDatabase(file));
    addTearDown(second.close);
    expect(
      _value(
        await LocalSearchHistoryRepository(SearchHistoryDao(second)).queries(),
      ),
      ['query-a'],
    );
  });
}
