import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/integrity_log_repository.dart';
import 'package:holyquran/data/services/daos/integrity_log_dao.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/utils/result.dart';

final class _FailingDao extends IntegrityLogDao {
  _FailingDao(super.attachedDatabase);

  var failing = true;

  @override
  Future<void> append({
    required String packId,
    required int? packVersion,
    required String kind,
    required String? detail,
    required int occurredAt,
  }) async {
    if (failing) throw const FormatException('synthetic failure');
    return super.append(
      packId: packId,
      packVersion: packVersion,
      kind: kind,
      detail: detail,
      occurredAt: occurredAt,
    );
  }

  @override
  Future<List<IntegrityEventRow>> entries() async => failing
      ? throw const FormatException('synthetic failure')
      : super.entries();
}

PackIntegrityEvent _event(
  PackIntegrity state, {
  String pack = 'synthetic-text',
  int? version = 1,
  int second = 0,
}) => PackIntegrityEvent(
  pack: pack,
  version: version,
  state: state,
  at: DateTime.utc(2026, 1, 1, 0, 0, second),
);

List<IntegrityLogEntry> _value(Result<List<IntegrityLogEntry>> result) =>
    switch (result) {
      Ok(:final value) => value,
      Failure(:final error) => throw error,
    };

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late UserDatabase db;

  setUp(() => db = UserDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('stores every event, newest first, and notifies', () async {
    final events = StreamController<PackIntegrityEvent>();
    final log = LocalIntegrityLogRepository(IntegrityLogDao(db), events.stream);
    addTearDown(log.dispose);
    var notified = 0;
    log.addListener(() => notified++);

    events
      ..add(_event(const IntegrityMissing(), version: null))
      ..add(_event(const IntegrityRepairing(), second: 1))
      ..add(
        _event(
          const IntegrityFailed(SurahHashMismatch('synthetic-text', 2)),
          second: 2,
        ),
      )
      ..add(_event(const IntegrityOk(), pack: 'synthetic-tafsir', second: 3));
    await events.close();
    await pumpEventQueue();

    expect(_value(await log.entries()), [
      IntegrityLogEntry(
        packId: 'synthetic-tafsir',
        packVersion: 1,
        kind: 'ok',
        detail: null,
        occurredAt: DateTime.utc(2026, 1, 1, 0, 0, 3),
      ),
      IntegrityLogEntry(
        packId: 'synthetic-text',
        packVersion: 1,
        kind: 'failed',
        detail: 'SurahHashMismatch(synthetic-text): surah 2',
        occurredAt: DateTime.utc(2026, 1, 1, 0, 0, 2),
      ),
      IntegrityLogEntry(
        packId: 'synthetic-text',
        packVersion: 1,
        kind: 'repairing',
        detail: null,
        occurredAt: DateTime.utc(2026, 1, 1, 0, 0, 1),
      ),
      IntegrityLogEntry(
        packId: 'synthetic-text',
        packVersion: null,
        kind: 'missing',
        detail: null,
        occurredAt: DateTime.utc(2026),
      ),
    ]);
    expect(notified, 4);
    expect(log.lastError, isNull);
  });

  test('keeps a failed write as the last error until one succeeds', () async {
    final dao = _FailingDao(db);
    final events = StreamController<PackIntegrityEvent>();
    final log = LocalIntegrityLogRepository(dao, events.stream);
    addTearDown(log.dispose);
    var notified = 0;
    log.addListener(() => notified++);

    events.add(_event(const IntegrityOk()));
    await pumpEventQueue();
    expect(log.lastError, isA<FormatException>());
    expect(notified, 1);
    expect(await log.entries(), isA<Failure<List<IntegrityLogEntry>>>());

    dao.failing = false;
    events.add(_event(const IntegrityOk(), second: 1));
    await pumpEventQueue();
    expect(log.lastError, isNull);
    expect(_value(await log.entries()), hasLength(1));
    await events.close();
  });

  test('records an error of the events as the last error', () async {
    final events = StreamController<PackIntegrityEvent>();
    final log = LocalIntegrityLogRepository(IntegrityLogDao(db), events.stream);
    addTearDown(log.dispose);
    var notified = 0;
    log.addListener(() => notified++);

    events.addError(const FormatException('synthetic failure'));
    await pumpEventQueue();
    expect(log.lastError, isA<FormatException>());
    expect(notified, 1);

    events.addError(StateError('synthetic error'));
    await pumpEventQueue();
    expect('${log.lastError}', contains('synthetic error'));

    events.add(_event(const IntegrityOk()));
    await pumpEventQueue();
    expect(log.lastError, isNull);
    expect(_value(await log.entries()), hasLength(1));
    await events.close();
  });

  test('stops listening once disposed', () async {
    final events = StreamController<PackIntegrityEvent>();
    LocalIntegrityLogRepository(IntegrityLogDao(db), events.stream).dispose();
    await pumpEventQueue();

    expect(events.hasListener, isFalse);
    await events.close();
  });

  test('the log survives closing and reopening a file database', () async {
    final directory = await Directory.systemTemp.createTemp('integrity_test');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/${UserDatabase.fileName}');

    final first = UserDatabase(NativeDatabase(file));
    final log = LocalIntegrityLogRepository(
      IntegrityLogDao(first),
      Stream.value(_event(const IntegrityOk())),
    );
    await pumpEventQueue();
    log.dispose();
    await first.close();

    final second = UserDatabase(NativeDatabase(file));
    addTearDown(second.close);
    final reopened = LocalIntegrityLogRepository(
      IntegrityLogDao(second),
      const Stream.empty(),
    );
    addTearDown(reopened.dispose);
    expect(_value(await reopened.entries()).single.kind, 'ok');
  });
}
