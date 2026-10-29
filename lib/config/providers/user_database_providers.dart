import 'package:flutter/foundation.dart';

import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/data/services/user_database.dart';

/// Provides the user's database in application support for the areas after
/// this one, once it has been checked (D-133): every table the schema
/// declares must be readable. If any is not, the user's file is suspect, and
/// the database every area uses is one kept in memory ([useDatabaseInMemory]),
/// so that nothing of the user's is ever written to the file. Without an
/// application support folder there is no file: the database is in memory
/// from the start.
Future<void> userDatabaseProviders(Dependencies dependencies) =>
    provideUserDatabase(dependencies, open: _open);

/// [userDatabaseProviders] over the database [open] returns.
Future<void> provideUserDatabase(
  Dependencies dependencies, {
  required Future<UserDatabase> Function() open,
}) async {
  final database = await open();
  dependencies.provide<UserDatabase>(database);
  if (!await _readable(database)) {
    useDatabaseInMemory(dependencies);
    await releaseDatabase(database);
  }
}

/// Whether the file is a database whose pages are sound and whose every
/// table can be read. Drift creates a new file's tables on the first query.
Future<bool> _readable(UserDatabase database) async {
  try {
    final check = await database.customSelect('PRAGMA quick_check').get();
    if (check.length != 1 || check.single.data.values.single != 'ok') {
      return false;
    }
    for (final table in database.allTables) {
      await database
          .customSelect('SELECT 1 FROM "${table.actualTableName}" LIMIT 1')
          .get();
    }
    return true;
  } on Exception catch (error) {
    debugPrint('User data unreadable, keeping it in memory: $error');
    return false;
  }
}

Future<UserDatabase> _open() async {
  try {
    return await UserDatabase.open();
  } on Exception catch (error, stack) {
    debugPrint('No application support folder, user data in memory: $error');
    debugPrintStack(stackTrace: stack);
    return UserDatabase.inMemory();
  }
}

/// Replaces the user's database, for the areas after this call and for the
/// widget tree, by one kept in memory (D-133): the user's file is suspect, so
/// nothing of the user's is written to it from here on. There is one such
/// database per [Dependencies]; asking again gives the same.
UserDatabase useDatabaseInMemory(Dependencies dependencies) {
  if (_fallbacks[dependencies] case final existing?) return existing;
  final memory = _fallbacks[dependencies] = UserDatabase.inMemory();
  dependencies.replace<UserDatabase>(memory);
  return memory;
}

final _fallbacks = Expando<UserDatabase>('user database in memory');

/// Closes a database nothing reads any more, to free its file.
Future<void> releaseDatabase(UserDatabase database) async {
  try {
    await database.close();
  } on Exception catch (error) {
    debugPrint('The unreadable user database did not close: $error');
  }
}
