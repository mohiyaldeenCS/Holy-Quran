import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../domain/models/edition_map.dart';
import '../../domain/models/pack_failure.dart';
import '../../domain/models/pack_text.dart';
import '../../domain/models/quran_address.dart';
import '../../domain/models/search_form.dart';
import '../../domain/models/surah_info.dart';

/// The first ayah of a division unit, as stored.
typedef DivisionRow = ({Division kind, int number, int surah, int ayah});

/// A word of an ayah, as stored: offsets in UTF-16 code units, not yet
/// checked against the ayah.
typedef WordRow = ({int number, int start, int end});

/// A mark of an ayah, as stored: offsets in UTF-16 code units and the word
/// it follows, not yet checked against the ayah or its words.
typedef MarkRow = ({int number, int afterWord, int start, int end});

/// The number of rows of each table of a text pack.
typedef PackRowCounts = ({
  int surahs,
  int ayat,
  int words,
  int marks,
  Map<Division, int> divisions,
  int sajdas,
});

/// A column of a pack table: its name, type, NOT NULL and position in the
/// primary key (0 when outside it).
typedef PackColumn = (String name, String type, bool notNull, int primaryKey);

/// A pack table: whether it is WITHOUT ROWID, and its columns in order.
typedef PackTable = (bool withoutRowid, List<PackColumn> columns);

/// A pack data file of any kind (docs/CONTENT_PACKS.md), opened read-only and
/// immutable once its header, `application_id`, `user_version` and schema
/// are those the format gives. It is the one opener of pack files (D-061),
/// and its [PackRow]s the one place that turns stored text into [PackText]:
/// every text is read as its stored bytes and decoded as strict UTF-8.
///
/// Failures are thrown as [PackFailure]s naming the file:
/// [FileHashMismatch] when there is no readable file, [UnsupportedPackFormat]
/// when the file is not of the expected version and schema.
final class PackSqliteFile {
  PackSqliteFile._(this._db, this.path, this.formatVersion);

  /// Opens the pack file at [path]; no file is ever created. [schema] holds
  /// every table the file must have, and no other.
  static PackSqliteFile open(
    String path, {
    required int formatVersion,
    required Map<String, PackTable> schema,
  }) {
    try {
      _checkHeader(path, formatVersion);
    } on FileSystemException {
      throw FileHashMismatch(path, Uri.file(path).pathSegments.last);
    }
    final Database db;
    try {
      db = sqlite3.open(
        'file:${Uri.file(path).path}?mode=ro&immutable=1',
        mode: OpenMode.readOnly,
        uri: true,
      );
    } on SqliteException {
      throw UnsupportedPackFormat(path, formatVersion);
    }
    final file = PackSqliteFile._(db, path, formatVersion);
    try {
      if (file.integer('PRAGMA application_id') != _applicationId) {
        file.unsupported();
      }
      final userVersion = file.integer('PRAGMA user_version');
      if (userVersion != formatVersion) {
        throw UnsupportedPackFormat(path, userVersion);
      }
      file._checkSchema(schema);
    } on PackFailure {
      db.close();
      rethrow;
    }
    return file;
  }

  /// ASCII `HQPK`.
  static const _applicationId = 1213288523;
  static const _headerLength = 100;
  static const _magic = 'SQLite format 3\u{0}';
  static const _utf8Encoding = 1;

  final Database _db;
  final String path;
  final int formatVersion;

  /// The magic string, rollback journal (bytes 18 and 19 are 1, so no WAL)
  /// and UTF-8 text, read from the file before SQLite opens it.
  static void _checkHeader(String path, int formatVersion) {
    final file = File(path).openSync();
    final Uint8List header;
    try {
      header = file.readSync(_headerLength);
    } finally {
      file.closeSync();
    }
    if (header.length < _headerLength ||
        String.fromCharCodes(header, 0, _magic.length) != _magic ||
        header[18] != 1 ||
        header[19] != 1 ||
        ByteData.sublistView(header).getUint32(56) != _utf8Encoding) {
      throw UnsupportedPackFormat(path, formatVersion);
    }
  }

