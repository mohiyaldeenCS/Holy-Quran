import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/reading_providers.dart';
import 'package:holyquran/config/providers/settings_providers.dart';
import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/in_memory_app_settings_repository.dart';
import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_app_settings_repository.dart';

QuranAddress _at(int surah, int ayah) => QuranAddress('hafs', surah, ayah);

/// Sets up the settings and the reading position over [database] and returns
/// what they provided.
Future<Dependencies> _readingOver(
  UserDatabase database, {
  bool settingsFromDatabase = true,
}) async {
  late Dependencies provided;
  await buildDependencies(
    areas: [
      (dependencies) async => dependencies.provide(database),
      if (settingsFromDatabase)
        settingsProviders
      else
        (dependencies) async =>
            dependencies.provideListenable<AppSettingsRepository>(
              FakeAppSettingsRepository(),
            ),
      readingProviders,
      (dependencies) async => provided = dependencies,
    ],
  );
  return provided;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('with readable user data', () {
    late UserDatabase db;

    setUp(() => db = UserDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('provides no position before the first save', () async {
      final provided = await _readingOver(db);

      expect(
        provided.read<ReadingPositionRepository>(),
        isA<LocalReadingPositionRepository>(),
      );
      expect(provided.read<ReadingPositionRepository>().last, isNull);
    });

    test('provides the position stored in the user database', () async {
      final first = (await _readingOver(db)).read<ReadingPositionRepository>();
      expect(await first.save(_at(2, 30)), isA<Ok<void>>());

      final second = (await _readingOver(db)).read<ReadingPositionRepository>();

      expect(second.last, _at(2, 30));
    });

    test('tells its listeners of a save', () async {
      final positions = (await _readingOver(
        db,
      )).read<ReadingPositionRepository>();
      var heard = 0;
      positions.addListener(() => heard++);

      await positions.save(_at(3, 1));

      expect(heard, 1);
    });
  });

  group('when the user file cannot be read', () {
    late Directory directory;
    late File file;
    late List<int> bytes;
    late UserDatabase unreadable;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('reading_test');
      file = File('${directory.path}/${UserDatabase.fileName}')
        ..writeAsStringSync('synthetic text that is not a database file' * 100);
      bytes = file.readAsBytesSync();
      unreadable = UserDatabase(NativeDatabase(file));
    });
    tearDown(() async {
      await unreadable.close();
      directory.deleteSync(recursive: true);
    });

    test('settings in memory keep the position in memory, and the file is '
        'left as it is (D-133)', () async {
      final provided = await _readingOver(unreadable);
      expect(
        provided.read<AppSettingsRepository>(),
        isA<InMemoryAppSettingsRepository>(),
      );

      final positions = provided.read<ReadingPositionRepository>();
      expect(positions.last, isNull);
      expect(await positions.save(_at(2, 30)), isA<Ok<void>>());

      expect(positions.last, _at(2, 30));
      expect(file.readAsBytesSync(), bytes);
    });

    test('a position that cannot be read provides nothing', () async {
      final provided = await _readingOver(
        unreadable,
        settingsFromDatabase: false,
      );

      expect(
        provided.read<AppSettingsRepository>(),
        isNot(isA<InMemoryAppSettingsRepository>()),
      );
      expect(provided.read<ReadingPositionRepository>, throwsStateError);
      expect(file.readAsBytesSync(), bytes);
    });
  });

  test('needs the user database and the settings from the areas before it', () {
    expect(buildDependencies(areas: [readingProviders]), throwsStateError);
  });
}
