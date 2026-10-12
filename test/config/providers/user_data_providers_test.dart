import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/user_data_providers.dart';
import 'package:holyquran/data/repositories/bookmark_repository.dart';
import 'package:holyquran/data/repositories/category_repository.dart';
import 'package:holyquran/data/repositories/integrity_log_repository.dart';
import 'package:holyquran/data/repositories/keep_awake_repository.dart';
import 'package:holyquran/data/repositories/listening_position_repository.dart';
import 'package:holyquran/data/repositories/note_repository.dart';
import 'package:holyquran/data/repositories/search_history_repository.dart';
import 'package:holyquran/data/repositories/tag_repository.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/data/services/wakelock_service.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_app_settings_repository.dart';
import '../../../testing/fakes/fake_pack_integrity_repository.dart';

final class _FakeWakelock implements WakelockService {
  final calls = <bool>[];
  Exception? failure;

  @override
  Future<void> enable() => _call(true);

  @override
  Future<void> disable() => _call(false);

  Future<void> _call(bool on) async {
    calls.add(on);
    if (failure case final failure?) throw failure;
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late UserDatabase db;
  late FakeAppSettingsRepository settings;
  late _FakeWakelock wakelock;

  setUp(() {
    db = UserDatabase(NativeDatabase.memory());
    settings = FakeAppSettingsRepository();
    wakelock = _FakeWakelock();
  });
  tearDown(() => db.close());

  Future<Dependencies> setUpArea({
    UserDatabase? database,
    Stream<PackIntegrityEvent>? integrityEvents,
  }) async {
    late Dependencies provided;
    final providers = await buildDependencies(
      areas: [
        (dependencies) async {
          await provideUserData(
            dependencies,
            database: database ?? db,
            settings: settings,
            wakelock: wakelock,
            integrityEvents: integrityEvents,
          );
          provided = dependencies;
        },
      ],
    );
    expect(providers, hasLength(8));
    return provided;
  }

  test('provides every repository of the user data', () async {
    final dependencies = await setUpArea();
    addTearDown(dependencies.read<IntegrityLogRepository>().dispose);

    final bookmarks = dependencies.read<BookmarkRepository>();
    final added = await bookmarks.add(QuranAddress.parse('hafs:2:5'), 'c');
    expect(added, isA<Ok<Object>>());
    expect(await dependencies.read<NoteRepository>().list(), isA<Ok<Object>>());
    expect(await dependencies.read<TagRepository>().tags(), isA<Ok<Object>>());
    expect(
      await dependencies.read<CategoryRepository>().categories(),
      isA<Ok<Object>>(),
    );
    expect(dependencies.read<ListeningPositionRepository>().last, isNull);
    expect(
      await dependencies.read<SearchHistoryRepository>().queries(),
      isA<Ok<Object>>(),
    );
    expect(dependencies.read<KeepAwakeRepository>().awake, isFalse);
  });

  test('keeps the screen awake as the setting says', () async {
    final dependencies = await setUpArea();
    addTearDown(dependencies.read<IntegrityLogRepository>().dispose);
    final keepAwake = dependencies.read<KeepAwakeRepository>();

    await keepAwake.setReaderActive(true);
    expect(keepAwake.awake, isTrue);

    await settings.setKeepScreenAwake(false);
    await pumpEventQueue();
    expect(keepAwake.awake, isFalse);

    await settings.setKeepScreenAwake(true);
    await pumpEventQueue();
    expect(wakelock.calls, [true, false, true]);
  });

  test('reports a wakelock that cannot follow the setting', () async {
    final reported = <FlutterErrorDetails>[];
    final onError = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = onError);
    final dependencies = await setUpArea();
    addTearDown(dependencies.read<IntegrityLogRepository>().dispose);
    final keepAwake = dependencies.read<KeepAwakeRepository>();
    await keepAwake.setReaderActive(true);
    wakelock.failure = const FormatException('synthetic failure');

    await settings.setKeepScreenAwake(false);
    await pumpEventQueue();

    final [details] = reported;
    expect(details.exception, isA<FormatException>());
    expect(details.library, 'keep awake');
    expect(keepAwake.awake, isTrue);
  });

  test('starts with the setting off when it is off', () async {
    settings = FakeAppSettingsRepository(keepScreenAwake: false);
    final dependencies = await setUpArea();
    addTearDown(dependencies.read<IntegrityLogRepository>().dispose);

    await dependencies.read<KeepAwakeRepository>().setPlayerActive(true);

    expect(wakelock.calls, isEmpty);
  });

  test('logs the integrity events it is given', () async {
    final integrity = FakePackIntegrityRepository();
    addTearDown(integrity.dispose);
    final dependencies = await setUpArea(integrityEvents: integrity.events);
    final log = dependencies.read<IntegrityLogRepository>();
    addTearDown(log.dispose);

    integrity.report('synthetic-text', const IntegrityOk(), version: 3);
    await pumpEventQueue();

    switch (await log.entries()) {
      case Ok(value: [final entry]):
        expect(entry.packId, 'synthetic-text');
        expect(entry.packVersion, 3);
        expect(entry.kind, 'ok');
      case final other:
        fail('expected one entry, got $other');
    }
  });

  test('throws when the user data cannot be read', () async {
    final directory = await Directory.systemTemp.createTemp('user_data_test');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/${UserDatabase.fileName}')
      ..writeAsStringSync('synthetic text that is not a database file' * 100);
    final unreadable = UserDatabase(NativeDatabase(file));
    addTearDown(unreadable.close);

    await expectLater(
      buildDependencies(
        areas: [
          (dependencies) => provideUserData(
            dependencies,
            database: unreadable,
            settings: settings,
            wakelock: wakelock,
          ),
        ],
      ),
      throwsA(isA<Exception>()),
    );
  });

  test(
    'the area itself provides nothing until the database is provided',
    () async {
      expect(await buildDependencies(areas: [userDataProviders]), isEmpty);
    },
  );
}
