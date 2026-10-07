import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:holyquran/data/models/pack_manifest_json.dart';
import 'package:holyquran/utils/result.dart';
import 'package:sqlite3/sqlite3.dart';

import 'tanzil_xml.dart';

const spikePackId = 'spike-tanzil-uthmani';
const spikePackVersion = 1;

/// A value as read from the source file, and where its UTF-8 bytes start.
typedef SpikeText = ({String value, int byteOffset});

typedef SpikeSurah = ({
  SpikeText name,
  SpikeText? basmala,
  List<SpikeText> ayat,
});

/// The source file and what the manifest records of it. [version] is the
/// registry's (docs/SOURCES.md row 1); [notice] is the file's copyright
/// block, kept verbatim.
typedef SpikeSource = ({
  Uint8List bytes,
  String url,
  String version,
  String fetchedOn,
  String notice,
});

/// The source version of docs/SOURCES.md, row 1.
const tanzilUthmaniVersion = '1.1';

/// Synthetic divisions, not the edition's: a unit of each kind starts every
/// so many ayat counted across the whole text.
const spikeDivisionEvery = {'juz': 200, 'hizb': 100, 'rub': 25, 'page': 10};

const _textFile = 'text.sqlite';
const _manifestFile = 'manifest.json';
const _applicationId = 1213288523;
const _formatVersion = 1;

List<SpikeSurah> spikeSurahsOf(TanzilXml xml) => [
  for (final sura in xml.suras)
    _surah(sura, [
      for (final ayah in xml.ayat)
        if (ayah.surah == sura.index) ayah,
    ]),
];

SpikeSurah _surah(TanzilSura sura, List<TanzilAyah> ayat) => (
  name: (value: sura.name, byteOffset: sura.nameByteOffset),
  basmala: switch ((ayat.first.basmala, ayat.first.basmalaByteOffset)) {
    (final String value, final int offset) => (
      value: value,
      byteOffset: offset,
    ),
    _ => null,
  },
  ayat: [
    for (final ayah in ayat) (value: ayah.text, byteOffset: ayah.byteOffset),
  ],
);

/// Writes `<root>/spike-tanzil-uthmani/1/` (manifest.json and text.sqlite)
/// to docs/CONTENT_PACKS.md, format v1, and returns its path.
///
/// Spike only (D-068, D-072): words are the maximal runs between U+0020, and
/// the divisions are [spikeDivisionEvery]; the changelog says so. Every value
/// must equal the source bytes at its offset before it is written and is
/// read back as stored bytes after; any difference, an existing directory or
/// a manifest the app's parser refuses throws a [StateError] naming an
/// address, and leaves no pack behind.
Future<String> writeSpikePack(
  Directory root, {
  required List<SpikeSurah> surahs,
  required String fontSha256,
  required SpikeSource source,
}) async {
  final directory = Directory('${root.path}/$spikePackId/$spikePackVersion');
  if (directory.existsSync()) {
    throw StateError('${directory.path} exists; a version is never rewritten');
  }
  if (surahs.isEmpty) throw StateError('no surah to write');
  _forEachText(surahs, (where, text) {
    final value = text.value;
    if (value.isEmpty || value.codeUnitAt(0) == 0xFEFF) {
      throw StateError('$where is empty or begins with U+FEFF');
    }
    if (!_equalsAt(utf8.encode(value), source.bytes, text.byteOffset)) {
      throw StateError(
        '$where differs from the source bytes at byte ${text.byteOffset}',
      );
    }
  });
  await directory.create(recursive: true);
  try {
    final text = File('${directory.path}/$_textFile');
    final counts = _writeDatabase(text.path, surahs);
    final surahSha256 = _readBack(text.path, surahs, source.bytes);
    final textBytes = await text.readAsBytes();
    final json = _manifest(
      source: source,
      fontSha256: fontSha256,
      textSha256: sha256.convert(textBytes).toString(),
      textBytes: textBytes.length,
      surahSha256: surahSha256,
      counts: counts,
    );
    final manifest = utf8.encode(
      '${const JsonEncoder.withIndent('  ').convert(json)}\n',
    );
    switch (parsePackManifest(manifest, pack: directory.path)) {
      case Failure(:final error):
        throw StateError('the app refuses the manifest: $error');
      case Ok(:final value)
          when value.sources.single.licence.notice != source.notice:
        throw StateError('the notice did not survive the manifest');
      case Ok():
    }
    await File(
      '${directory.path}/$_manifestFile',
    ).writeAsBytes(manifest, flush: true);
  } on Object {
    await directory.delete(recursive: true);
    rethrow;
  }
  return directory.path;
}

