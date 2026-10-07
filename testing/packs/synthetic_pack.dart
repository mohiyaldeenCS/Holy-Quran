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

/// A mark of a synthetic ayah: the number of the word it follows (0 before
/// the first word) and its UTF-16 half-open span.
typedef SyntheticMark = ({int afterWord, int start, int end});

/// One synthetic ayah. Its text is never Quran text.
final class SyntheticAyah {
  const SyntheticAyah(this.text, {this.words, this.marks});

  final String text;

  /// UTF-16 half-open spans, when given.
  final List<(int, int)>? words;

  /// The marks, when given.
  final List<SyntheticMark>? marks;

  /// [words], or else the tokens between single ASCII spaces that hold a
  /// letter.
  List<(int, int)> get spans =>
      words ??
      [
        for (final (start, end, isWord) in _tokens(text))
          if (isWord) (start, end),
      ];

  /// [marks], or else, when [words] is not given either, the tokens between
  /// single ASCII spaces that hold no letter, each after the word before it.
  List<SyntheticMark> get markSpans {
    if (marks case final given?) return given;
    if (words != null) return const [];
    final found = <SyntheticMark>[];
    var word = 0;
    for (final (start, end, isWord) in _tokens(text)) {
      if (isWord) {
        word++;
      } else {
        found.add((afterWord: word, start: start, end: end));
      }
    }
    return found;
  }

  /// Synthetic test data only, never how the app or the pipeline finds
  /// words: a token holding a letter of [_isLetter] is a word, any other a
  /// mark (D-078). Which tokens of a real pack are marks is the pipeline's
  /// rule, from its own table of code points.
  static List<(int, int, bool)> _tokens(String text) {
    final tokens = <(int, int, bool)>[];
    var start = 0;
    for (final token in text.split(' ')) {
      if (token.isNotEmpty) {
        tokens.add((start, start + token.length, token.runes.any(_isLetter)));
      }
      start += token.length + 1;
    }
    return tokens;
  }

  /// The letters of the synthetic texts: ASCII and Latin-1 letters, and the
  /// Arabic letters from hamza to yeh without the tatweel.
  static bool _isLetter(int rune) =>
      (rune >= 0x41 && rune <= 0x5A) ||
      (rune >= 0x61 && rune <= 0x7A) ||
      (rune >= 0xC0 && rune <= 0xFF && rune != 0xD7 && rune != 0xF7) ||
      (rune >= 0x621 && rune <= 0x64A && rune != 0x640);
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

  /// The second word of the first ayah starts inside the first; the counts
  /// and every hash are consistent with it.
  overlappingSpans,

  /// The `sajda` table is created without `STRICT`.
  nonStrictSchema,

  /// The first mark that follows a word starts one code unit before that
  /// word ends; the counts and every hash are consistent with it.
  markOverlapsWord,

  /// The first mark that follows a word names the word after it in
  /// `after_word`; the counts and every hash are consistent with it.
  wrongAfterWord,

