import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/user_database_providers.dart';
import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/bookmark_repository.dart';
import 'package:holyquran/data/repositories/integrity_log_repository.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/utils/result.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../testing/application_support.dart';
import '../../../testing/fakes/memory_task_storage.dart';

// D-133: nothing of the user's is ever written to a file that cannot be read
// in full. The whole composition of areas is run over a file that lost one
// table, and each repository that writes is written through.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The areas start the pack installer, which creates the downloader plugin.
  setUpAll(() => FileDownloader(persistentStorage: MemoryTaskStorage()));

  final tables = [
    for (final table in UserDatabase.inMemory().allTables)
      table.actualTableName,
  ];

  /// A user database file with every table, minus [drop].
  Future<File> userFile(
    Directory support, {
    String? drop,
    int? userVersion,
  }) async {
    final file = File('${support.path}/${UserDatabase.fileName}');
    final created = UserDatabase(NativeDatabase(file));
    await created.customSelect('SELECT 1').get();
    await created.close();
    if (drop != null || userVersion != null) {
      final raw = sqlite3.open(file.path);
      if (drop != null) raw.execute('DROP TABLE "$drop"');
      if (userVersion != null) {
        raw.execute('PRAGMA user_version = $userVersion');
      }
      raw.close();
    }
    return file;
  }

  /// Builds every area over the support folder, writes through the settings,
  /// the reading position and the bookmarks, and closes what holds files.
  Future<void> startAndWrite() async {
    late Dependencies provided;
    await buildDependencies(
      areas: [...appAreas, (dependencies) async => provided = dependencies],
    );
    await provided.read<PackInstallRepository>().started;
    final settings = provided.read<AppSettingsRepository>();
    expect(await settings.setTheme(ReadingTheme.night), isA<Ok<void>>());
    expect(settings.themePreference.theme, ReadingTheme.night);
    final address = QuranAddress.parse('hafs:2:5');
    expect(
      await provided.read<ReadingPositionRepository>().save(address),
      isA<Ok<void>>(),
    );
    expect(
      await provided.read<BookmarkRepository>().add(address, 'c'),
      isA<Ok<Object>>(),
    );
    provided.read<IntegrityLogRepository>().dispose();
    await provided.read<UserDatabase>().close();
  }

  test('a healthy file is written to', () async {
    final support = useTemporaryApplicationSupport();
    final file = await userFile(support);
    final before = file.readAsBytesSync();

    await startAndWrite();

    expect(file.readAsBytesSync(), isNot(before));
  });

  for (final table in tables) {
    test('without its $table table the app starts, keeps the data in '
        'memory and leaves the file as it is', () async {
      final support = useTemporaryApplicationSupport();
      final file = await userFile(support, drop: table);
      final before = file.readAsBytesSync();

      await startAndWrite();

      expect(file.readAsBytesSync(), before);
    });
  }

  test('a new install creates the file with every table', () async {
    final support = useTemporaryApplicationSupport();
    final file = File('${support.path}/${UserDatabase.fileName}');
    expect(file.existsSync(), isFalse);

    await startAndWrite();

    expect(file.existsSync(), isTrue);
    final raw = sqlite3.open(file.path, mode: OpenMode.readOnly);
    addTearDown(raw.close);
    expect(raw.select('PRAGMA user_version').single.values.single, 1);
    for (final table in tables) {
      expect(raw.select('SELECT 1 FROM "$table"'), isNotNull);
    }
  });

  // Drift runs onCreate for a file of version 0, which would write to it and
  // recreate a dropped table empty, before any check could read it.
  for (final (name, drop, version) in [
    ('of version 0 that lost a table', 'listening_position', 0),
    ('of version 0 with every table', null, 0),
    ('of a later version', null, 2),
  ]) {
    test('a file $name is not opened by drift and kept as it is', () async {
      final support = useTemporaryApplicationSupport();
      final file = await userFile(support, drop: drop, userVersion: version);
      final before = file.readAsBytesSync();

      await startAndWrite();

      expect(file.readAsBytesSync(), before);
    });
  }

  test('an empty file is a new install', () async {
    final support = useTemporaryApplicationSupport();
    final file = File('${support.path}/${UserDatabase.fileName}')
      ..writeAsBytesSync(const []);

    await startAndWrite();

    expect(file.lengthSync(), greaterThan(0));
  });

  test('a file that is not a database is kept as it is', () async {
    final support = useTemporaryApplicationSupport();
    final file = File('${support.path}/${UserDatabase.fileName}')
      ..writeAsStringSync('synthetic text that is not a database file' * 100);
    final before = file.readAsBytesSync();

    await startAndWrite();

    expect(file.readAsBytesSync(), before);
  });

  group('provideUserDatabase', () {
    Future<(Dependencies, UserDatabase)> over({String? drop}) async {
      final directory = Directory.systemTemp.createTempSync('user_database');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = await userFile(directory, drop: drop);
      final suspect = UserDatabase(NativeDatabase(file));
      addTearDown(suspect.close);
      late Dependencies provided;
      await buildDependencies(
        areas: [
          (dependencies) => provideUserDatabase(
            dependencies,
            locate: () async => file,
            open: (_) => suspect,
          ),
          (dependencies) async => provided = dependencies,
        ],
      );
      return (provided, suspect);
    }

    test('provides a readable database as it is', () async {
      final (dependencies, file) = await over();

      expect(dependencies.read<UserDatabase>(), same(file));
      await file.customSelect('SELECT 1').get();
    });

    test('replaces a database with an unreadable table by one in memory, and '
        'closes the file', () async {
      final (dependencies, file) = await over(drop: 'note');

      expect(dependencies.read<UserDatabase>(), isNot(same(file)));
      await expectLater(file.customSelect('SELECT 1').get(), throwsStateError);
    });
  });
}