void _forEachText(
  List<SpikeSurah> surahs,
  void Function(String where, SpikeText text) visit,
) {
  for (final (s, surah) in surahs.indexed) {
    visit('surah ${s + 1} name', surah.name);
    if (surah.basmala case final basmala?) {
      visit('surah ${s + 1} basmala', basmala);
    }
    for (final (a, ayah) in surah.ayat.indexed) {
      visit('ayah ${s + 1}:${a + 1}', ayah);
    }
  }
}

bool _equalsAt(List<int> value, Uint8List source, int offset) {
  if (offset < 0 || offset + value.length > source.length) return false;
  for (var i = 0; i < value.length; i++) {
    if (value[i] != source[offset + i]) return false;
  }
  return true;
}

/// The maximal runs of code units other than U+0020, as UTF-16 half-open
/// spans. Spike only; B0.4 and D-038 decide what a word is.
List<(int, int)> spikeWordSpans(String text) {
  final spans = <(int, int)>[];
  int? start;
  for (var i = 0; i < text.length; i++) {
    if (text.codeUnitAt(i) == 0x20) {
      if (start != null) spans.add((start, i));
      start = null;
    } else {
      start ??= i;
    }
  }
  if (start != null) spans.add((start, text.length));
  return spans;
}

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

/// Writes the tables, binding each value as the Dart string received, and
/// returns the manifest's `counts`.
Map<String, Object?> _writeDatabase(String path, List<SpikeSurah> surahs) {
  final db = sqlite3.open(path);
  try {
    db
      ..execute("PRAGMA encoding = 'UTF-8'")
      ..execute('PRAGMA application_id = $_applicationId')
      ..execute('PRAGMA user_version = $_formatVersion')
      ..execute('PRAGMA journal_mode = DELETE')
      ..execute('PRAGMA foreign_keys = ON');
    for (final table in _schema) {
      db.execute(table);
    }
    db.execute('BEGIN');
    final insertSurah = db.prepare(
      'INSERT INTO surah VALUES (?, ?, ?, NULL, NULL, ?)',
    );
    final insertAyah = db.prepare('INSERT INTO ayah VALUES (?, ?, ?)');
    final insertWord = db.prepare('INSERT INTO word VALUES (?, ?, ?, ?, ?)');
    final insertDivision = db.prepare(
      'INSERT INTO division VALUES (?, ?, ?, ?)',
    );
    var words = 0;
    final starts = <(int, int)>[];
    for (final (s, surah) in surahs.indexed) {
      insertSurah.execute([
        s + 1,
        surah.name.value,
        surah.ayat.length,
        surah.basmala?.value,
      ]);
      for (final (a, ayah) in surah.ayat.indexed) {
        insertAyah.execute([s + 1, a + 1, ayah.value]);
        for (final (w, (start, end)) in spikeWordSpans(ayah.value).indexed) {
          insertWord.execute([s + 1, a + 1, w + 1, start, end]);
          words++;
        }
        starts.add((s + 1, a + 1));
      }
    }
    final divisions = <String, int>{};
    for (final MapEntry(key: kind, value: every)
        in spikeDivisionEvery.entries) {
      var number = 0;
      for (var i = 0; i < starts.length; i += every) {
        final (surah, ayah) = starts[i];
        insertDivision.execute([kind, ++number, surah, ayah]);
      }
      divisions[kind] = number;
    }
    for (final statement in [
      insertSurah,
      insertAyah,
      insertWord,
      insertDivision,
    ]) {
      statement.close();
    }
    db
      ..execute('COMMIT')
      ..execute('VACUUM');
    return {
      'surahs': surahs.length,
      'ayat': starts.length,
      'words': words,
      'divisions': divisions,
      'sajdas': 0,
    };
  } finally {
    db.close();
  }
}

