import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'raw_pack.dart';
import 'synthetic_files.dart';

const recitationFileName = 'recitation.sqlite';

/// One row of the file table, and the synthetic bytes it describes.
final class SyntheticRecitationFile {
  SyntheticRecitationFile({
    required this.qualityKbps,
    required this.part,
    required this.surah,
    required this.ayah,
    required this.path,
    required this.audio,
    required this.bytes,
    required this.sha256,
    required this.durationMs,
  });

  final int qualityKbps;

  /// `surah`, `ayah`, `basmala` or `istiadha`.
  final String part;
  final int? surah;
  final int? ayah;
  final String path;

  /// Synthetic bytes standing for the audio; never a recording.
  final Uint8List audio;
  final int bytes;
  final String sha256;
  final int? durationMs;
}

/// The ayah counts of the surahs of the default synthetic text pack.
const defaultSyntheticAyahCounts = [4, 3, 1];

/// One defect, applied to an otherwise valid recitation pack.
enum SyntheticRecitationFault {
  /// The first file has 0 bytes.
  zeroBytes,

  /// The first file's hash is in upper case.
  upperCaseHash,

  /// The basmala of the lowest quality is listed twice.
  duplicateBasmala,

  /// A file of the other unit is added: a surah file in an ayah recitation,
  /// an ayah file in a surah recitation.
  partOfOtherUnit,

  /// A file for an ayah after the end of the last surah is added.
  fileOutsideText,

  /// `counts.files` is one more than stored.
  wrongFileCount,

  /// The base URL is `http`.
  insecureBaseUrl,
}

final class SyntheticRecitationPack {
  SyntheticRecitationPack({
    required this.directory,
    required this.manifest,
    required this.reciter,
    required this.style,
    required this.unit,
    required this.baseUrl,
    required this.files,
  });

  final Directory directory;
  final Map<String, Object?> manifest;
  final String reciter;
  final String style;

  /// `ayah` or `surah`.
  final String unit;
  final String baseUrl;

  /// As stored.
  final List<SyntheticRecitationFile> files;

  File get file => File('${directory.path}/$recitationFileName');
}

// The DDL of docs/CONTENT_PACKS.md, "Recitation pack".
const _schema = [
  '''
CREATE TABLE recitation (
  reciter  TEXT NOT NULL,
  style    TEXT NOT NULL,
  unit     TEXT NOT NULL CHECK (unit IN ('ayah','surah')),
  base_url TEXT NOT NULL
) STRICT''',
  '''
CREATE TABLE file (
  quality_kbps INTEGER NOT NULL CHECK (quality_kbps > 0),
  part         TEXT NOT NULL CHECK (part IN ('surah','ayah','basmala','istiadha')),
  surah        INTEGER,
  ayah         INTEGER,
  path         TEXT NOT NULL,
  bytes        INTEGER NOT NULL,
  sha256       TEXT NOT NULL,
  duration_ms  INTEGER,
  PRIMARY KEY (path),
  UNIQUE (quality_kbps, part, surah, ayah)
) STRICT, WITHOUT ROWID''',
];

SyntheticRecitationFile _file(
  int quality,
  String part,
  int? surah,
  int? ayah, {
  String? path,
  int? durationMs,
}) {
  final name = path ?? '$quality/$part-${surah ?? 0}-${ayah ?? 0}.mp3';
  final audio = utf8.encode('synthetic audio $name');
  return SyntheticRecitationFile(
    qualityKbps: quality,
    part: part,
    surah: surah,
    ayah: ayah,
    path: name,
    audio: audio,
    bytes: audio.length,
    sha256: sha256.convert(audio).toString(),
    durationMs: durationMs,
  );
}

