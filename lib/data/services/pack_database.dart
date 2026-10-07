import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../domain/models/edition_map.dart';
import '../../domain/models/pack_failure.dart';
import '../../domain/models/pack_text.dart';
import '../../domain/models/surah_info.dart';
import '../../domain/models/word_span.dart';

/// The first ayah of a division unit, as stored.
typedef DivisionRow = ({Division kind, int number, int surah, int ayah});

/// The number of rows of each table of a text pack.
typedef PackRowCounts = ({
  int surahs,
  int ayat,
  int words,
  Map<Division, int> divisions,
  int sajdas,
});

/// A text pack's `text.sqlite` (docs/CONTENT_PACKS.md, "Text pack"), opened
/// read-only and immutable. It runs only queries, and it is the only place
/// that turns stored text into [PackText]: every text is read as its stored
/// bytes and decoded as strict UTF-8.
///
/// Failures are thrown as [PackFailure]s naming the file:
/// [UnsupportedPackFormat] when the file is not a text pack of the expected
/// version, [TextEncodingRejected] when a text is not strict UTF-8 or begins
/// with U+FEFF.
final class PackDatabase {
  PackDatabase._(this._db, this._path, this._formatVersion);

  /// Opens the pack file at [path]. Throws [UnsupportedPackFormat] when the
  /// header, `application_id` or `user_version` is not that of a text pack of
  /// [formatVersion], and a [FileSystemException] when there is no readable
  /// file at [path]; no file is ever created.
  static PackDatabase open(String path, {required int formatVersion}) {
    _checkHeader(path, formatVersion);
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
    final pack = PackDatabase._(db, path, formatVersion);
    try {
      if (pack._integer('PRAGMA application_id') != _applicationId) {
        throw UnsupportedPackFormat(path, formatVersion);
      }
      final userVersion = pack._integer('PRAGMA user_version');
      if (userVersion != formatVersion) {
        throw UnsupportedPackFormat(path, userVersion);
      }
    } on PackFailure {
      db.close();
      rethrow;
    }
    return pack;
  }

  /// ASCII `HQPK`.
  static const _applicationId = 1213288523;
  static const _headerLength = 100;
  static const _magic = 'SQLite format 3\u{0}';
  static const _utf8Encoding = 1;

  final Database _db;
  final String _path;
  final int _formatVersion;

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

  void close() => _db.close();

  /// Every surah, in order.
  List<SurahInfo> surahs() => [
    for (final row in _select(
      'SELECT number, CAST(name AS BLOB), ayah_count, revelation_place, '
      'revelation_order FROM surah ORDER BY number',
    ))
      SurahInfo(
        number: row.columnAt(0) as int,
        name: _text(row.columnAt(1) as Uint8List, row.columnAt(0) as int),
        ayahCount: row.columnAt(2) as int,
        revelationPlace: switch (row.columnAt(3) as String?) {
          'makki' => RevelationPlace.makki,
          'madani' => RevelationPlace.madani,
          null => null,
          _ => throw UnsupportedPackFormat(_path, _formatVersion),
        },
        revelationOrder: row.columnAt(4) as int?,
      ),
  ];

  /// The basmala stored for [surah], or null when it has none.
  PackText? basmala(int surah) => switch (_select(
    'SELECT CAST(basmala AS BLOB) FROM surah WHERE number = ?',
    [surah],
  )) {
    [final row] when row.columnAt(0) != null => _text(
      row.columnAt(0) as Uint8List,
      surah,
    ),
    _ => null,
  };

  /// The text of ayah [ayah] of [surah], or null when there is none.
  PackText? ayahText(int surah, int ayah) => switch (_select(
    'SELECT CAST(text AS BLOB) FROM ayah WHERE surah = ? AND number = ?',
    [surah, ayah],
  )) {
    [final row] => _text(row.columnAt(0) as Uint8List, surah, ayah),
    _ => null,
  };

  /// The word spans of an ayah, in order; empty when there is no such ayah.
  List<WordSpan> words(int surah, int ayah) => [
    for (final row in _select(
      'SELECT number, start_offset, end_offset FROM word '
      'WHERE surah = ? AND ayah = ? ORDER BY number',
      [surah, ayah],
    ))
      WordSpan(
        number: row.columnAt(0) as int,
        start: row.columnAt(1) as int,
        end: row.columnAt(2) as int,
      ),
  ];

  /// Every division unit, by kind and number.
  List<DivisionRow> divisions() => [
    for (final row in _select(
      'SELECT kind, number, surah, ayah FROM division ORDER BY kind, number',
    ))
      (
        kind: switch (row.columnAt(0) as String) {
          'juz' => Division.juz,
          'hizb' => Division.hizb,
          'rub' => Division.rub,
          'page' => Division.page,
          _ => throw UnsupportedPackFormat(_path, _formatVersion),
        },
        number: row.columnAt(1) as int,
        surah: row.columnAt(2) as int,
        ayah: row.columnAt(3) as int,
      ),
  ];

  /// Every ayah carrying a sajda, in order.
  List<(int surah, int ayah)> sajdas() => [
    for (final row in _select(
      'SELECT surah, ayah FROM sajda ORDER BY surah, ayah',
    ))
      (row.columnAt(0) as int, row.columnAt(1) as int),
  ];

  PackRowCounts rowCounts() => (
    surahs: _integer('SELECT count(*) FROM surah'),
    ayat: _integer('SELECT count(*) FROM ayah'),
    words: _integer('SELECT count(*) FROM word'),
    divisions: {
      for (final division in Division.values)
        division: _integer('SELECT count(*) FROM division WHERE kind = ?', [
          division.name,
        ]),
    },
    sajdas: _integer('SELECT count(*) FROM sajda'),
  );

  /// The digest of docs/CONTENT_PACKS.md, "Surah digest", over the stored
  /// bytes and numbers of [surah]; null when there is no such surah.
  String? surahSha256(int surah) {
    final basmala = _select(
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

    if (basmala.single.columnAt(0) case final Uint8List bytes) add(0, bytes);
    for (final row in _select(
      'SELECT number, CAST(text AS BLOB) FROM ayah WHERE surah = ? '
      'ORDER BY number',
      [surah],
    )) {
      add(row.columnAt(0) as int, row.columnAt(1) as Uint8List);
    }
    input.close();
    return digest.toString();
  }

  ResultSet _select(String sql, [List<Object?> parameters = const []]) {
    try {
      return _db.select(sql, parameters);
    } on SqliteException {
      throw UnsupportedPackFormat(_path, _formatVersion);
    }
  }

  int _integer(String sql, [List<Object?> parameters = const []]) =>
      _select(sql, parameters).single.columnAt(0) as int;

  /// Decodes stored bytes with no change. A leading EF BB BF is refused
  /// because Dart's decoder would discard it without notice.
  PackText _text(Uint8List bytes, int surah, [int? ayah]) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      throw TextEncodingRejected(_path, surah, ayah);
    }
    try {
      // Spelled out so that a reader sees that malformed bytes are refused.
      // ignore: avoid_redundant_argument_values
      return PackText.fromPack(utf8.decode(bytes, allowMalformed: false));
    } on FormatException {
      throw TextEncodingRejected(_path, surah, ayah);
    }
  }
}
