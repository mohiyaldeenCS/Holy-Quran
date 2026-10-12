import 'dart:io';

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
    return UserDatabase(
      NativeDatabase.createInBackground(
        File.fromUri(directory.uri.resolve(fileName)),
      ),
    );
  }

  @override
  int get schemaVersion => 1;
}
