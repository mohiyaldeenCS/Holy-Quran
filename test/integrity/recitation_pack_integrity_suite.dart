import 'package:holyquran/data/services/recitation_pack_index.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/domain/models/recitation_file.dart';

import '../../testing/packs/synthetic_recitation_pack.dart'
    show recitationFileName;
import 'pack_file_suite.dart';
import 'pack_integrity_suite.dart';

// The integrity suite for one recitation pack (docs/CONTENT_PACKS.md,
// "Recitation pack"). The audio files themselves are fetched later and each
// checked against its row; here every row must give what that check needs.

void defineRecitationPackIntegritySuite(
  String description,
  Future<String> Function() packDirectory, {
  Future<String?> Function()? textPackDirectory,
}) => definePackFileSuite(
  description,
  recitationFileName,
  packDirectory,
  checks: recitationPackChecks,
  textChecks: {
    'has files only for surahs and ayat of the text pack':
        recitationTextProblems,
  },
  textPackDirectory: textPackDirectory,
);

final recitationPackChecks = <String, PackFileCheck>{
  'has the header of a format 2 pack file': (pack) =>
      fileHeaderProblems(pack.file, pack.manifest.formatVersion),
  'has the tables and columns of a recitation pack, STRICT': (pack) async =>
      rawSchemaProblems(pack.raw, _schema),
  'sits in the directories its id and version name': (pack) =>
      directoryLocationProblems(pack.directory),
  'stores its recitation once, with a unit and an https base URL':
      recitationFactsProblems,
  'lists counts.files files, each with a size, a SHA-256 and a relative path':
      recitationFileProblems,
  'lists each file once per quality, of the parts its unit allows':
      recitationPartProblems,
  'gives every file as stored': recitationReadProblems,
};

const _schema = {
  'recitation': (
    false,
    [
      'reciter TEXT NOT NULL',
      'style TEXT NOT NULL',
      'unit TEXT NOT NULL',
      'base_url TEXT NOT NULL',
    ],
  ),
  'file': (
    true,
    [
      'quality_kbps INTEGER NOT NULL',
      'part TEXT NOT NULL',
      'surah INTEGER',
      'ayah INTEGER',
      'path TEXT NOT NULL pk1',
      'bytes INTEGER NOT NULL',
      'sha256 TEXT NOT NULL',
      'duration_ms INTEGER',
    ],
  ),
};

typedef _Row = ({
  int quality,
  String part,
  int? surah,
  int? ayah,
  String path,
  int bytes,
  String sha256,
  int? durationMs,
});

List<_Row> _files(PackFileUnderTest pack) => [
  for (final [quality, part, surah, ayah, path, bytes, sha256, duration]
      in pack.raw.rows(
        'SELECT quality_kbps, part, surah, ayah, path, bytes, sha256, '
        'duration_ms FROM file ORDER BY quality_kbps, path',
      ))
    (
      quality: quality! as int,
      part: part! as String,
      surah: surah as int?,
      ayah: ayah as int?,
      path: path! as String,
      bytes: bytes! as int,
      sha256: sha256! as String,
      durationMs: duration as int?,
    ),
];

String? _unit(PackFileUnderTest pack) =>
    switch (pack.raw.rows('SELECT unit FROM recitation')) {
      [[final String unit]] => unit,
      _ => null,
    };

Future<List<String>> recitationFactsProblems(PackFileUnderTest pack) async {
  final rows = pack.raw.rows(
    'SELECT CAST(reciter AS BLOB), CAST(style AS BLOB), unit, base_url '
    'FROM recitation',
  );
  if (rows.length != 1) return ['recitation has ${rows.length} rows, not 1'];
  final [reciter, style, unit, baseUrl] = rows.single;
  final url = Uri.tryParse(baseUrl! as String);
  return [
    for (final (name, bytes) in [('reciter', reciter), ('style', style)]) ...[
      if ((bytes! as List<int>).isEmpty) 'recitation.$name is empty',
      if (startsWithBom(bytes as List<int>))
        'recitation.$name begins with EF BB BF',
    ],
    if (unit != 'ayah' && unit != 'surah') 'recitation.unit is $unit',
    if (url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        url.hasQuery ||
        url.hasFragment ||
        !url.path.endsWith('/'))
      'recitation.base_url is not an https base URL ending in /',
  ];
}

