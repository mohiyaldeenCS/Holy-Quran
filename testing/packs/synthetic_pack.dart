import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

import 'raw_pack.dart';

/// The pinned font the text pack names (pubspec.yaml, D-026).
const amiriQuranFontPath = 'assets/fonts/AmiriQuran-Regular.ttf';

const textFileName = 'text.sqlite';
const manifestFileName = 'manifest.json';

/// One synthetic ayah. Its text is never Quran text.
final class SyntheticAyah {
  const SyntheticAyah(this.text, {this.words});

  final String text;

  /// UTF-16 half-open spans, when given.
  final List<(int, int)>? words;

  /// [words], or else the tokens between single ASCII spaces: synthetic test
  /// data only, never how the app finds words.
  List<(int, int)> get spans => words ?? _spacedWords(text);

  static List<(int, int)> _spacedWords(String text) {
    final spans = <(int, int)>[];
    var start = 0;
    for (final token in text.split(' ')) {
      if (token.isNotEmpty) spans.add((start, start + token.length));
      start += token.length + 1;
    }
    return spans;
  }
}

final class SyntheticSurah {
  const SyntheticSurah({
    required this.name,
    required this.ayat,
    this.basmala,
    this.revelationPlace,
    this.revelationOrder,
  });

  final String name;
  final String? basmala;
  final List<SyntheticAyah> ayat;

  /// `makki`, `madani` or null.
  final String? revelationPlace;
  final int? revelationOrder;
}

/// The first ayah of a unit of [kind] (`juz`, `hizb`, `rub` or `page`).
final class SyntheticDivision {
  const SyntheticDivision(this.kind, this.number, this.surah, this.ayah);

  final String kind;
  final int number;
  final int surah;
  final int ayah;
}

/// One defect, applied to an otherwise valid pack.
enum SyntheticFault {
  /// One byte of the text of the first ayah is changed after hashing.
  flippedByte,

  /// `surah_sha256["1"]` is a well-formed hash of something else.
  wrongSurahHash,

  /// `counts.ayat` is one more than stored.
  wrongCounts,

  /// The first ayah is stored with a leading U+FEFF (bytes EF BB BF); every
  /// hash in the manifest is consistent with it.
  leadingBom,

  /// The file is left in WAL mode: header bytes 18 and 19 are 2.
  walHeader,

  /// `application_id` is not `HQPK`.
  wrongApplicationId,

  /// `user_version` differs from `format_version`.
  wrongUserVersion,

  /// `format_version` is one the app does not know.
  unsupportedFormatVersion,

  /// `files[0].name` is `../text.sqlite`.
  pathInFileName,

  /// `text.sqlite` is deleted after the manifest is written.
  missingFile,

  /// `files[0].bytes` is one more than the file's size; its hash is right.
  wrongFileSize,
}

/// A built pack and what it truly holds. [manifest] is what the pack claims;
/// the other fields describe what was stored, so a fault shows up as a
/// difference between the two.
final class SyntheticPack {
  SyntheticPack({
    required this.directory,
    required this.manifest,
    required this.surahs,
    required this.divisions,
    required this.sajdas,
    required this.surahSha256,
    required this.counts,
    required this.fault,
  });

  final Directory directory;
  final Map<String, Object?> manifest;
  final List<SyntheticSurah> surahs;
  final List<SyntheticDivision> divisions;
  final List<(int, int)> sajdas;

  /// Digests of the stored values, keyed `"1"` to `"<surahs>"`.
  final Map<String, String> surahSha256;

  /// The counts of the stored rows, in the manifest's shape.
  final Map<String, Object?> counts;
  final SyntheticFault? fault;

  File get textFile => File('${directory.path}/$textFileName');
  File get manifestFile => File('${directory.path}/$manifestFileName');
}

