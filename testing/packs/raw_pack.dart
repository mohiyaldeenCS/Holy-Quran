import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

/// `PRAGMA application_id` of a text pack: ASCII `HQPK` (docs/CONTENT_PACKS.md).
const hqpkApplicationId = 1213288523;

/// The only pack format version this tooling knows.
const packFormatVersion = 1;

/// SHA-256 over `u32be(number) ‖ u32be(byte_length) ‖ bytes` for each field,
/// in the order given (docs/CONTENT_PACKS.md, "Surah digest").
///
/// A reference implementation written from the spec, independent of `lib/`.
String digestFields(Iterable<(int, List<int>)> fields) {
  final out = BytesBuilder(copy: false);
  for (final (number, bytes) in fields) {
    final prefix = ByteData(8)
      ..setUint32(0, number)
      ..setUint32(4, bytes.length);
    out
      ..add(prefix.buffer.asUint8List())
      ..add(bytes);
  }
  return sha256.convert(out.takeBytes()).toString();
}

/// The surah digest: the basmala, if any, as number 0, then the ayat
/// numbered from 1.
String surahDigest(List<List<int>> ayat, {List<int>? basmala}) => digestFields([
  if (basmala != null) (0, basmala),
  for (var i = 0; i < ayat.length; i++) (i + 1, ayat[i]),
]);