  /// Exactly the tables of [schema], each STRICT, with exactly its columns
  /// and none hidden or generated, so that every value read has the type and
  /// nullability the reads assume.
  void _checkSchema(Map<String, PackTable> schema) {
    final tables = {
      for (final row in _db.select(
        'SELECT name, type, wr, strict FROM pragma_table_list '
        r"WHERE schema = 'main' AND name NOT LIKE 'sqlite\_%' ESCAPE '\'",
      ))
        row.columnAt(0) as String: (
          type: row.columnAt(1),
          withoutRowid: row.columnAt(2) == 1,
          strict: row.columnAt(3) == 1,
        ),
    };
    if (tables.length != schema.length) unsupported();
    for (final MapEntry(key: table, value: (withoutRowid, columns))
        in schema.entries) {
      final found = tables[table];
      if (found == null ||
          found.type != 'table' ||
          !found.strict ||
          found.withoutRowid != withoutRowid) {
        unsupported();
      }
      final stored = [
        for (final row in _db.select(
          'SELECT name, type, "notnull", pk, hidden FROM pragma_table_xinfo(?) '
          'ORDER BY cid',
          [table],
        ))
          (
            row.columnAt(0),
            row.columnAt(1),
            row.columnAt(2) == 1,
            row.columnAt(3),
            row.columnAt(4) == 0,
          ),
      ];
      if (stored.length != columns.length) unsupported();
      for (final (index, (name, type, notNull, pk)) in columns.indexed) {
        if (stored[index] != (name, type, notNull, pk, true)) unsupported();
      }
    }
  }

  Never unsupported() => throw UnsupportedPackFormat(path, formatVersion);

  void close() => _db.close();

  /// The rows of a query. A query SQLite refuses, or a text column read as a
  /// plain string that is not UTF-8, is [UnsupportedPackFormat].
  List<PackRow> select(String sql, [List<Object?> parameters = const []]) {
    try {
      return [for (final row in _db.select(sql, parameters)) PackRow._(row)];
    } on SqliteException {
      unsupported();
    } on FormatException {
      unsupported();
    }
  }

  /// The one integer a query returns.
  int integer(String sql, [List<Object?> parameters = const []]) =>
      select(sql, parameters).single.integer(0);
}

/// A row a [PackSqliteFile] returned. The schema check fixes each column's
/// type, so a read of the wrong type is a programming error.
final class PackRow {
  PackRow._(this._row);

  final Row _row;

  int integer(int column) => _row.columnAt(column) as int;

  int? nullableInteger(int column) => _row.columnAt(column) as int?;

  /// A value the format restricts to a closed set or a pattern, such as a
  /// kind, a path or a hash; never a text shown as it is stored.
  String string(int column) => _row.columnAt(column) as String;

  String? nullableString(int column) => _row.columnAt(column) as String?;

  /// The stored bytes of a text column selected as `CAST(... AS BLOB)`.
  Uint8List? nullableBytes(int column) => _row.columnAt(column) as Uint8List?;

  /// The text of a column selected as `CAST(... AS BLOB)`, decoded with no
  /// change. [rejected] is thrown when the bytes are not strict UTF-8 or
  /// begin with EF BB BF, which Dart's decoder would discard without notice.
  PackText text(int column, PackFailure Function() rejected) =>
      nullableText(column, rejected) ?? (throw rejected());

  /// Null when the column holds NULL; otherwise as [text].
  PackText? nullableText(int column, PackFailure Function() rejected) {
    final bytes = nullableBytes(column);
    if (bytes == null) return null;
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      throw rejected();
    }
    try {
      // Spelled out so that a reader sees that malformed bytes are refused.
      // ignore: avoid_redundant_argument_values
      return PackText.fromPack(utf8.decode(bytes, allowMalformed: false));
    } on FormatException {
      throw rejected();
    }
  }
}

/// A text pack's `text.sqlite` (docs/CONTENT_PACKS.md, "Text pack"), format
/// 1 or 2, opened through [PackSqliteFile]. It runs only queries.
///
/// Failures are thrown as [PackFailure]s naming the file:
/// [FileHashMismatch] when there is no readable file, [UnsupportedPackFormat]
/// when the file is not a text pack of the expected version,
/// [TextEncodingRejected] when a text is not strict UTF-8 or begins with
/// U+FEFF, [PackInconsistent] when a search form breaks the format.
final class PackDatabase {
  PackDatabase._(this._file);

  /// Opens the pack file at [path]. Throws [UnsupportedPackFormat] when
  /// [formatVersion] is not one of a text pack, or the header,
  /// `application_id`, `user_version` or schema is not that of a text pack
  /// of [formatVersion], and [FileHashMismatch] when there is no readable
  /// file at [path]; no file is ever created.
  static PackDatabase open(String path, {required int formatVersion}) =>
      PackDatabase._(
        PackSqliteFile.open(
          path,
          formatVersion: formatVersion,
          schema:
              _schemas[formatVersion] ??
              (throw UnsupportedPackFormat(path, formatVersion)),
        ),
      );

