import 'package:flutter/foundation.dart';

import 'package:holyquran/config/dependencies.dart';
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