  /// `counts.marks` is one more than stored.
  wrongMarkCount,
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
/// an Arabic-script synthetic phrase, a word holding a hyphen, and surahs
/// with and without a basmala. Single code points stand alone as marks:
/// between words, after the last word, before the first word, and one
/// outside the BMP. Only U+0020 lies outside the words and marks
/// (docs/CONTENT_PACKS.md, "Word and mark offsets").
const List<SyntheticSurah> defaultSyntheticSurahs = [
  SyntheticSurah(
    name: 'Synthetic surah one',
    basmala: 'Synthetic opening line',
    revelationPlace: 'makki',
    revelationOrder: 2,
    ayat: [
      SyntheticAyah('Synthetic ayah one'),
      SyntheticAyah('Synthetic \u{E9} \u{6D6} two \u{6D7} \u{6E9}'),
      SyntheticAyah('\u{6DA} Synthetic e\u{301} three'),
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
      SyntheticAyah('Synthetic-pair joined'),
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
CREATE TABLE mark (
  surah        INTEGER NOT NULL,
  ayah         INTEGER NOT NULL,
  number       INTEGER NOT NULL,
  after_word   INTEGER NOT NULL,
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
  final stored = switch (fault) {
    SyntheticFault.leadingBom => _withLeadingBom(surahs),
    SyntheticFault.overlappingSpans => _withOverlappingSpans(surahs),
    SyntheticFault.markOverlapsWord => _withFirstMarkAfterWord(
      surahs,
      (mark, words) => (
        afterWord: mark.afterWord,
        start: words[mark.afterWord - 1].$2 - 1,
        end: mark.end,
      ),
    ),
    SyntheticFault.wrongAfterWord => _withFirstMarkAfterWord(
      surahs,
      (mark, _) =>
          (afterWord: mark.afterWord + 1, start: mark.start, end: mark.end),
    ),
    _ => surahs,
  };
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
    'marks': stored.fold<int>(
      0,
      (n, s) => s.ayat.fold<int>(n, (m, a) => m + a.markSpans.length),
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
  final ayah = surahs[0].ayat[0];
  return _withFirstAyah(
    surahs,
    SyntheticAyah(
      '\u{FEFF}${ayah.text}',
      words: [for (final (start, end) in ayah.spans) (start + 1, end + 1)],
      marks: [
        for (final mark in ayah.markSpans)
          (afterWord: mark.afterWord, start: mark.start + 1, end: mark.end + 1),
      ],
    ),
  );
}

List<SyntheticSurah> _withOverlappingSpans(List<SyntheticSurah> surahs) {
  final ayah = surahs[0].ayat[0];
  final [(firstStart, firstEnd), (_, secondEnd), ...rest] = ayah.spans;
  return _withFirstAyah(
    surahs,
    SyntheticAyah(
      ayah.text,
      words: [(firstStart, firstEnd), (firstEnd - 1, secondEnd), ...rest],
      marks: ayah.markSpans,
    ),
  );
}

/// [surahs] with the first mark that follows a word, in surah and ayah
/// order, replaced by what [change] makes of it and the ayah's word spans.
List<SyntheticSurah> _withFirstMarkAfterWord(
  List<SyntheticSurah> surahs,
  SyntheticMark Function(SyntheticMark mark, List<(int, int)> words) change,
) {
  for (final (s, surah) in surahs.indexed) {
    for (final (a, ayah) in surah.ayat.indexed) {
      final marks = [...ayah.markSpans];
      final at = marks.indexWhere((mark) => mark.afterWord > 0);
      if (at < 0) continue;
      marks[at] = change(marks[at], ayah.spans);
      return _withAyah(
        surahs,
        s,
        a,
        SyntheticAyah(ayah.text, words: ayah.spans, marks: marks),
      );
    }
  }
  throw StateError('No synthetic mark follows a word.');
}

List<SyntheticSurah> _withFirstAyah(
  List<SyntheticSurah> surahs,
  SyntheticAyah ayah,
) => _withAyah(surahs, 0, 0, ayah);

/// [surahs] with ayah [a] of surah [s], both counted from 0, replaced.
List<SyntheticSurah> _withAyah(
  List<SyntheticSurah> surahs,
  int s,
  int a,
  SyntheticAyah ayah,
) => [
  for (final (index, surah) in surahs.indexed)
    if (index != s)
      surah
    else
      SyntheticSurah(
        name: surah.name,
        basmala: surah.basmala,
        revelationPlace: surah.revelationPlace,
        revelationOrder: surah.revelationOrder,
        ayat: [...surah.ayat]..[a] = ayah,
      ),
];

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
      db.execute(
        fault == SyntheticFault.nonStrictSchema && table == _schema.last
            ? table.replaceFirst('STRICT, ', '')
            : table,
      );
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
        final marks = ayah.markSpans;
        for (var m = 0; m < marks.length; m++) {
          db.execute('INSERT INTO mark VALUES (?, ?, ?, ?, ?, ?)', [
            s + 1,
            a + 1,
            m + 1,
            marks[m].afterWord,
            marks[m].start,
            marks[m].end,
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
  'sources': [
    _source('text', 1, {
      'synthetic_type': 'synthetic',
      'synthetic_marks': true,
      'synthetic_level': 1,
    }),
    _source('edition_map', 4, null),
  ],
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

Map<String, Object?> _source(
  String role,
  int registryRow,
  Map<String, Object>? options,
) => {
  'role': role,
  'registry_row': registryRow,
  'name': 'Synthetic $role source',
  'publisher': 'Synthetic publisher',
  'url': 'https://example.invalid/synthetic/$role',
  'version': '1',
  'fetched_on': '2026-01-01',
  'file_sha256': sha256.convert(utf8.encode('synthetic $role')).toString(),
  'trust_grade': 'A',
  'options': options,
  'licence': {
    'text': null,
    'permission_ref': 'Synthetic permission $registryRow',
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
    case SyntheticFault.wrongMarkCount:
      final counts = manifest['counts']! as Map<String, Object?>;
      counts['marks'] = (counts['marks']! as int) + 1;
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
