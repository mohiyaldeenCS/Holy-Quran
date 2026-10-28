import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/data/services/daos/reading_position_dao.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/utils/result.dart';

final class _FailingDao extends ReadingPositionDao {
  _FailingDao(super.attachedDatabase, {this.failRead = false});

  final bool failRead;

  @override
  Future<String?> readAddress() async =>
      failRead ? throw const FormatException('synthetic failure') : null;

  @override
  Future<void> writeAddress(String address, {required int updatedAt}) async =>
      throw const FormatException('synthetic failure');
}

int _zero() => 0;

Future<LocalReadingPositionRepository> _load(
  ReadingPositionDao dao, {
  int Function() now = _zero,
}) async => switch (await LocalReadingPositionRepository.load(dao, now: now)) {
  Ok(:final value) => value,
  Failure(:final error) => throw error,
};

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late UserDatabase db;

  setUp(() => db = UserDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('has no position before the first save', () async {
    final positions = await _load(ReadingPositionDao(db));

    expect(positions.last, isNull);
  });

  test('saves the last ayah in one row and notifies', () async {
    var clock = 10;
    final positions = await _load(ReadingPositionDao(db), now: () => clock++);
    var notified = 0;
    positions.addListener(() => notified++);

    expect(
      await positions.save(QuranAddress.parse('hafs:2:5')),
      isA<Ok<void>>(),
    );
    expect(
      await positions.save(QuranAddress.parse('hafs:4:1')),
      isA<Ok<void>>(),
    );

    expect(positions.last, QuranAddress.parse('hafs:4:1'));
    expect(notified, 2);
    final rows = await db.select(db.readingPosition).get();
    expect(rows, hasLength(1));
    expect(rows.single.address, 'hafs:4:1');
    expect(rows.single.updatedAt, 11);
    expect((await _load(ReadingPositionDao(db))).last, positions.last);
  });

  test('saving the same ayah again neither writes nor notifies', () async {
    var clock = 0;
    final positions = await _load(ReadingPositionDao(db), now: () => ++clock);
    var notified = 0;
    positions.addListener(() => notified++);

    await positions.save(QuranAddress.parse('hafs:2:5'));
    await positions.save(QuranAddress.parse('hafs:2:5'));

    expect(notified, 1);
    expect((await db.select(db.readingPosition).getSingle()).updatedAt, 1);
  });

  test('a word address is refused', () async {
    final positions = await _load(ReadingPositionDao(db));

    expect(
      () => positions.save(QuranAddress.parse('hafs:2:5:1')),
      throwsArgumentError,
    );
    expect(positions.last, isNull);
  });

  for (final stored in ['not an address', 'hafs:2:5:1']) {
    test('a stored "$stored" reads as no position', () async {
      await ReadingPositionDao(db).writeAddress(stored, updatedAt: 1);

      expect((await _load(ReadingPositionDao(db))).last, isNull);
    });
  }

  test(
    'a failed write returns a Failure; the session keeps the position',
    () async {
      final positions = await _load(_FailingDao(db));
      var notified = 0;
      positions.addListener(() => notified++);

      final result = await positions.save(QuranAddress.parse('hafs:1:1'));

      expect(result, isA<Failure<void>>());
      expect(positions.last, QuranAddress.parse('hafs:1:1'));
      expect(notified, 1);
      expect((await _load(ReadingPositionDao(db))).last, isNull);
    },
  );

  test('the position is current and notified before the write ends', () async {
    final positions = await _load(ReadingPositionDao(db));
    var notified = 0;
    positions.addListener(() => notified++);

    final saving = positions.save(QuranAddress.parse('hafs:2:3'));

    expect(positions.last, QuranAddress.parse('hafs:2:3'));
    expect(notified, 1);
    expect(await saving, isA<Ok<void>>());
  });

  test('a failed read returns a Failure', () async {
    expect(
      await LocalReadingPositionRepository.load(
        _FailingDao(db, failRead: true),
      ),
      isA<Failure<LocalReadingPositionRepository>>(),
    );
  });

  test('the position survives closing and reopening a file database', () async {
    final directory = await Directory.systemTemp.createTemp('position_test');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/${UserDatabase.fileName}');

    final first = UserDatabase(NativeDatabase(file));
    await (await _load(
      ReadingPositionDao(first),
    )).save(QuranAddress.parse('hafs:18:10'));
    await first.close();

    final second = UserDatabase(NativeDatabase(file));
    addTearDown(second.close);
    expect(
      (await _load(ReadingPositionDao(second))).last,
      QuranAddress.parse('hafs:18:10'),
    );
  });
}