/// Three short surahs of plainly synthetic text that would change under any
/// normalising, trimming or offset error: a precomposed and a decomposed
/// e-acute, leading, trailing and double spaces, a character outside the BMP,
/// an Arabic-script synthetic phrase, a word list with a non-space separator,
/// and surahs with and without a basmala.
const List<SyntheticSurah> defaultSyntheticSurahs = [
  SyntheticSurah(
    name: 'Synthetic surah one',
    basmala: 'Synthetic opening line',
    revelationPlace: 'makki',
    revelationOrder: 2,
    ayat: [
      SyntheticAyah('Synthetic ayah one'),
      SyntheticAyah('Synthetic \u{E9} two'),
      SyntheticAyah('Synthetic e\u{301} three'),
      SyntheticAyah(
        ' \u{646}\u{635} \u{62A}\u{62C}\u{631}\u{64A}\u{628}\u{64A}  ',
      ),
    ],
  ),
  SyntheticSurah(
    name: 'Synthetic surah two',
    revelationPlace: 'madani',
    revelationOrder: 1,
    ayat: [
      SyntheticAyah('Synthetic  double  spaces'),
      SyntheticAyah('ab \u{1F600} cd'),
      SyntheticAyah(
        'Synthetic-pair joined',
        words: [(0, 9), (10, 14), (15, 21)],
      ),
    ],
  ),
  SyntheticSurah(
    name: 'Synthetic surah three',
    basmala: 'Synthetic opening line',
    ayat: [SyntheticAyah('Synthetic last ayah')],
  ),
];

const List<SyntheticDivision> defaultSyntheticDivisions = [
  SyntheticDivision('juz', 1, 1, 1),
  SyntheticDivision('juz', 2, 2, 1),
  SyntheticDivision('hizb', 1, 1, 1),
  SyntheticDivision('hizb', 2, 1, 3),
  SyntheticDivision('hizb', 3, 2, 1),
  SyntheticDivision('hizb', 4, 3, 1),
  SyntheticDivision('rub', 1, 1, 1),
  SyntheticDivision('rub', 2, 1, 2),
  SyntheticDivision('rub', 3, 1, 3),
  SyntheticDivision('rub', 4, 1, 4),
  SyntheticDivision('rub', 5, 2, 1),
  SyntheticDivision('rub', 6, 2, 2),
  SyntheticDivision('rub', 7, 2, 3),
  SyntheticDivision('rub', 8, 3, 1),
  SyntheticDivision('page', 1, 1, 1),
  SyntheticDivision('page', 2, 1, 4),
  SyntheticDivision('page', 3, 2, 2),
  SyntheticDivision('page', 4, 3, 1),
];

const List<(int, int)> defaultSyntheticSajdas = [(1, 2), (2, 3)];

const _divisionKinds = ['juz', 'hizb', 'rub', 'page'];

// The DDL of docs/CONTENT_PACKS.md, "Text pack".
const _schema = [
  '''
CREATE TABLE surah (
  number           INTEGER PRIMARY KEY,
  name             TEXT NOT NULL,
  ayah_count       INTEGER NOT NULL,
  revelation_place TEXT CHECK (revelation_place IN ('makki','madani')),
  revelation_order INTEGER,
  basmala          TEXT
) STRICT''',
  '''
CREATE TABLE ayah (
  surah  INTEGER NOT NULL REFERENCES surah(number),
  number INTEGER NOT NULL,
  text   TEXT NOT NULL,
  PRIMARY KEY (surah, number)
) STRICT, WITHOUT ROWID''',
  '''
CREATE TABLE word (
  surah        INTEGER NOT NULL,
  ayah         INTEGER NOT NULL,
  number       INTEGER NOT NULL,
  start_offset INTEGER NOT NULL,
  end_offset   INTEGER NOT NULL,
  PRIMARY KEY (surah, ayah, number),
  FOREIGN KEY (surah, ayah) REFERENCES ayah(surah, number)
) STRICT, WITHOUT ROWID''',
  '''
CREATE TABLE division (
  kind   TEXT NOT NULL CHECK (kind IN ('juz','hizb','rub','page')),
  number INTEGER NOT NULL,
  surah  INTEGER NOT NULL,
  ayah   INTEGER NOT NULL,
  PRIMARY KEY (kind, number),
  FOREIGN KEY (surah, ayah) REFERENCES ayah(surah, number)
) STRICT, WITHOUT ROWID''',
  '''
CREATE TABLE sajda (
  surah INTEGER NOT NULL,
  ayah  INTEGER NOT NULL,
  PRIMARY KEY (surah, ayah),
  FOREIGN KEY (surah, ayah) REFERENCES ayah(surah, number)
) STRICT, WITHOUT ROWID''',
];

