import '../../domain/models/pack_failure.dart';
import '../../domain/models/pack_text.dart';
import '../../domain/models/recitation.dart';
import '../../domain/models/recitation_file.dart';
import 'pack_database.dart';

/// The facts of a recitation its pack stores. Its riwaya is the manifest's.
typedef RecitationFacts = ({
  PackText reciter,
  PackText style,
  RecitationUnit unit,
  Uri baseUrl,
});

/// A recitation pack's `recitation.sqlite` (docs/CONTENT_PACKS.md,
/// "Recitation pack"): the index of its audio files, which are fetched
/// separately and each checked against its size and hash. Opened read-only
/// and immutable through [PackSqliteFile]; it runs only queries.
///
/// Failures are thrown as [PackFailure]s naming the file: those of
/// [PackSqliteFile.open], and [PackInconsistent] when the recitation is not
/// one row or a value breaks the format.
final class RecitationPackIndex {
  RecitationPackIndex._(this._file);

  static RecitationPackIndex open(String path, {required int formatVersion}) =>
      RecitationPackIndex._(
        PackSqliteFile.open(
          path,
          formatVersion: formatVersion,
          schema:
              _schemas[formatVersion] ??
              (throw UnsupportedPackFormat(path, formatVersion)),
        ),
      );

  static const _schemas = {
    2: {
      'recitation': (
        false,
        [
          ('reciter', 'TEXT', true, 0),
          ('style', 'TEXT', true, 0),
          ('unit', 'TEXT', true, 0),
          ('base_url', 'TEXT', true, 0),
        ],
      ),
      'file': (
        true,
        [
          ('quality_kbps', 'INTEGER', true, 0),
          ('part', 'TEXT', true, 0),
          ('surah', 'INTEGER', false, 0),
          ('ayah', 'INTEGER', false, 0),
          ('path', 'TEXT', true, 1),
          ('bytes', 'INTEGER', true, 0),
          ('sha256', 'TEXT', true, 0),
          ('duration_ms', 'INTEGER', false, 0),
        ],
      ),
    },
  };

  final PackSqliteFile _file;

  String get _path => _file.path;

  void close() => _file.close();

  /// The recitation's facts. Its base URL is absolute `https` with a host,
  /// ends with `/` and has no user, query or fragment.
  RecitationFacts recitation() {
    final rows = _file.select(
      'SELECT CAST(reciter AS BLOB), CAST(style AS BLOB), unit, base_url '
      'FROM recitation',
    );
    if (rows case [final row]) {
      PackFailure rejected(String column) => PackInconsistent(
        _path,
        'recitation.$column is not strict UTF-8 or begins with U+FEFF',
      );
      return (
        reciter: row.text(0, () => rejected('reciter')),
        style: row.text(1, () => rejected('style')),
        unit: switch (row.string(2)) {
          'ayah' => RecitationUnit.ayah,
          'surah' => RecitationUnit.surah,
          final unit => throw PackInconsistent(
            _path,
            'recitation.unit is $unit',
          ),
        },
        baseUrl: _baseUrl(row.string(3)),
      );
    }
    throw PackInconsistent(_path, 'recitation has ${rows.length} rows, not 1');
  }

  Uri _baseUrl(String stored) {
    final url = Uri.tryParse(stored);
    if (url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        url.hasQuery ||
        url.hasFragment ||
        !url.path.endsWith('/')) {
      throw PackInconsistent(_path, 'recitation.base_url is not a base URL');
    }
    return url;
  }

  /// The qualities its files come in, lowest first.
  List<int> qualities() => [
    for (final row in _file.select(
      'SELECT DISTINCT quality_kbps FROM file ORDER BY quality_kbps',
    ))
      row.integer(0),
  ];

  int fileCount() => _file.integer('SELECT count(*) FROM file');

  /// The files of quality [qualityKbps]: the basmala and isti'adha first,
  /// then by surah and ayah. A part the recitation's unit does not allow is
  /// [PackInconsistent].
  List<RecitationFile> files(int qualityKbps) {
    final allowed = switch (recitation().unit) {
      RecitationUnit.ayah => 'ayah',
      RecitationUnit.surah => 'surah',
    };
    return [
      for (final row in _file.select(
        'SELECT quality_kbps, part, surah, ayah, path, bytes, sha256, '
        'duration_ms FROM file WHERE quality_kbps = ? '
        'ORDER BY surah, ayah, part',
        [qualityKbps],
      ))
        _recitationFile(row, allowed),
    ];
  }

  RecitationFile _recitationFile(PackRow row, String allowedUnit) {
    final path = row.string(4);
    final part = switch (row.string(1)) {
      'basmala' => RecitationFilePart.basmala,
      'istiadha' => RecitationFilePart.istiadha,
      final unit when unit == allowedUnit =>
        unit == 'ayah' ? RecitationFilePart.ayah : RecitationFilePart.surah,
      final part => throw PackInconsistent(
        _path,
        'file $path is a $part file of a recitation by $allowedUnit',
      ),
    };
    try {
      return RecitationFile(
        qualityKbps: row.integer(0),
        part: part,
        surah: row.nullableInteger(2),
        ayah: row.nullableInteger(3),
        path: path,
        bytes: row.integer(5),
        sha256: row.string(6),
        duration: switch (row.nullableInteger(7)) {
          final ms? => Duration(milliseconds: ms),
          null => null,
        },
      );
    } on ArgumentError catch (error) {
      throw PackInconsistent(_path, 'file $path: $error');
    }
  }
}
