import 'package:flutter/foundation.dart';

import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/download_settings_repository.dart';
import 'package:holyquran/data/repositories/in_memory_app_settings_repository.dart';
import 'package:holyquran/data/services/daos/settings_dao.dart';
import 'package:holyquran/data/services/user_database.dart';

/// Provides the [AppSettingsRepository] over the user database, every
/// setting read before the first frame (D-105). Reading the Quran needs no
/// user data, so settings that cannot be read do not stop the start: the app
/// starts on the defaults, kept in memory only, and the user's file is left
/// as it is.
Future<void> settingsProviders(Dependencies dependencies) async {
  final dao = SettingsDao(dependencies.read<UserDatabase>());
  final settings = await _load(dao);
  dependencies
    ..provideListenable<AppSettingsRepository>(settings)
    // The file is suspect when the settings could not be read (D-133), so
    // nothing more is read from it.
    ..provideListenable<DownloadSettingsRepository>(
      settings is InMemoryAppSettingsRepository
          ? InMemoryDownloadSettingsRepository()
          : await _loadDownloads(dao),
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
