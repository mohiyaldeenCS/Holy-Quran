import 'package:flutter/foundation.dart';

import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/in_memory_app_settings_repository.dart';
import 'package:holyquran/data/services/daos/settings_dao.dart';
import 'package:holyquran/data/services/user_database.dart';

/// Provides the [AppSettingsRepository] over the user database, every
/// setting read before the first frame (D-105). Reading the Quran needs no
/// user data, so settings that cannot be read do not stop the start: the app
/// starts on the defaults, kept in memory only, and the user's file is left
/// as it is.
Future<void> settingsProviders(Dependencies dependencies) async =>
    dependencies.provideListenable<AppSettingsRepository>(
      await _load(SettingsDao(dependencies.read<UserDatabase>())),
    );

Future<AppSettingsRepository> _load(SettingsDao dao) async {
  try {
    return await LocalAppSettingsRepository.load(dao);
  } on Exception catch (error, stack) {
    // The integrity log is kept in the same unreadable database; the
    // failure stays on the device.
    debugPrint('Settings unreadable, starting on the defaults: $error');
    debugPrintStack(stackTrace: stack);
    return InMemoryAppSettingsRepository();
  }
}
