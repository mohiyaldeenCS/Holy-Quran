import 'package:flutter/foundation.dart';

import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/user_database_providers.dart';
import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/download_settings_repository.dart';
import 'package:holyquran/data/repositories/in_memory_app_settings_repository.dart';
import 'package:holyquran/data/services/daos/settings_dao.dart';
import 'package:holyquran/data/services/user_database.dart';

/// Provides the [AppSettingsRepository] over the user database, every
/// setting read before the first frame (D-105). Reading the Quran needs no
/// user data, so settings that cannot be read do not stop the start: the app
/// starts on the defaults, kept in memory only, and the user's file is left
/// as it is: the areas after this one get a database in memory
/// ([useDatabaseInMemory], D-133). The database area has already checked that
/// every table can be read, so this is for settings whose rows are not.
Future<void> settingsProviders(Dependencies dependencies) async {
  final database = dependencies.read<UserDatabase>();
  final loaded = await _load(SettingsDao(database));
  if (loaded == null) {
    final memory = useDatabaseInMemory(dependencies);
    if (!identical(memory, database)) await releaseDatabase(database);
  }
  dependencies
    ..provideListenable<AppSettingsRepository>(
      loaded ?? InMemoryAppSettingsRepository(),
    )
    // The file is suspect when the settings could not be read (D-133), and
    // the database may be released, so nothing more is read from it.
    ..provideListenable<DownloadSettingsRepository>(
      loaded == null
          ? InMemoryDownloadSettingsRepository()
          : await _loadDownloads(SettingsDao(database)),
    );
}

/// The download choices (`AU-13`, `AU-14`), on the defaults when unreadable.
Future<DownloadSettingsRepository> _loadDownloads(SettingsDao dao) async {
  try {
    return await LocalDownloadSettingsRepository.load(dao);
  } on Exception catch (error, stack) {
    debugPrint('Download settings unreadable, using the defaults: $error');
    debugPrintStack(stackTrace: stack);
    return InMemoryDownloadSettingsRepository();
  }
}

Future<AppSettingsRepository?> _load(SettingsDao dao) async {
  try {
    return await LocalAppSettingsRepository.load(dao);
  } on Exception catch (error) {
    // The integrity log is kept in the same unreadable database; the
    // failure stays on the device.
    debugPrint('Settings unreadable, starting on the defaults: $error');
    return null;
  }
}