  /// The tables of docs/CONTENT_PACKS.md, "Text pack".
  static const _v1 = {
    'surah': (
      false,
      [
        ('number', 'INTEGER', false, 1),
        ('name', 'TEXT', true, 0),
        ('ayah_count', 'INTEGER', true, 0),
        ('revelation_place', 'TEXT', false, 0),
        ('revelation_order', 'INTEGER', false, 0),
        ('basmala', 'TEXT', false, 0),
      ],
    ),
    'ayah': (
      true,
      [
        ('surah', 'INTEGER', true, 1),
        ('number', 'INTEGER', true, 2),
        ('text', 'TEXT', true, 0),
      ],
    ),
    'word': (
      true,
      [
        ('surah', 'INTEGER', true, 1),
        ('ayah', 'INTEGER', true, 2),
        ('number', 'INTEGER', true, 3),
        ('start_offset', 'INTEGER', true, 0),
        ('end_offset', 'INTEGER', true, 0),
      ],
    ),
    'mark': (
      true,
      [
        ('surah', 'INTEGER', true, 1),
        ('ayah', 'INTEGER', true, 2),
        ('number', 'INTEGER', true, 3),
        ('after_word', 'INTEGER', true, 0),
        ('start_offset', 'INTEGER', true, 0),
        ('end_offset', 'INTEGER', true, 0),
      ],
    ),
    'division': (
      true,
      [
        ('kind', 'TEXT', true, 1),
        ('number', 'INTEGER', true, 2),
        ('surah', 'INTEGER', true, 0),
        ('ayah', 'INTEGER', true, 0),
      ],
    ),
    'sajda': (
      true,
      [('surah', 'INTEGER', true, 1), ('ayah', 'INTEGER', true, 2)],
    ),
  };

  /// The schema of each format version: version 2 adds `search_form`.
  static const _schemas = {
    1: _v1,
    2: {
      ..._v1,
      'search_form': (
        true,
        [
          ('surah', 'INTEGER', true, 1),
          ('ayah', 'INTEGER', true, 2),
          ('word', 'INTEGER', true, 3),
          ('kind', 'TEXT', true, 4),
          ('form', 'TEXT', true, 0),
        ],
      ),
    },
  };

  final PackSqliteFile _file;

  String get _path => _file.path;

  bool get _hasSearchForms => _file.formatVersion >= 2;

  Never _unsupported() => _file.unsupported();

  void close() => _file.close();

  /// Every surah, in order.
  List<SurahInfo> surahs() => [
    for (final row in _file.select(
      'SELECT number, CAST(name AS BLOB), ayah_count, revelation_place, '
      'revelation_order FROM surah ORDER BY number',
    ))
      SurahInfo(
        number: row.integer(0),
        name: row.text(
          1,
          () => TextEncodingRejected(_path, row.integer(0), null),
        ),
        ayahCount: row.integer(2),
        revelationPlace: switch (row.nullableString(3)) {
          'makki' => RevelationPlace.makki,
          'madani' => RevelationPlace.madani,
          null => null,
          _ => _unsupported(),
        },
        revelationOrder: row.nullableInteger(4),
      ),
  ];

  /// The basmala stored for [surah], or null when it has none.
  PackText? basmala(int surah) => switch (_file.select(
    'SELECT CAST(basmala AS BLOB) FROM surah WHERE number = ?',
    [surah],
  )) {
    [final row] => row.nullableText(
      0,
      () => TextEncodingRejected(_path, surah, null),
    ),
    _ => null,
  };

  /// The text of ayah [ayah] of [surah], or null when there is none.
  PackText? ayahText(int surah, int ayah) => switch (_file.select(
    'SELECT CAST(text AS BLOB) FROM ayah WHERE surah = ? AND number = ?',
    [surah, ayah],
  )) {
    [final row] => row.text(0, () => TextEncodingRejected(_path, surah, ayah)),
    _ => null,
  };

  /// The words of an ayah, by number; empty when there is no such ayah.
  List<WordRow> words(int surah, int ayah) => [
    for (final row in _file.select(
      'SELECT number, start_offset, end_offset FROM word '
      'WHERE surah = ? AND ayah = ? ORDER BY number',
      [surah, ayah],
    ))
      (number: row.integer(0), start: row.integer(1), end: row.integer(2)),
  ];

