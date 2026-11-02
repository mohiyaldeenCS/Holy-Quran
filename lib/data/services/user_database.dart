import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'package:holyquran/data/services/user_tables.dart';
import 'package:path_provider/path_provider.dart';

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
  /// SQLite file whose `user_version` is one this app wrote. Drift runs
  /// `onCreate` for a file of version 0 and so writes to it; the version is
  /// read from the file's 100-byte header, at offset 60, without opening it as
  /// a database.
  static bool canOpenAsIs(File file) {
    const headerBytes = 100;
    const versionOffset = 60;
    const magic = 'SQLite format 3\x00';
    try {
      if (!file.existsSync() || file.lengthSync() == 0) return true;
      final reader = file.openSync();
      final List<int> header;
      try {
        header = reader.readSync(headerBytes);
      } finally {
        reader.closeSync();
      }
      if (header.length < headerBytes ||
          String.fromCharCodes(header.take(magic.length)) != magic) {
        return false;
      }
      final version = ByteData.sublistView(Uint8List.fromList(header))
          .getUint32(versionOffset);
      return version >= 1 && version <= latestSchemaVersion;
    } on FileSystemException {
      return false;
    }
  }

  /// A database held in memory only, for a start that has no file to open.
  static UserDatabase inMemory() => UserDatabase(NativeDatabase.memory());

  static const latestSchemaVersion = 1;

  @override
  int get schemaVersion => latestSchemaVersion;
}