/// Lowercase hex SHA-256 of the whole file.
Future<String> fileSha256(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

/// The 100-byte SQLite file header, read from the file without SQLite.
final class RawHeader {
  RawHeader(this.bytes) : _data = ByteData.sublistView(bytes);

  static Future<RawHeader> read(File file) async {
    final handle = await file.open();
    try {
      return RawHeader(await handle.read(100));
    } finally {
      await handle.close();
    }
  }

  final Uint8List bytes;
  final ByteData _data;

  static const _magic = 'SQLite format 3\u0000';

  bool get hasMagic => String.fromCharCodes(bytes.sublist(0, 16)) == _magic;
  int get writeVersion => bytes[18];
  int get readVersion => bytes[19];
  int get freelistPages => _data.getUint32(36);

  /// 1 is UTF-8.
  int get textEncoding => _data.getUint32(56);
  int get userVersion => _data.getUint32(60);
  int get applicationId => _data.getUint32(68);
}

final class RawSurahRow {
  RawSurahRow(
    this.number,
    this.name,
    this.ayahCount,
    this.revelationPlace,
    this.revelationOrder,
    this.basmala,
  );

  final int number;
  final Uint8List name;
  final int ayahCount;
  final String? revelationPlace;
  final int? revelationOrder;
  final Uint8List? basmala;
}

final class RawColumn {
  RawColumn(this.name, this.type, {required this.notNull, required this.pk});

  final String name;
  final String type;
  final bool notNull;

  /// Position in the primary key, 0 when not part of it.
  final int pk;

  @override
  String toString() =>
      '$name $type${notNull ? ' NOT NULL' : ''}${pk > 0 ? ' pk$pk' : ''}';
}

final class RawTable {
  RawTable(this.name, {required this.strict, required this.withoutRowid});

  final String name;
  final bool strict;
  final bool withoutRowid;
}

/// An independent reader of a text pack: opens it read-only and immutable
/// and returns stored text as raw bytes (`CAST(... AS BLOB)`), so no Dart
/// decoder can alter it on the way.
final class RawPack {
  RawPack._(this._db);

  factory RawPack.open(File file) {
    final uri = Uri.file(
      file.absolute.path,
    ).replace(queryParameters: {'mode': 'ro', 'immutable': '1'});
    return RawPack._(
      sqlite3.open(uri.toString(), mode: OpenMode.readOnly, uri: true),
    );
  }

  final Database _db;

  void close() => _db.close();

  int get applicationId =>
      _db.select('PRAGMA application_id').single.columnAt(0) as int;
  int get userVersion => _db.userVersion;
  String get encoding =>
      _db.select('PRAGMA encoding').single.columnAt(0) as String;

  List<RawTable> tables() => [
    for (final row in _db.select(
      "SELECT name, strict, wr FROM pragma_table_list WHERE schema = 'main' "
      "AND name NOT LIKE 'sqlite_%' ORDER BY name",
    ))
      RawTable(
        row.columnAt(0) as String,
        strict: row.columnAt(1) == 1,
        withoutRowid: row.columnAt(2) == 1,
      ),
  ];

  List<RawColumn> columns(String table) => [
    for (final row in _db.select(
      'SELECT name, type, "notnull", pk FROM pragma_table_info(?) ORDER BY cid',
      [table],
    ))
      RawColumn(
        row.columnAt(0) as String,
        row.columnAt(1) as String,
        notNull: row.columnAt(2) == 1,
        pk: row.columnAt(3) as int,
      ),
  ];

  /// The `CREATE TABLE` statement as stored in `sqlite_schema`.
  String tableSql(String table) =>
      _db
              .select(
                "SELECT sql FROM sqlite_schema WHERE type = 'table' AND name = ?",
                [table],
              )
              .single
              .columnAt(0)
          as String;

  /// Each row is `(table, referenced table)` of a foreign key.
  Set<(String, String)> foreignKeys(String table) => {
    for (final row in _db.select(
      'SELECT "table" FROM pragma_foreign_key_list(?)',
      [table],
    ))
      (table, row.columnAt(0) as String),
  };

  List<String> integrityCheck() => [
    for (final row in _db.select('PRAGMA integrity_check'))
      row.columnAt(0) as String,
  ];

  int foreignKeyViolations() => _db.select('PRAGMA foreign_key_check').length;

  int count(String table) =>
      _db.select('SELECT count(*) FROM "$table"').single.columnAt(0) as int;

  Map<String, int> divisionCounts() => {
    for (final kind in const ['juz', 'hizb', 'rub', 'page'])
      kind:
          _db
                  .select('SELECT count(*) FROM division WHERE kind = ?', [
                    kind,
                  ])
                  .single
                  .columnAt(0)
              as int,
  };

  /// The storage classes found in [column] of [table], from `typeof`.
  Set<String> storageClasses(String table, String column) => {
    for (final row in _db.select(
      'SELECT DISTINCT typeof("$column") FROM "$table"',
    ))
      row.columnAt(0) as String,
  };

  List<RawSurahRow> surahs() => [
    for (final row in _db.select(
      'SELECT number, CAST(name AS BLOB), ayah_count, revelation_place, '
      'revelation_order, CAST(basmala AS BLOB) FROM surah ORDER BY number',
    ))
      RawSurahRow(
        row.columnAt(0) as int,
        row.columnAt(1) as Uint8List,
        row.columnAt(2) as int,
        row.columnAt(3) as String?,
        row.columnAt(4) as int?,
        row.columnAt(5) as Uint8List?,
      ),
  ];

  /// `(number, bytes)` of each ayah of [surah], in order.
  List<(int, Uint8List)> ayat(int surah) => [
    for (final row in _db.select(
      'SELECT number, CAST(text AS BLOB) FROM ayah WHERE surah = ? '
      'ORDER BY number',
      [surah],
    ))
      (row.columnAt(0) as int, row.columnAt(1) as Uint8List),
  ];

  /// `(number, start, end)` of each word of an ayah, in order.
  List<(int, int, int)> words(int surah, int ayah) => [
    for (final row in _db.select(
      'SELECT number, start_offset, end_offset FROM word '
      'WHERE surah = ? AND ayah = ? ORDER BY number',
      [surah, ayah],
    ))
      (row.columnAt(0) as int, row.columnAt(1) as int, row.columnAt(2) as int),
  ];

  /// `(number, after_word, start, end)` of each mark of an ayah, in order.
  List<(int, int, int, int)> marks(int surah, int ayah) => [
    for (final row in _db.select(
      'SELECT number, after_word, start_offset, end_offset FROM mark '
      'WHERE surah = ? AND ayah = ? ORDER BY number',
      [surah, ayah],
    ))
      (
        row.columnAt(0) as int,
        row.columnAt(1) as int,
        row.columnAt(2) as int,
        row.columnAt(3) as int,
      ),
  ];

  /// `(kind, number, surah, ayah)` of every division.
  List<(String, int, int, int)> divisions() => [
    for (final row in _db.select(
      'SELECT kind, number, surah, ayah FROM division ORDER BY kind, number',
    ))
      (
        row.columnAt(0) as String,
        row.columnAt(1) as int,
        row.columnAt(2) as int,
        row.columnAt(3) as int,
      ),
  ];

  List<(int, int)> sajdas() => [
    for (final row in _db.select(
      'SELECT surah, ayah FROM sajda ORDER BY surah, ayah',
    ))
      (row.columnAt(0) as int, row.columnAt(1) as int),
  ];

  /// The digest of [surah] over its stored bytes and stored numbers.
  String surahDigestOf(int surah) {
    final basmala = surahs().singleWhere((s) => s.number == surah).basmala;
    return digestFields([if (basmala != null) (0, basmala), ...ayat(surah)]);
  }
}