Future<List<String>> recitationFileProblems(PackFileUnderTest pack) async {
  final files = _files(pack);
  final listed = (pack.manifest.kindCounts as RecitationCounts).files;
  final hash = RegExp(r'^[0-9a-f]{64}$');
  return [
    if (files.length != listed)
      'counts.files is $listed; the file holds ${files.length}',
    for (final file in files) ...[
      if (file.quality < 1) '${file.path}: quality ${file.quality}',
      if (file.bytes < 1) '${file.path}: ${file.bytes} bytes',
      if (!hash.hasMatch(file.sha256)) '${file.path}: no lowercase SHA-256',
      if (!RecitationFile.pathPattern.hasMatch(file.path) ||
          file.path.split('/').any((s) => s == '.' || s == '..'))
        '${file.path}: not a plain relative path',
      if (file.durationMs case final ms? when ms < 1)
        '${file.path}: a duration of $ms ms',
    ],
  ];
}

Future<List<String>> recitationPartProblems(PackFileUnderTest pack) async {
  final unit = _unit(pack);
  final problems = <String>[];
  final seen = <(int, String, int?, int?)>{};
  for (final file in _files(pack)) {
    final (needsSurah, needsAyah) = switch (file.part) {
      'ayah' => (true, true),
      'surah' => (true, false),
      _ => (false, false),
    };
    if (const {'ayah', 'surah', 'basmala', 'istiadha'}.contains(file.part) ==
        false) {
      problems.add('${file.path}: the part ${file.part}');
    } else if ((file.part == 'ayah' || file.part == 'surah') &&
        file.part != unit) {
      problems.add(
        '${file.path}: a ${file.part} file of a recitation by $unit',
      );
    }
    if ((file.surah != null) != needsSurah ||
        (file.ayah != null) != needsAyah) {
      problems.add(
        '${file.path}: a ${file.part} file of surah ${file.surah}, '
        'ayah ${file.ayah}',
      );
    }
    if (!seen.add((file.quality, file.part, file.surah, file.ayah))) {
      problems.add(
        '${file.path}: a second ${file.part} file of ${file.surah}:'
        '${file.ayah} at ${file.quality} kbps',
      );
    }
  }
  return problems;
}

Future<List<String>> recitationTextProblems(PackFileUnderTest pack) async {
  final counts = pack.ayahCounts;
  return [
    for (final file in _files(pack))
      if (file.surah case final surah?)
        if (counts[surah] case final count?)
          if (file.ayah case final ayah? when ayah > count)
            '${file.path}: ayah $surah:$ayah is not in the text pack'
          else
            ...const <String>[]
        else
          '${file.path}: surah $surah is not in the text pack',
  ];
}

Future<List<String>> recitationReadProblems(PackFileUnderTest pack) async {
  final problems = <String>[];
  final index = RecitationPackIndex.open(
    pack.file.path,
    formatVersion: pack.manifest.formatVersion,
  );
  pack.onClose(index.close);
  try {
    index.recitation();
    final read = {
      for (final quality in index.qualities())
        for (final file in index.files(quality)) file.path: file,
    };
    final stored = _files(pack);
    if (read.length != stored.length) {
      problems.add(
        'the app gives ${read.length} files; the file holds ${stored.length}',
      );
    }
    for (final row in stored) {
      final file = read[row.path];
      if (file == null) {
        problems.add('${row.path}: the app gives none');
      } else if ((
            file.qualityKbps,
            file.part.name,
            file.surah,
            file.ayah,
            file.bytes,
            file.sha256,
            file.duration?.inMilliseconds,
          ) !=
          (
            row.quality,
            row.part,
            row.surah,
            row.ayah,
            row.bytes,
            row.sha256,
            row.durationMs,
          )) {
        problems.add('${row.path}: the app gives another row');
      }
    }
  } on PackFailure catch (failure) {
    problems.add('the production reader refuses the pack: $failure');
  }
  return problems;
}
