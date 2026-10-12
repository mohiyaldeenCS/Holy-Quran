import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/listening_position_repository.dart';
import 'package:holyquran/data/services/daos/listening_position_dao.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/domain/models/listening_position.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/utils/result.dart';

final class _FailingDao extends ListeningPositionDao {
  _FailingDao(super.attachedDatabase, {this.failRead = false});

  final bool failRead;

  @override
  Future<ListeningPositionRow?> read() async =>
      failRead ? throw const FormatException('synthetic failure') : null;

  @override
  Future<void> write(
    String address,
    String recitationId,
    int offsetMs, {
    required int updatedAt,
  }) async => throw const FormatException('synthetic failure');
}

ListeningPosition _position(String address, [int offsetMs = 1500]) =>
    ListeningPosition(
      address: QuranAddress.parse(address),
      recitationId: 'synthetic-reciter',
      offset: Duration(milliseconds: offsetMs),
    );

Future<LocalListeningPositionRepository> _load(
  ListeningPositionDao dao, {
  int Function()? now,
}) async => switch (now == null
    ? await LocalListeningPositionRepository.load(dao)
    : await LocalListeningPositionRepository.load(dao, now: now)) {
  Ok(:final value) => value,
  Failure(:final error) => throw error,
};

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late UserDatabase db;

  setUp(() => db = UserDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('has no position before the first save', () async {
    expect((await _load(ListeningPositionDao(db))).last, isNull);
  });

  test('saves the position in one row and notifies', () async {
    var clock = 10;
    final positions = await _load(ListeningPositionDao(db), now: () => clock++);
    var notified = 0;
    positions.addListener(() => notified++);

    expect(await positions.save(_position('hafs:2:5')), isA<Ok<void>>());
    expect(await positions.save(_position('hafs:2:5')), isA<Ok<void>>());
    expect(await positions.save(_position('hafs:2:5', 3000)), isA<Ok<void>>());

    expect(positions.last, _position('hafs:2:5', 3000));
    expect(notified, 2);
    final [row] = await db.select(db.listeningPosition).get();
    expect(row.address, 'hafs:2:5');
    expect(row.recitationId, 'synthetic-reciter');
    expect(row.offsetMs, 3000);
    expect(row.updatedAt, 11);
  });

  for (final (address, offset) in [
    ('hafs:2:5:3', 0),
    ('not an address', 0),
    ('hafs:2:5', -1),
  ]) {
    test('reads "$address" at $offset ms as no position', () async {
      await ListeningPositionDao(
        db,
      ).write(address, 'synthetic-reciter', offset, updatedAt: 1);

      expect((await _load(ListeningPositionDao(db))).last, isNull);
    });
  }

  test('a failed write returns a Failure and keeps the position', () async {
    final positions = await _load(_FailingDao(db));
    var notified = 0;
    positions.addListener(() => notified++);

    expect(await positions.save(_position('hafs:1:1')), isA<Failure<void>>());
    expect(positions.last, isNull);
    expect(notified, 0);
  });

  test('a failed read returns a Failure', () async {
    expect(
      await LocalListeningPositionRepository.load(
        _FailingDao(db, failRead: true),
      ),
      isA<Failure<LocalListeningPositionRepository>>(),
    );
  });

  test('the position survives closing and reopening a file database', () async {
    final directory = await Directory.systemTemp.createTemp('listening_test');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/${UserDatabase.fileName}');

    final first = UserDatabase(NativeDatabase(file));
    await (await _load(
      ListeningPositionDao(first),
    )).save(_position('hafs:18:10', 4200));
    await first.close();

    final second = UserDatabase(NativeDatabase(file));
    addTearDown(second.close);
    expect(
      (await _load(ListeningPositionDao(second))).last,
      _position('hafs:18:10', 4200),
    );
  });
}
