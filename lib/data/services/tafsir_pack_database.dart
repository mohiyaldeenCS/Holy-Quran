import '../../domain/models/pack_failure.dart';
import '../../domain/models/quran_address.dart';
import '../../domain/models/quran_range.dart';
import '../../domain/models/tafsir_book.dart';
import '../../domain/models/tafsir_passage.dart';
import 'pack_database.dart';

/// A tafsir pack's `tafsir.sqlite` (docs/CONTENT_PACKS.md, "Tafsir pack"),
/// opened read-only and immutable through [PackSqliteFile]. It runs only
/// queries; every text reaches the app as its stored bytes.
///
/// Failures are thrown as [PackFailure]s naming the file: those of
/// [PackSqliteFile.open], [TextEncodingRejected] when a passage is not strict
/// UTF-8 or begins with U+FEFF, and [PackInconsistent] when the book is not
/// one row or a passage breaks the format.
final class TafsirPackDatabase {
  TafsirPackDatabase._(this._file, this._riwaya);

  /// Opens the pack file at [path], whose passages are ayat of [riwaya].
  static TafsirPackDatabase open(
    String path, {
    required int formatVersion,
    required String riwaya,
  }) => TafsirPackDatabase._(
    PackSqliteFile.open(
      path,
      formatVersion: formatVersion,
      schema:
          _schemas[formatVersion] ??
          (throw UnsupportedPackFormat(path, formatVersion)),
    ),
    riwaya,
  );

  static const _schemas = {
    2: {
      'book': (
        false,
        [
          ('title', 'TEXT', true, 0),
          ('author', 'TEXT', true, 0),
          ('publisher', 'TEXT', false, 0),
          ('edition', 'TEXT', false, 0),
          ('editor', 'TEXT', false, 0),
        ],
      ),
      'passage': (
        false,
        [
          ('number', 'INTEGER', false, 1),
          ('surah', 'INTEGER', true, 0),
          ('first_ayah', 'INTEGER', true, 0),
          ('last_ayah', 'INTEGER', true, 0),
          ('text', 'TEXT', true, 0),
        ],
      ),
    },
  };

  static const _passageColumns =
      'number, surah, first_ayah, last_ayah, CAST(text AS BLOB)';

  final PackSqliteFile _file;
  final String _riwaya;

  String get _path => _file.path;

  void close() => _file.close();

  TafsirBook book() {
    final rows = _file.select(
      'SELECT CAST(title AS BLOB), CAST(author AS BLOB), '
      'CAST(publisher AS BLOB), CAST(edition AS BLOB), CAST(editor AS BLOB) '
      'FROM book',
    );
    if (rows case [final row]) {
      PackFailure rejected(String column) => PackInconsistent(
        _path,
        'book.$column is not strict UTF-8 or begins with U+FEFF',
      );
      return TafsirBook(
        title: row.text(0, () => rejected('title')),
        author: row.text(1, () => rejected('author')),
        publisher: row.nullableText(2, () => rejected('publisher')),
        edition: row.nullableText(3, () => rejected('edition')),
        editor: row.nullableText(4, () => rejected('editor')),
      );
    }
    throw PackInconsistent(_path, 'book has ${rows.length} rows, not 1');
  }

  int passageCount() => _file.integer('SELECT count(*) FROM passage');

  /// The passage that explains ayah [ayah] of [surah], or null when the book
  /// has none for it.
  TafsirPassage? passageAt(int surah, int ayah) {
    final passages = [
      for (final row in _file.select(
        'SELECT $_passageColumns FROM passage '
        'WHERE surah = ? AND first_ayah <= ? AND last_ayah >= ? '
        'ORDER BY number',
        [surah, ayah, ayah],
      ))
        _passage(row),
    ];
    return switch (passages) {
      [] => null,
      [final passage] => passage,
      [final first, final second, ...] => throw PackInconsistent(
        _path,
        'passages ${first.number} and ${second.number} overlap',
      ),
    };
  }

  /// The passages of [surah] in order; empty when it has none. Passages that
  /// overlap, or whose numbers do not follow their order, are
  /// [PackInconsistent].
  List<TafsirPassage> passagesOfSurah(int surah) {
    final passages = [
      for (final row in _file.select(
        'SELECT $_passageColumns FROM passage WHERE surah = ? '
        'ORDER BY first_ayah',
        [surah],
      ))
        _passage(row),
    ];
    for (final (index, passage) in passages.indexed.skip(1)) {
      final before = passages[index - 1];
      if (passage.range.start.ayah <= before.range.end.ayah ||
          passage.number <= before.number) {
        throw PackInconsistent(
          _path,
          'passage ${passage.number} does not follow ${before.number}',
        );
      }
    }
    return passages;
  }

  TafsirPassage _passage(PackRow row) {
    final number = row.integer(0);
    final surah = row.integer(1);
    final firstAyah = row.integer(2);
    final text = row.text(
      4,
      () => TextEncodingRejected(_path, surah, firstAyah),
    );
    try {
      return TafsirPassage(
        number: number,
        range: QuranRange(
          QuranAddress(_riwaya, surah, firstAyah),
          QuranAddress(_riwaya, surah, row.integer(3)),
        ),
        text: text,
      );
    } on ArgumentError catch (error) {
      throw PackInconsistent(_path, 'passage $number: $error');
    }
  }
}
