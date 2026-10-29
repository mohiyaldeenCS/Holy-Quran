import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/settings_providers.dart';
import 'package:holyquran/config/providers/user_data_providers.dart';
import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/bookmark_repository.dart';
import 'package:holyquran/data/repositories/category_repository.dart';
import 'package:holyquran/data/repositories/in_memory_app_settings_repository.dart';
import 'package:holyquran/data/repositories/integrity_log_repository.dart';
import 'package:holyquran/data/repositories/keep_awake_repository.dart';
import 'package:holyquran/data/repositories/listening_position_repository.dart';
import 'package:holyquran/data/repositories/note_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
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

  group('the area', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final messages = <String>[];

    setUp(() {
      messages.clear();
      messenger.allMessagesHandler = (channel, handler, message) {
        messages.add(channel);
        return null;
      };
    });
    tearDown(() => messenger.allMessagesHandler = null);

    Future<Dependencies> over(
      UserDatabase database, {
      PackIntegrityRepository? integrity,
    }) async {
      late Dependencies provided;
      await buildDependencies(
        areas: [
          (dependencies) async => dependencies.provide(database),
          settingsProviders,
          if (integrity != null)
            (dependencies) async => dependencies.provideListenable(integrity),
          userDataProviders,
          (dependencies) async => provided = dependencies,
        ],
      );
      return provided;
    }

    test('provides the repositories over the user database without touching '
        'a plugin', () async {
      final dependencies = await over(db);
      addTearDown(dependencies.read<IntegrityLogRepository>().dispose);

      expect(
        await dependencies.read<BookmarkRepository>().add(
          QuranAddress.parse('hafs:2:5'),
          'c',
        ),
        isA<Ok<Object>>(),
      );
      expect(
        dependencies.read<KeepAwakeRepository>(),
        isA<LocalKeepAwakeRepository>(),
      );
      expect(messages, isEmpty);
    });

    test('stores the events of the integrity repository the Quran area '
        'provided', () async {
      final integrity = FakePackIntegrityRepository();
      addTearDown(integrity.dispose);
      final dependencies = await over(db, integrity: integrity);
      final log = dependencies.read<IntegrityLogRepository>();
      addTearDown(log.dispose);

      integrity.report('synthetic-text', const IntegrityOk(), version: 3);
      await pumpEventQueue();

      switch (await log.entries()) {
        case Ok(value: [final entry]):
          expect(entry.packId, 'synthetic-text');
        case final other:
          fail('expected one entry, got $other');
      }
    });

    test('keeps user data in memory when the settings could not be read, '
        'and leaves the file as it is (D-133)', () async {
      final directory = await Directory.systemTemp.createTemp('user_data_area');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/${UserDatabase.fileName}')
        ..writeAsStringSync('synthetic text that is not a database file' * 100);
      final bytes = file.readAsBytesSync();
      final unreadable = UserDatabase(NativeDatabase(file));
      addTearDown(unreadable.close);

      final dependencies = await over(unreadable);
      addTearDown(dependencies.read<IntegrityLogRepository>().dispose);

      expect(
        dependencies.read<AppSettingsRepository>(),
        isA<InMemoryAppSettingsRepository>(),
      );
      expect(
        await dependencies.read<BookmarkRepository>().add(
          QuranAddress.parse('hafs:2:5'),
          'c',
        ),
        isA<Ok<Object>>(),
      );
      expect(file.readAsBytesSync(), bytes);
    });

    test(
      'needs the user database and the settings from the areas before it',
      () {
        expect(buildDependencies(areas: [userDataProviders]), throwsStateError);
      },
    );
  });
}
