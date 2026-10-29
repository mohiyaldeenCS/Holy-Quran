import 'package:flutter/foundation.dart';

import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/user_database_providers.dart';
import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/in_memory_app_settings_repository.dart';
import 'package:holyquran/data/services/daos/settings_dao.dart';
import 'package:holyquran/data/services/user_database.dart';

/// Provides the [AppSettingsRepository] over the user database, every
/// setting read before the first frame (D-105). Reading the Quran needs no
/// user data, so settings that cannot be read do not stop the start: the app
/// starts on the defaults, kept in memory only, and the user's file is left
/// as it is: the areas after this one get a database in memory
/// ([useDatabaseInMemory], D-133).
Future<void> settingsProviders(Dependencies dependencies) async {
  final database = dependencies.read<UserDatabase>();
  final loaded = await _load(SettingsDao(database));
  if (loaded == null) {
    useDatabaseInMemory(dependencies);
    await _release(database);
  }
  dependencies.provideListenable<AppSettingsRepository>(
    loaded ?? InMemoryAppSettingsRepository(),
  );
}

Future<AppSettingsRepository?> _load(SettingsDao dao) async {
  try {
    return await LocalAppSettingsRepository.load(dao);
  } on Exception catch (error, stack) {
    // The integrity log is kept in the same unreadable database; the
    // failure stays on the device.
    debugPrint('Settings unreadable, starting on the defaults: $error');
    debugPrintStack(stackTrace: stack);
    return null;
  }
}

/// Nothing reads the suspect file any more; closing it frees the file.
Future<void> _release(UserDatabase database) async {
  try {
    await database.close();
  } on Exception catch (error) {
    debugPrint('The unreadable user database did not close: $error');
  }
}
