import 'dart:convert';

import 'package:holyquran/data/services/tafsir_pack_database.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/domain/models/pack_text.dart';

import '../../testing/packs/synthetic_tafsir_pack.dart' show tafsirFileName;
import 'pack_file_suite.dart';
import 'pack_integrity_suite.dart';

// The integrity suite for one tafsir pack (docs/CONTENT_PACKS.md, "Tafsir
// pack"). Every expected value comes from the manifest or from the text pack
// of its riwaya.

void defineTafsirPackIntegritySuite(
  String description,
  Future<String> Function() packDirectory, {
  Future<String?> Function()? textPackDirectory,
}) => definePackFileSuite(
  description,
  tafsirFileName,
  packDirectory,
  checks: tafsirPackChecks,
  textChecks: {
    'has passages only over ayat of the text pack': tafsirTextProblems,
  },
  textPackDirectory: textPackDirectory,
);

final tafsirPackChecks = <String, PackFileCheck>{
  'has the header of a format 2 pack file': (pack) =>
      fileHeaderProblems(pack.file, pack.manifest.formatVersion),
  'has the tables and columns of a tafsir pack, STRICT': (pack) async =>
      rawSchemaProblems(pack.raw, _schema),
  'sits in the directories its id and version name': (pack) =>
      directoryLocationProblems(pack.directory),
  'stores its book once, with a title and an author': tafsirBookProblems,
  'numbers its passages 1 to counts.passages': tafsirNumberingProblems,
  'has passage ranges that are valid and in order': tafsirRangeProblems,
  'stores no empty passage and no text that begins with EF BB BF':
      tafsirTextBytesProblems,
  'gives the book and every passage as its stored bytes': tafsirReadProblems,
};

const _schema = {
  'book': (
    false,
    [
      'title TEXT NOT NULL',
      'author TEXT NOT NULL',
      'publisher TEXT',
      'edition TEXT',
      'editor TEXT',
    ],
  ),
  'passage': (
    false,
    [
      'number INTEGER pk1',
      'surah INTEGER NOT NULL',
      'first_ayah INTEGER NOT NULL',
      'last_ayah INTEGER NOT NULL',
      'text TEXT NOT NULL',
    ],
  ),
};

const _bookColumns =
    'CAST(title AS BLOB), CAST(author AS BLOB), CAST(publisher AS BLOB), '
    'CAST(edition AS BLOB), CAST(editor AS BLOB)';

/// `(number, surah, first, last, bytes)` of every passage, by number.
List<(int, int, int, int, List<int>)> _passages(PackFileUnderTest pack) => [
  for (final [number, surah, first, last, text] in pack.raw.rows(
    'SELECT number, surah, first_ayah, last_ayah, CAST(text AS BLOB) '
    'FROM passage ORDER BY number',
  ))
    (
      number! as int,
      surah! as int,
      first! as int,
      last! as int,
      text! as List<int>,
    ),
];

Future<List<String>> tafsirBookProblems(PackFileUnderTest pack) async {
  final rows = pack.raw.rows('SELECT $_bookColumns FROM book');
  return [
    if (rows.length != 1) 'book has ${rows.length} rows, not 1',
    for (final row in rows)
      for (final (index, name) in ['title', 'author'].indexed)
        if ((row[index]! as List<int>).isEmpty) 'book.$name is empty',
  ];
}

Future<List<String>> tafsirNumberingProblems(PackFileUnderTest pack) async {
  final numbers = [for (final passage in _passages(pack)) passage.$1];
  final listed = (pack.manifest.kindCounts as TafsirCounts).passages;
  return [
    if (numbers.length != listed)
      'counts.passages is $listed; the file holds ${numbers.length}',
    for (final (index, number) in numbers.indexed)
      if (number != index + 1) 'passage ${index + 1} is numbered $number',
  ];
}