/// Builds `<root>/<id>/<version>/` with `text.sqlite` and `manifest.json`
/// as docs/CONTENT_PACKS.md defines them, then applies [fault], if any.
Future<SyntheticPack> buildSyntheticPack(
  Directory root, {
  List<SyntheticSurah> surahs = defaultSyntheticSurahs,
  List<SyntheticDivision> divisions = defaultSyntheticDivisions,
  List<(int, int)> sajdas = defaultSyntheticSajdas,
  SyntheticFault? fault,
  String id = 'synthetic-text',
  int version = 1,
}) async {
  final stored = fault == SyntheticFault.leadingBom
      ? _withLeadingBom(surahs)
      : surahs;
  final directory = await Directory(
    '${root.path}/$id/$version',
  ).create(recursive: true);
  final textFile = File('${directory.path}/$textFileName');

  _writeDatabase(textFile, stored, divisions, sajdas, fault);

  final textBytes = await textFile.readAsBytes();
  final surahSha256 = {
    for (var i = 0; i < stored.length; i++)
      '${i + 1}': surahDigest(
        [for (final ayah in stored[i].ayat) utf8.encode(ayah.text)],
        basmala: switch (stored[i].basmala) {
          final basmala? => utf8.encode(basmala),
          null => null,
        },
      ),
  };
  final counts = <String, Object?>{
    'surahs': stored.length,
    'ayat': stored.fold<int>(0, (n, s) => n + s.ayat.length),
    'words': stored.fold<int>(
      0,
      (n, s) => s.ayat.fold<int>(n, (m, a) => m + a.spans.length),
    ),
    'divisions': {
      for (final kind in _divisionKinds)
        kind: divisions.where((d) => d.kind == kind).length,
    },
    'sajdas': sajdas.length,
  };

  // A JSON round trip, so the manifest shares no map with the stored truth
  // and equals what is written.
  final manifest = _jsonCopy(
    _manifest(
      id: id,
      version: version,
      fontSha256: sha256
          .convert(await File(amiriQuranFontPath).readAsBytes())
          .toString(),
      textSha256: sha256.convert(textBytes).toString(),
      textBytes: textBytes.length,
      surahSha256: surahSha256,
      counts: counts,
    ),
  );
  _applyManifestFault(manifest, fault);

  final manifestFile = File('${directory.path}/$manifestFileName');
  await manifestFile.writeAsBytes(
    utf8.encode('${const JsonEncoder.withIndent('  ').convert(manifest)}\n'),
  );

  switch (fault) {
    case SyntheticFault.flippedByte:
      await _flipFirstByteOf(textFile, utf8.encode(stored[0].ayat[0].text));
    case SyntheticFault.missingFile:
      await textFile.delete();
    default:
  }

  return SyntheticPack(
    directory: directory,
    manifest: manifest,
    surahs: stored,
    divisions: divisions,
    sajdas: sajdas,
    surahSha256: surahSha256,
    counts: counts,
    fault: fault,
  );
}

List<SyntheticSurah> _withLeadingBom(List<SyntheticSurah> surahs) {
  final first = surahs[0];
  final ayah = first.ayat[0];
  final bommed = SyntheticAyah(
    '\u{FEFF}${ayah.text}',
    words: [for (final (start, end) in ayah.spans) (start + 1, end + 1)],
  );
  return [
    SyntheticSurah(
      name: first.name,
      basmala: first.basmala,
      revelationPlace: first.revelationPlace,
      revelationOrder: first.revelationOrder,
      ayat: [bommed, ...first.ayat.skip(1)],
    ),
    ...surahs.skip(1),
  ];
}

void _writeDatabase(
  File file,
  List<SyntheticSurah> surahs,
  List<SyntheticDivision> divisions,
  List<(int, int)> sajdas,
  SyntheticFault? fault,
) {
  final db = sqlite3.open(file.path);
  try {
    final applicationId = fault == SyntheticFault.wrongApplicationId
        ? hqpkApplicationId + 1
        : hqpkApplicationId;
    final userVersion = fault == SyntheticFault.wrongUserVersion
        ? packFormatVersion + 1
        : packFormatVersion;
    db
      ..execute("PRAGMA encoding = 'UTF-8'")
      ..execute('PRAGMA application_id = $applicationId')
      ..execute('PRAGMA user_version = $userVersion')
      ..execute('PRAGMA journal_mode = DELETE')
      ..execute('PRAGMA foreign_keys = ON');
    for (final table in _schema) {
      db.execute(table);
    }

    // Text is bound as the UTF-8 bytes written here and cast to TEXT, so the
    // stored bytes do not depend on the driver's string encoding.
    db.execute('BEGIN');
    for (var s = 0; s < surahs.length; s++) {
      final surah = surahs[s];
      db.execute(
        'INSERT INTO surah VALUES (?, CAST(? AS TEXT), ?, ?, ?, CAST(? AS TEXT))',
        [
          s + 1,
          _bytes(surah.name),
          surah.ayat.length,
          surah.revelationPlace,
          surah.revelationOrder,
          switch (surah.basmala) {
            final basmala? => _bytes(basmala),
            null => null,
          },
        ],
      );
      for (var a = 0; a < surah.ayat.length; a++) {
        final ayah = surah.ayat[a];
        db.execute('INSERT INTO ayah VALUES (?, ?, CAST(? AS TEXT))', [
          s + 1,
          a + 1,
          _bytes(ayah.text),
        ]);
        final words = ayah.spans;
        for (var w = 0; w < words.length; w++) {
          db.execute('INSERT INTO word VALUES (?, ?, ?, ?, ?)', [
            s + 1,
            a + 1,
            w + 1,
            words[w].$1,
            words[w].$2,
          ]);
        }
      }
    }
    for (final d in divisions) {
      db.execute('INSERT INTO division VALUES (?, ?, ?, ?)', [
        d.kind,
        d.number,
        d.surah,
        d.ayah,
      ]);
    }
    for (final (surah, ayah) in sajdas) {
      db.execute('INSERT INTO sajda VALUES (?, ?)', [surah, ayah]);
    }
    db
      ..execute('COMMIT')
      ..execute('VACUUM');
    if (fault == SyntheticFault.walHeader) {
      db.execute('PRAGMA journal_mode = WAL');
    }
  } finally {
    db.close();
  }
}