  /// The marks of an ayah, by number; empty when there is no such ayah.
  List<MarkRow> marks(int surah, int ayah) => [
    for (final row in _file.select(
      'SELECT number, after_word, start_offset, end_offset FROM mark '
      'WHERE surah = ? AND ayah = ? ORDER BY number',
      [surah, ayah],
    ))
      (
        number: row.integer(0),
        afterWord: row.integer(1),
        start: row.integer(2),
        end: row.integer(3),
      ),
  ];

  /// The search forms of the words of [surah] in [riwaya], by ayah, word and
  /// kind, as the source gives them; empty for a format 1 pack, which has
  /// none, and for a surah that is not stored. A kind not of the form of
  /// [SearchForm.kindPattern] is [PackInconsistent].
  List<SearchForm> searchForms(int surah, {required String riwaya}) {
    if (!_hasSearchForms) return const [];
    return [
      for (final row in _file.select(
        'SELECT ayah, word, kind, CAST(form AS BLOB) FROM search_form '
        'WHERE surah = ? ORDER BY ayah, word, kind',
        [surah],
      ))
        _searchForm(riwaya, surah, row),
    ];
  }

  SearchForm _searchForm(String riwaya, int surah, PackRow row) {
    final ayah = row.integer(0);
    final form = row.text(3, () => TextEncodingRejected(_path, surah, ayah));
    try {
      return SearchForm(
        word: QuranAddress(riwaya, surah, ayah, row.integer(1)),
        kind: row.string(2),
        form: form,
      );
    } on ArgumentError catch (error) {
      throw PackInconsistent(_path, 'search form of $surah:$ayah: $error');
    }
  }

  /// The number of search forms of each kind; empty for a format 1 pack.
  Map<String, int> searchFormCounts() => !_hasSearchForms
      ? const {}
      : {
          for (final row in _file.select(
            'SELECT kind, count(*) FROM search_form GROUP BY kind ORDER BY kind',
          ))
            row.string(0): row.integer(1),
        };

  /// Every division unit, by kind and number.
  List<DivisionRow> divisions() => [
    for (final row in _file.select(
      'SELECT kind, number, surah, ayah FROM division ORDER BY kind, number',
    ))
      (
        kind: switch (row.string(0)) {
          'juz' => Division.juz,
          'hizb' => Division.hizb,
          'rub' => Division.rub,
          'page' => Division.page,
          _ => _unsupported(),
        },
        number: row.integer(1),
        surah: row.integer(2),
        ayah: row.integer(3),
      ),
  ];

  /// Every ayah carrying a sajda, in order.
  List<(int surah, int ayah)> sajdas() => [
    for (final row in _file.select(
      'SELECT surah, ayah FROM sajda ORDER BY surah, ayah',
    ))
      (row.integer(0), row.integer(1)),
  ];

  PackRowCounts rowCounts() => (
    surahs: _file.integer('SELECT count(*) FROM surah'),
    ayat: _file.integer('SELECT count(*) FROM ayah'),
    words: _file.integer('SELECT count(*) FROM word'),
    marks: _file.integer('SELECT count(*) FROM mark'),
    divisions: {
      for (final division in Division.values)
        division: _file.integer(
          'SELECT count(*) FROM division WHERE kind = ?',
          [division.name],
        ),
    },
    sajdas: _file.integer('SELECT count(*) FROM sajda'),
  );

  /// The digest of docs/CONTENT_PACKS.md, "Surah digest", over the stored
  /// bytes and numbers of [surah]; null when there is no such surah.
  String? surahSha256(int surah) {
    final basmala = _file.select(
      'SELECT CAST(basmala AS BLOB) FROM surah WHERE number = ?',
      [surah],
    );
    if (basmala.isEmpty) return null;
    late final Digest digest;
    final input = sha256.startChunkedConversion(
      ChunkedConversionSink<Digest>.withCallback(
        (digests) => digest = digests.single,
      ),
    );
    void add(int number, Uint8List bytes) {
      final prefix = ByteData(8)
        ..setUint32(0, number)
        ..setUint32(4, bytes.length);
      input
        ..add(prefix.buffer.asUint8List())
        ..add(bytes);
    }

    if (basmala.single.nullableBytes(0) case final bytes?) add(0, bytes);
    for (final row in _file.select(
      'SELECT number, CAST(text AS BLOB) FROM ayah WHERE surah = ? '
      'ORDER BY number',
      [surah],
    )) {
      add(row.integer(0), row.nullableBytes(1)!);
    }
    input.close();
    return digest.toString();
  }
}
