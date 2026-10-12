import 'dart:convert';
import 'dart:io';

import 'raw_pack.dart';
import 'synthetic_files.dart';

const tafsirFileName = 'tafsir.sqlite';

/// The facts of a synthetic tafsir book; never a real book.
final class SyntheticBook {
  const SyntheticBook({
    required this.title,
    required this.author,
    this.publisher,
    this.edition,
    this.editor,
  });

  final String title;
  final String author;
  final String? publisher;
  final String? edition;
  final String? editor;
}

/// One passage over ayat [firstAyah] to [lastAyah] of [surah]. Its text is
/// never tafsir text.
final class SyntheticPassage {
  const SyntheticPassage(this.surah, this.firstAyah, this.lastAyah, this.text);

  final int surah;
  final int firstAyah;
  final int lastAyah;
  final String text;
}

const defaultSyntheticBook = SyntheticBook(
  title: 'Synthetic tafsir title',
  author: '$syntheticArabic author',
  publisher: 'Synthetic publisher \u{E9}',
  editor: 'Synthetic editor e\u{301}',
);

/// Passages over the surahs of the default synthetic text pack (four, three
/// and one ayat): one over three ayat, then ayah 1:4 with none, passages of
/// one and two ayat, and texts that would change under any normalising,
/// trimming or re-encoding.
const defaultSyntheticPassages = [
  SyntheticPassage(1, 1, 3, '$syntheticArabic over three ayat'),
  SyntheticPassage(2, 1, 1, ' e\u{301} \u{E9} $syntheticArabic  '),
  SyntheticPassage(2, 2, 3, 'Synthetic \u{1F600} passage \u{FEFF}inside'),
  SyntheticPassage(3, 1, 1, 'Synthetic\nlast passage'),
];

/// One defect, applied to an otherwise valid tafsir pack.
enum SyntheticTafsirFault {
  /// The second passage ends inside the third.
  overlappingPassages,

  /// The first passage ends before it starts.
  reversedRange,

  /// The last passage reaches an ayah after the end of its surah in the
  /// default synthetic text pack.
  passageOutsideText,

  /// `counts.passages` is one more than stored.
  wrongPassageCount,

  /// The book is stored twice.
  twoBookRows,

  /// The title is stored with a leading U+FEFF.
  leadingBom,
}

final class SyntheticTafsirPack {
  SyntheticTafsirPack({
    required this.directory,
    required this.manifest,
    required this.book,
    required this.passages,
  });

  final Directory directory;
  final Map<String, Object?> manifest;
  final SyntheticBook book;

  /// As stored, numbered from 1 in this order.
  final List<SyntheticPassage> passages;

  File get file => File('${directory.path}/$tafsirFileName');
}

// The DDL of docs/CONTENT_PACKS.md, "Tafsir pack".
const _schema = [
  '''
CREATE TABLE book (
  title     TEXT NOT NULL,
  author    TEXT NOT NULL,
  publisher TEXT,
  edition   TEXT,
  editor    TEXT
) STRICT''',
  '''
CREATE TABLE passage (
  number     INTEGER PRIMARY KEY,
  surah      INTEGER NOT NULL,
  first_ayah INTEGER NOT NULL,
  last_ayah  INTEGER NOT NULL,
  text       TEXT NOT NULL,
  UNIQUE (surah, first_ayah)
) STRICT''',
];

/// Builds `<root>/<id>/<version>/` with `tafsir.sqlite` and `manifest.json`,
/// then applies [fault], if any.
Future<SyntheticTafsirPack> buildSyntheticTafsirPack(
  Directory root, {
  SyntheticBook book = defaultSyntheticBook,
  List<SyntheticPassage> passages = defaultSyntheticPassages,
  SyntheticTafsirFault? fault,
  String id = 'synthetic-tafsir',
  int version = 1,
}) async {
  final stored = [...passages];
  SyntheticPassage changed(int index, {int? firstAyah, int? lastAyah}) =>
      SyntheticPassage(
        stored[index].surah,
        firstAyah ?? stored[index].firstAyah,
        lastAyah ?? stored[index].lastAyah,
        stored[index].text,
      );
  switch (fault) {
    case SyntheticTafsirFault.overlappingPassages:
      stored[1] = changed(1, lastAyah: 2);
    case SyntheticTafsirFault.reversedRange:
      stored[0] = changed(0, firstAyah: 3, lastAyah: 1);
    case SyntheticTafsirFault.passageOutsideText:
      stored[stored.length - 1] = changed(
        stored.length - 1,
        lastAyah: stored.last.lastAyah + 1,
      );
    default:
  }
  final storedBook = fault == SyntheticTafsirFault.leadingBom
      ? SyntheticBook(
          title: '\u{FEFF}${book.title}',
          author: book.author,
          publisher: book.publisher,
          edition: book.edition,
          editor: book.editor,
        )
      : book;

  final directory = await Directory(
    '${root.path}/$id/$version',
  ).create(recursive: true);
  final file = File('${directory.path}/$tafsirFileName');
  writePackFile(
    file,
    userVersion: newestPackFormatVersion,
    schema: _schema,
    fill: (db) {
      for (
        var i = 0;
        i < (fault == SyntheticTafsirFault.twoBookRows ? 2 : 1);
        i++
      ) {
        db.execute(
          'INSERT INTO book VALUES (CAST(? AS TEXT), CAST(? AS TEXT), '
          'CAST(? AS TEXT), CAST(? AS TEXT), CAST(? AS TEXT))',
          [
            for (final text in [
              storedBook.title,
              storedBook.author,
              storedBook.publisher,
              storedBook.edition,
              storedBook.editor,
            ])
              text == null ? null : utf8.encode(text),
          ],
        );
      }
      for (final (index, passage) in stored.indexed) {
        db.execute('INSERT INTO passage VALUES (?, ?, ?, ?, CAST(? AS TEXT))', [
          index + 1,
          passage.surah,
          passage.firstAyah,
          passage.lastAyah,
          utf8.encode(passage.text),
        ]);
      }
    },
  );

  final manifest = syntheticManifest(
    formatVersion: newestPackFormatVersion,
    id: id,
    kind: 'tafsir',
    version: version,
    fields: {
      'sources': [syntheticSource('tafsir', 18, null)],
      'files': [await fileEntry(file)],
      'counts': {
        'passages':
            stored.length +
            (fault == SyntheticTafsirFault.wrongPassageCount ? 1 : 0),
      },
    },
  );
  await writeManifest(directory, manifest);
  return SyntheticTafsirPack(
    directory: directory,
    manifest: manifest,
    book: storedBook,
    passages: stored,
  );
}