/// Reads every stored text back as bytes, checks it against the source, and
/// returns the surah digests of docs/CONTENT_PACKS.md over the stored bytes.
Map<String, String> _readBack(
  String path,
  List<SpikeSurah> surahs,
  Uint8List source,
) {
  final db = sqlite3.open(
    'file:${Uri.file(path).path}?mode=ro&immutable=1',
    mode: OpenMode.readOnly,
    uri: true,
  );
  try {
    final rows = db.select(
      'SELECT number, CAST(name AS BLOB), CAST(basmala AS BLOB) FROM surah '
      'ORDER BY number',
    );
    if (rows.length != surahs.length) {
      throw StateError('${rows.length} surahs stored, ${surahs.length} given');
    }
    void expectStored(String where, Object? stored, SpikeText? given) {
      final same = switch ((stored, given)) {
        (null, null) => true,
        (final Uint8List bytes, final SpikeText text) =>
          _equalsAt(bytes, source, text.byteOffset) &&
              bytes.length == utf8.encode(text.value).length,
        _ => false,
      };
      if (!same) throw StateError('$where: stored bytes differ from source');
    }

    final digests = <String, String>{};
    for (final (s, surah) in surahs.indexed) {
      final row = rows[s];
      if (row.columnAt(0) != s + 1) throw StateError('surah ${s + 1} missing');
      expectStored('surah ${s + 1} name', row.columnAt(1), surah.name);
      expectStored('surah ${s + 1} basmala', row.columnAt(2), surah.basmala);
      final ayat = db.select(
        'SELECT number, CAST(text AS BLOB) FROM ayah WHERE surah = ? '
        'ORDER BY number',
        [s + 1],
      );
      if (ayat.length != surah.ayat.length) {
        throw StateError('surah ${s + 1}: ${ayat.length} ayat stored');
      }
      final fields = <(int, Uint8List)>[
        if (row.columnAt(2) case final Uint8List basmala) (0, basmala),
      ];
      for (final (a, ayah) in surah.ayat.indexed) {
        final stored = ayat[a];
        if (stored.columnAt(0) != a + 1) {
          throw StateError('ayah ${s + 1}:${a + 1} missing');
        }
        expectStored('ayah ${s + 1}:${a + 1}', stored.columnAt(1), ayah);
        fields.add((a + 1, stored.columnAt(1) as Uint8List));
      }
      digests['${s + 1}'] = _digest(fields);
    }
    return digests;
  } finally {
    db.close();
  }
}

String _digest(List<(int, Uint8List)> fields) {
  final out = BytesBuilder(copy: false);
  for (final (number, bytes) in fields) {
    out
      ..add(
        (ByteData(8)
              ..setUint32(0, number)
              ..setUint32(4, bytes.length))
            .buffer
            .asUint8List(),
      )
      ..add(bytes);
  }
  return sha256.convert(out.takeBytes()).toString();
}

String get _summary {
  final every = [
    for (final MapEntry(:key, :value) in spikeDivisionEvery.entries)
      'a $key every $value ayat',
  ].join(', ');
  return 'Spike S1 pack (D-068, D-072); not for release, not reviewed. '
      'Words are the maximal runs between U+0020 characters, offsets in '
      'UTF-16 code units (spike only; B0.4 and D-038 decide). Divisions are '
      'synthetic, not the edition\'s: $every, counted across the text. No '
      'sajdas. Revelation place and order are not given.';
}

Map<String, Object?> _manifest({
  required SpikeSource source,
  required String fontSha256,
  required String textSha256,
  required int textBytes,
  required Map<String, String> surahSha256,
  required Map<String, Object?> counts,
}) => {
  'format': 'holyquran-pack',
  'format_version': _formatVersion,
  'id': spikePackId,
  'kind': 'text',
  'version': spikePackVersion,
  'changelog': [
    {
      'version': spikePackVersion,
      'date': source.fetchedOn,
      'summary': _summary,
    },
  ],
  'riwaya': 'hafs',
  'edition': 'spike-synthetic-divisions',
  'font': {'family': 'Amiri Quran', 'version': '1.003', 'sha256': fontSha256},
  'sources': [
    {
      'role': 'text',
      'registry_row': 1,
      'name': 'Tanzil Quran Text (Uthmani)',
      'publisher': 'Tanzil Project',
      'url': source.url,
      'version': source.version,
      'fetched_on': source.fetchedOn,
      'file_sha256': sha256.convert(source.bytes).toString(),
      'trust_grade': 'A',
      'licence': {
        'text': null,
        'permission_ref': 'docs/SOURCES.md, registry row 1: CC BY 3.0',
        'notice': source.notice,
        'allows_export': true,
      },
    },
  ],
  'files': [
    {'name': _textFile, 'sha256': textSha256, 'bytes': textBytes},
  ],
  'surah_sha256': surahSha256,
  'counts': counts,
  'reviews': <Object?>[],
};
