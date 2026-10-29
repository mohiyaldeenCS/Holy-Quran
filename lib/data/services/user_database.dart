import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'package:holyquran/data/services/user_tables.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

part 'user_database.g.dart';

/// The one read/write database of the user's own data (D-104). DAOs live in
/// `daos/` and take this database, so adding one leaves this class alone.
@DriftDatabase(
  tables: [
    Settings,
    ReadingPosition,
    ListeningPosition,
    Category,
    Bookmark,
    Tag,
    BookmarkTag,
    Note,
    NoteTag,
    SearchHistory,
    IntegrityEvent,
  ],
)
class UserDatabase extends _$UserDatabase {
  UserDatabase(super.executor);

  static const fileName = 'user.sqlite';

  /// Opens `user.sqlite` in the application-support directory, creating both
  /// when missing.
  static Future<UserDatabase> open() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return openFile(File.fromUri(directory.uri.resolve(fileName)));
  }

  /// The database in [file], created when missing; the file is opened by a
  /// background isolate.
  static UserDatabase openFile(File file) =>
      UserDatabase(NativeDatabase.createInBackground(file));

  /// Whether drift can open [file] without creating or migrating anything of
  /// the user's: it is missing or empty, as on a new install, or it is a
  /// database whose `user_version` is one this app wrote. Drift runs
  /// `onCreate` for a file of version 0 and so writes to it, which a plain
  /// read-only connection avoids.
  static bool canOpenAsIs(File file) {
    Database? probe;
    try {
      if (!file.existsSync() || file.lengthSync() == 0) return true;
      probe = sqlite3.open(file.path, mode: OpenMode.readOnly);
      final version =
          probe.select('PRAGMA user_version').single.values.single as int;
      return version >= 1 && version <= latestSchemaVersion;
    } on SqliteException {
      return false;
    } on FileSystemException {
      return false;
    } finally {
      probe?.close();
    }
  }

  /// A database held in memory only, for a start that has no file to open.
  static UserDatabase inMemory() => UserDatabase(NativeDatabase.memory());

  static const latestSchemaVersion = 1;

  @override
  int get schemaVersion => latestSchemaVersion;
}