/// Builds `<root>/<id>/<version>/` with `recitation.sqlite` and
/// `manifest.json` for a recitation by [unit] (`ayah` or `surah`) over
/// surahs of [ayahCounts], in two qualities. The higher quality also has the
/// reciter's basmala and isti'adha; one file states no duration. Then
/// applies [fault], if any.
Future<SyntheticRecitationPack> buildSyntheticRecitationPack(
  Directory root, {
  String unit = 'ayah',
  List<int> ayahCounts = defaultSyntheticAyahCounts,
  SyntheticRecitationFault? fault,
  String id = 'synthetic-recitation',
  int version = 1,
}) async {
  const qualities = [64, 128];
  final files = [
    for (final quality in qualities) ...[
      if (quality == qualities.last) ...[
        _file(quality, 'basmala', null, null, durationMs: 1500),
        _file(quality, 'istiadha', null, null, durationMs: 2500),
      ],
      for (final (s, count) in ayahCounts.indexed)
        if (unit == 'surah')
          _file(quality, 'surah', s + 1, null, durationMs: 60000 + s)
        else
          for (var a = 1; a <= count; a++)
            _file(
              quality,
              'ayah',
              s + 1,
              a,
              durationMs: s == 0 && a == 1 ? null : 1000 * a + s,
            ),
    ],
  ];
  SyntheticRecitationFile edited(
    SyntheticRecitationFile file, {
    int? bytes,
    String? sha256,
  }) => SyntheticRecitationFile(
    qualityKbps: file.qualityKbps,
    part: file.part,
    surah: file.surah,
    ayah: file.ayah,
    path: file.path,
    audio: file.audio,
    bytes: bytes ?? file.bytes,
    sha256: sha256 ?? file.sha256,
    durationMs: file.durationMs,
  );
  switch (fault) {
    case SyntheticRecitationFault.zeroBytes:
      files[0] = edited(files[0], bytes: 0);
    case SyntheticRecitationFault.upperCaseHash:
      files[0] = edited(files[0], sha256: files[0].sha256.toUpperCase());
    case SyntheticRecitationFault.duplicateBasmala:
      files.add(
        _file(qualities.last, 'basmala', null, null, path: 'extra.mp3'),
      );
    case SyntheticRecitationFault.partOfOtherUnit:
      files.add(
        unit == 'surah'
            ? _file(qualities.first, 'ayah', 1, 1)
            : _file(qualities.first, 'surah', 1, null),
      );
    case SyntheticRecitationFault.fileOutsideText:
      files.add(
        unit == 'surah'
            ? _file(qualities.first, 'surah', ayahCounts.length + 1, null)
            : _file(
                qualities.first,
                'ayah',
                ayahCounts.length,
                ayahCounts.last + 1,
              ),
      );
    default:
  }
  const reciter = '$syntheticArabic reciter';
  const style = 'Synthetic style \u{E9}';
  final baseUrl = fault == SyntheticRecitationFault.insecureBaseUrl
      ? 'http://example.invalid/synthetic/'
      : 'https://example.invalid/synthetic/';

  final directory = await Directory(
    '${root.path}/$id/$version',
  ).create(recursive: true);
  final file = File('${directory.path}/$recitationFileName');
  writePackFile(
    file,
    userVersion: newestPackFormatVersion,
    schema: _schema,
    fill: (db) {
      db.execute(
        'INSERT INTO recitation VALUES (CAST(? AS TEXT), CAST(? AS TEXT), ?, ?)',
        [utf8.encode(reciter), utf8.encode(style), unit, baseUrl],
      );
      for (final f in files) {
        db.execute('INSERT INTO file VALUES (?, ?, ?, ?, ?, ?, ?, ?)', [
          f.qualityKbps,
          f.part,
          f.surah,
          f.ayah,
          f.path,
          f.bytes,
          f.sha256,
          f.durationMs,
        ]);
      }
    },
  );

  final manifest = syntheticManifest(
    formatVersion: newestPackFormatVersion,
    id: id,
    kind: 'recitation',
    version: version,
    fields: {
      'sources': [syntheticSource('recitation', 7, null)],
      'files': [await fileEntry(file)],
      'counts': {
        'files':
            files.length +
            (fault == SyntheticRecitationFault.wrongFileCount ? 1 : 0),
      },
    },
  );
  await writeManifest(directory, manifest);
  return SyntheticRecitationPack(
    directory: directory,
    manifest: manifest,
    reciter: reciter,
    style: style,
    unit: unit,
    baseUrl: baseUrl,
    files: files,
  );
}
