import 'package:flutter/foundation.dart';

import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/in_memory_app_settings_repository.dart';
import 'package:holyquran/data/services/user_database.dart';

/// Provides the user's database in application support for the areas after
/// this one. Drift opens the file lazily, so a file that cannot be read fails
/// at the first read, in the area that reads it. Without an application
/// support folder there is no file: the database is kept in memory, and
/// nothing is written to disk.
Future<void> userDatabaseProviders(Dependencies dependencies) async =>
    dependencies.provide<UserDatabase>(await _open());

Future<UserDatabase> _open() async {
  try {
    return await UserDatabase.open();
  } on Exception catch (error, stack) {
    debugPrint('No application support folder, user data in memory: $error');
    debugPrintStack(stackTrace: stack);
    return UserDatabase.inMemory();
  }
}

/// The database that the areas after the settings write to. When the
/// settings could not be read (D-133) the user's file is suspect, so it is
/// an in-memory database that nothing of the user's reaches the disk from;
/// each area that asks gets its own.
UserDatabase userDataDatabase(Dependencies dependencies) =>
    dependencies.read<AppSettingsRepository>() is InMemoryAppSettingsRepository
    ? UserDatabase.inMemory()
    : dependencies.read<UserDatabase>();
