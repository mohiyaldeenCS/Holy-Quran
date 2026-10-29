import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/data/services/catalogue_service.dart';
import 'package:holyquran/data/services/user_database.dart';

/// Provides the user's database in application support for the areas after
/// this one, once it has been checked (D-133). An existing file that drift
/// could not open without writing to it, such as one of version 0, is not
/// opened at all. An opened one must have every table the schema declares
/// readable. In either case the user's file is suspect, and the database every
/// area uses is one kept in memory ([useDatabaseInMemory]), so that nothing of
/// the user's is ever written to the file. A new install has no file and
/// creates it. Without an application support folder the database is in
/// memory from the start.
Future<void> userDatabaseProviders(Dependencies dependencies) =>
    provideUserDatabase(dependencies, locate: _locate);

/// [userDatabaseProviders] over the file [locate] finds, which [open] opens.
Future<void> provideUserDatabase(
  Dependencies dependencies, {
  required Future<File?> Function() locate,
  UserDatabase Function(File file) open = UserDatabase.openFile,
}) async {
  final file = await locate();
  if (file == null) {
    dependencies.provide<UserDatabase>(UserDatabase.inMemory());
    return;
  }
  if (!UserDatabase.canOpenAsIs(file)) {
    debugPrint('User database not opened, user data in memory: ${file.path}');
    final memory = _fallbacks[dependencies] = UserDatabase.inMemory();
    dependencies.provide<UserDatabase>(memory);
    return;
  }
  final database = open(file);
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

Future<File?> _locate() async {
  try {
    final directory = Directory(await applicationSupportPath());
    await directory.create(recursive: true);
    return File('${directory.path}/${UserDatabase.fileName}');
  } on Exception catch (error) {
    debugPrint('No application support folder, user data in memory: $error');
    return null;
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