/// Each range starts at ayah 1 or later and ends no earlier; passages
/// follow in mushaf order with no overlap.
Future<List<String>> tafsirRangeProblems(PackFileUnderTest pack) async {
  final problems = <String>[];
  (int, int)? previousEnd;
  for (final (number, surah, first, last, _) in _passages(pack)) {
    if (surah < 1 || first < 1) {
      problems.add('passage $number starts at $surah:$first');
    }
    if (last < first) {
      problems.add('passage $number ends at $surah:$last, before $first');
    }
    if (previousEnd case (
      final s,
      final a,
    ) when surah < s || (surah == s && first <= a)) {
      problems.add('passage $number starts at $surah:$first, not after $s:$a');
    }
    previousEnd = (surah, last);
  }
  return problems;
}

Future<List<String>> tafsirTextProblems(PackFileUnderTest pack) async {
  final counts = pack.ayahCounts;
  return [
    for (final (number, surah, _, last, _) in _passages(pack))
      if (counts[surah] case final count? when last <= count)
        ...const <String>[]
      else
        'passage $number reaches $surah:$last, which the text pack lacks',
  ];
}

Future<List<String>> tafsirTextBytesProblems(PackFileUnderTest pack) async => [
  for (final (number, _, _, _, bytes) in _passages(pack)) ...[
    if (bytes.isEmpty) 'passage $number is empty',
    if (startsWithBom(bytes)) 'passage $number begins with EF BB BF',
  ],
  for (final row in pack.raw.rows('SELECT $_bookColumns FROM book'))
    for (final (index, name) in [
      'title',
      'author',
      'publisher',
      'edition',
      'editor',
    ].indexed)
      if (startsWithBom(row[index] as List<int>?))
        'book.$name begins with EF BB BF',
];

Future<List<String>> tafsirReadProblems(PackFileUnderTest pack) async {
  final problems = <String>[];
  final database = TafsirPackDatabase.open(
    pack.file.path,
    formatVersion: pack.manifest.formatVersion,
    riwaya: pack.manifest.riwaya!,
  );
  pack.onClose(database.close);
  void expectBytes(String where, PackText? text, Object? bytes) {
    final stored = bytes as List<int>?;
    if (text == null || stored == null) {
      if ((text == null) != (stored == null)) {
        problems.add('$where: the app gives ${text ?? 'none'}');
      }
      return;
    }
    if (byteMismatch(utf8.encode(text.verbatim), stored) case final m?) {
      problems.add('$where: the app gives $m');
    }
  }

  try {
    final book = database.book();
    final [stored, ...] = pack.raw.rows('SELECT $_bookColumns FROM book');
    expectBytes('book.title', book.title, stored[0]);
    expectBytes('book.author', book.author, stored[1]);
    expectBytes('book.publisher', book.publisher, stored[2]);
    expectBytes('book.edition', book.edition, stored[3]);
    expectBytes('book.editor', book.editor, stored[4]);
    final passages = _passages(pack);
    final surahs = {for (final passage in passages) passage.$2};
    final read = [
      for (final surah in surahs) ...database.passagesOfSurah(surah),
    ];
    if (read.length != passages.length) {
      problems.add(
        'the app gives ${read.length} passages; the file holds '
        '${passages.length}',
      );
    }
    final byNumber = {for (final passage in read) passage.number: passage};
    for (final (number, surah, first, last, bytes) in passages) {
      final passage = byNumber[number];
      if (passage == null) {
        problems.add('passage $number: the app gives none');
        continue;
      }
      final range = passage.range;
      if ((range.start.surah, range.start.ayah, range.end.ayah) !=
          (surah, first, last)) {
        problems.add('passage $number: the app gives the range $range');
      }
      expectBytes('passage $number', passage.text, bytes);
      for (final ayah in {first, last}) {
        if (database.passageAt(surah, ayah)?.number != number) {
          problems.add('$surah:$ayah: the app does not give passage $number');
        }
      }
    }
  } on PackFailure catch (failure) {
    problems.add('the production reader refuses the pack: $failure');
  }
  return problems;
}