Uint8List _bytes(String text) => utf8.encode(text);

Map<String, Object?> _jsonCopy(Map<String, Object?> map) =>
    jsonDecode(jsonEncode(map)) as Map<String, Object?>;

Map<String, Object?> _manifest({
  required String id,
  required int version,
  required String fontSha256,
  required String textSha256,
  required int textBytes,
  required Map<String, String> surahSha256,
  required Map<String, Object?> counts,
}) => {
  'format': 'holyquran-pack',
  'format_version': packFormatVersion,
  'id': id,
  'kind': 'text',
  'version': version,
  'changelog': [
    {'version': version, 'date': '2026-01-01', 'summary': 'Synthetic pack'},
  ],
  'riwaya': 'hafs',
  'edition': 'synthetic-edition',
  'font': {'family': 'Amiri Quran', 'version': '1.003', 'sha256': fontSha256},
  'sources': [_source('text', 1), _source('edition_map', 4)],
  'files': [
    {'name': textFileName, 'sha256': textSha256, 'bytes': textBytes},
  ],
  'surah_sha256': surahSha256,
  'counts': counts,
  'reviews': [
    {
      'reviewer': 'synthetic reviewer',
      'date': '2026-01-01',
      'scope': 'synthetic test data',
    },
  ],
};

Map<String, Object?> _source(String role, int registryRow) => {
  'role': role,
  'registry_row': registryRow,
  'name': 'Synthetic $role source',
  'publisher': 'Synthetic publisher',
  'url': 'https://example.invalid/synthetic/$role',
  'version': '1',
  'fetched_on': '2026-01-01',
  'file_sha256': sha256.convert(utf8.encode('synthetic $role')).toString(),
  'trust_grade': 'A',
  'licence': {
    'text': null,
    'permission_ref': null,
    'notice': null,
    'allows_export': true,
  },
};

void _applyManifestFault(Map<String, Object?> manifest, SyntheticFault? fault) {
  final file =
      (manifest['files']! as List<Object?>)[0]! as Map<String, Object?>;
  switch (fault) {
    case SyntheticFault.wrongSurahHash:
      (manifest['surah_sha256']! as Map<String, Object?>)['1'] = sha256
          .convert(utf8.encode('synthetic wrong digest'))
          .toString();
    case SyntheticFault.wrongCounts:
      final counts = manifest['counts']! as Map<String, Object?>;
      counts['ayat'] = (counts['ayat']! as int) + 1;
    case SyntheticFault.unsupportedFormatVersion:
      manifest['format_version'] = packFormatVersion + 1;
    case SyntheticFault.pathInFileName:
      file['name'] = '../$textFileName';
    case SyntheticFault.wrongFileSize:
      file['bytes'] = (file['bytes']! as int) + 1;
    default:
  }
}

Future<void> _flipFirstByteOf(File file, List<int> needle) async {
  final bytes = await file.readAsBytes();
  final at = _indexOf(bytes, needle);
  if (at < 0) {
    throw StateError('The first ayah was not found in $textFileName.');
  }
  bytes[at] ^= 0x01;
  await file.writeAsBytes(bytes, flush: true);
}

int _indexOf(List<int> haystack, List<int> needle) {
  outer:
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}
