import 'package:drift/drift.dart';

// Schema v1 of the user database (D-104). Rows hold canonical addresses
// (D-063) and the user's own content, never Quran text. Times are UTC
// milliseconds: drift's DateTimeColumn keeps whole seconds, too coarse to tell
// the newer of two edits (PRD §10.6). Synced rows carry a random 128-bit id,
// `updated_at`, and `deleted` as the tombstone, so a deletion is never undone
// by a merge.
//
// No foreign keys and no indexes: enforcing either puts SQL text in lib/data/,
// which the pack-write guard forbids.

/// Typed values keyed by name, newest per key (§10.6). The key is the shared
/// id; a setting is reset by writing its default, never deleted.
@DataClassName('SettingRow')
class Settings extends Table {
  @override
  String get tableName => 'settings';

  TextColumn get key => text()();
  IntColumn get intValue => integer().nullable()();
  RealColumn get realValue => real().nullable()();
  TextColumn get textValue => text().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

mixin _Synced on Table {
  TextColumn get id => text()();
  IntColumn get updatedAt => integer()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The last ayah read on this device (D-106).
@DataClassName('ReadingPositionRow')
class ReadingPosition extends Table with _Synced {
  @override
  String get tableName => 'reading_position';

  TextColumn get address => text()();
}

/// The last place listened to on this device (D-106).
@DataClassName('ListeningPositionRow')
class ListeningPosition extends Table with _Synced {
  @override
  String get tableName => 'listening_position';

  TextColumn get address => text()();
  TextColumn get recitationId => text()();
  IntColumn get offsetMs => integer()();
}

/// A bookmark or note category: a built-in one by key, whose id equals its
/// key so devices agree, or one the user named. The colour and shape slots
/// stay empty until O-14 is answered.
@DataClassName('CategoryRow')
class Category extends Table with _Synced {
  @override
  String get tableName => 'category';

  TextColumn get builtinKey => text().nullable().unique()();
  TextColumn get name => text().nullable()();
  IntColumn get colourSlot => integer().nullable()();
  IntColumn get shapeSlot => integer().nullable()();
  IntColumn get createdAt => integer()();
}

@DataClassName('BookmarkRow')
class Bookmark extends Table with _Synced {
  @override
  String get tableName => 'bookmark';

  TextColumn get address => text()();
  TextColumn get categoryId => text()();
  IntColumn get createdAt => integer()();
}

@DataClassName('TagRow')
class Tag extends Table with _Synced {
  @override
  String get tableName => 'tag';

  TextColumn get name => text()();
  IntColumn get createdAt => integer()();
}

/// Keyed by the pair, so the same pair made on two devices merges into one
/// row.
@DataClassName('BookmarkTagRow')
class BookmarkTag extends Table {
  @override
  String get tableName => 'bookmark_tag';

  TextColumn get bookmarkId => text()();
  TextColumn get tagId => text()();
  IntColumn get updatedAt => integer()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {bookmarkId, tagId};
}

@DataClassName('NoteRow')
class Note extends Table with _Synced {
  @override
  String get tableName => 'note';

  TextColumn get address => text()();
  TextColumn get body => text()();
  TextColumn get categoryId => text().nullable()();
  IntColumn get createdAt => integer()();
}

/// Keyed by the pair, as [BookmarkTag].
@DataClassName('NoteTagRow')
class NoteTag extends Table {
  @override
  String get tableName => 'note_tag';

  TextColumn get noteId => text()();
  TextColumn get tagId => text()();
  IntColumn get updatedAt => integer()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {noteId, tagId};
}

/// Local only and cleared by deleting its rows (`SR-10`).
@DataClassName('SearchHistoryRow')
class SearchHistory extends Table {
  @override
  String get tableName => 'search_history';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get query => text()();
  IntColumn get searchedAt => integer()();
}

/// The local integrity log: what a pack check found. `detail` holds hashes,
/// counts and kinds, never pack text.
@DataClassName('IntegrityEventRow')
class IntegrityEvent extends Table {
  @override
  String get tableName => 'integrity_event';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get packId => text()();
  IntColumn get packVersion => integer()();
  TextColumn get kind => text()();
  TextColumn get detail => text().nullable()();
  IntColumn get occurredAt => integer()();
}
