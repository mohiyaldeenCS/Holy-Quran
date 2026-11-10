import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/services/tafsir_pack_database.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_range.dart';
import 'package:holyquran/domain/models/tafsir_passage.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../testing/packs/raw_pack.dart';
import '../../../testing/packs/synthetic_pack.dart';
import '../../../testing/packs/synthetic_tafsir_pack.dart';

// Every string is synthetic; non-ASCII characters are written as escapes.

(int, int?) _where(TextEncodingRejected failure) =>
    (failure.surah, failure.ayah);

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('tafsir_pack_database_test');
  });
  tearDown(() => root.delete(recursive: true));

  TafsirPackDatabase open(SyntheticTafsirPack pack) {
    final db = TafsirPackDatabase.open(
      pack.file.path,
      formatVersion: 2,
      riwaya: 'hafs',
    );
    addTearDown(db.close);
    return db;
  }

  Matcher throwsFailure<T extends PackFailure>([
    Object? Function(T failure)? feature,
    Object? expected,
  ]) => throwsA(
    feature == null ? isA<T>() : isA<T>().having(feature, 'failure', expected),
  );

  QuranRange range(int surah, int first, int last) => QuranRange(
    QuranAddress('hafs', surah, first),
    QuranAddress('hafs', surah, last),
  );

  void expectPassage(TafsirPassage? passage, int number, SyntheticPassage of) {
    expect(passage, isNotNull);
    expect(passage!.number, number);
    expect(passage.range, range(of.surah, of.firstAyah, of.lastAyah));
    expect(utf8.encode(passage.text.verbatim), utf8.encode(of.text));
  }

  group('reads', () {
    late SyntheticTafsirPack pack;
    late TafsirPackDatabase db;

    setUp(() async {
      pack = await buildSyntheticTafsirPack(root);
      db = open(pack);
    });

    test('the book, byte for byte, an absent fact as null', () {
      final book = db.book();
      expect(book.title.verbatim, pack.book.title);
      expect(book.author.verbatim, pack.book.author);
      expect(book.publisher!.verbatim, pack.book.publisher);
      expect(book.edition, isNull);
      expect(book.editor!.verbatim, 'Synthetic editor e\u{301}');
    });

    test('the number of passages', () {
      expect(db.passageCount(), pack.passages.length);
    });

    test('the passage over several ayat from each of its ayat', () {
      for (var ayah = 1; ayah <= 3; ayah++) {
        expectPassage(db.passageAt(1, ayah), 1, pack.passages[0]);
      }
    });

    test('no passage for an ayah the book does not explain', () {
      expect(db.passageAt(1, 4), isNull);
      expect(db.passageAt(4, 1), isNull);
    });

    test('every passage of a surah in order, its text as stored', () {
      final raw = RawPack.open(pack.file);
      addTearDown(raw.close);
      final stored = {
        for (final [number, text] in raw.rows(
          'SELECT number, CAST(text AS BLOB) FROM passage',
        ))
          number! as int: text! as List<int>,
      };
      final read = [
        for (var surah = 1; surah <= 3; surah++) ...db.passagesOfSurah(surah),
      ];
      expect(read.map((p) => p.number), [1, 2, 3, 4]);
      for (final (index, passage) in read.indexed) {
        expectPassage(passage, index + 1, pack.passages[index]);
        expect(utf8.encode(passage.text.verbatim), stored[passage.number]);
      }
      expect(db.passagesOfSurah(4), isEmpty);
    });
  });

  group('refuses', () {
    Future<TafsirPackDatabase> faulty(SyntheticTafsirFault fault) async =>
        open(await buildSyntheticTafsirPack(root, fault: fault));

    test('overlapping passages', () async {
      final db = await faulty(SyntheticTafsirFault.overlappingPassages);
      expect(() => db.passageAt(2, 2), throwsFailure<PackInconsistent>());
      expect(() => db.passagesOfSurah(2), throwsFailure<PackInconsistent>());
      expect(db.passagesOfSurah(1), hasLength(1));
    });

    test('a range that ends before it starts', () async {
      final db = await faulty(SyntheticTafsirFault.reversedRange);
      expect(() => db.passagesOfSurah(1), throwsFailure<PackInconsistent>());
    });

    test('a book stored twice', () async {
      final db = await faulty(SyntheticTafsirFault.twoBookRows);
      expect(
        db.book,
        throwsFailure<PackInconsistent>(
          (f) => f.reason,
          'book has 2 rows, not 1',
        ),
      );
    });

    test('a title that begins with U+FEFF', () async {
      final db = await faulty(SyntheticTafsirFault.leadingBom);
      expect(db.book, throwsFailure<PackInconsistent>());
    });

    test('a passage whose text begins with U+FEFF', () async {
      final pack = await buildSyntheticTafsirPack(
        root,
        passages: const [SyntheticPassage(1, 2, 2, '\u{FEFF}Synthetic')],
      );
      expect(
        () => open(pack).passageAt(1, 2),
        throwsFailure<TextEncodingRejected>((f) => (f.surah, f.ayah), (1, 2)),
      );
    });

    test('a format version other than 2, and a text pack', () async {
      final pack = await buildSyntheticTafsirPack(root);
      for (final version in [1, 3]) {
        expect(
          () => TafsirPackDatabase.open(
            pack.file.path,
            formatVersion: version,
            riwaya: 'hafs',
          ),
          throwsFailure<UnsupportedPackFormat>((f) => f.formatVersion, version),
        );
      }
      final text = await buildSyntheticPack(root, formatVersion: 2);
      expect(
        () => TafsirPackDatabase.open(
          text.textFile.path,
          formatVersion: 2,
          riwaya: 'hafs',
        ),
        throwsFailure<UnsupportedPackFormat>(),
      );
    });

    test('a missing file, and creates none', () {
      final path = '${root.path}/missing/$tafsirFileName';
      expect(
        () => TafsirPackDatabase.open(path, formatVersion: 2, riwaya: 'hafs'),
        throwsFailure<FileHashMismatch>(),
      );
      expect(File(path).existsSync(), isFalse);
    });
  });

  group('surah-level passages (D-184)', () {
    late SyntheticTafsirPack pack;
    late TafsirPackDatabase db;

    setUp(() async {
      pack = await buildSyntheticTafsirPack(
        root,
        passages: syntheticPassagesWithSurahLevel,
      );
      db = open(pack);
    });

    test('each is read for its surah, its text as stored', () {
      for (final (surah, index) in [(1, 0), (2, 2)]) {
        final whole = db.surahPassageOf(surah);
        expect(whole, isNotNull, reason: '$surah');
        expect(whole!.number, index + 1);
        expect(whole.surah, surah);
        expect(
          utf8.encode(whole.text.verbatim),
          utf8.encode(pack.passages[index].text),
        );
      }
    });

    test('a surah without one has none', () async {
      expect(db.surahPassageOf(3), isNull);
      expect(db.surahPassageOf(4), isNull);
      final plain = open(
        await buildSyntheticTafsirPack(Directory('${root.path}/plain')),
      );
      for (var surah = 1; surah <= 3; surah++) {
        expect(plain.surahPassageOf(surah), isNull);
      }
    });

    test('is neither an ayah passage nor reached by ayah', () {
      expect(db.passagesOfSurah(1).map((p) => p.number), [2]);
      expect(db.passagesOfSurah(2).map((p) => p.number), [4, 5]);
      expect(db.passageAt(1, 1)!.number, 2);
      expect(db.passageAt(2, 1)!.number, 4);
      expect(db.passageCount(), pack.passages.length);
    });
  });

  group('refuses on a surah as a whole', () {
    Future<TafsirPackDatabase> faulty(SyntheticTafsirFault fault) async =>
        open(await buildSyntheticTafsirPack(root, fault: fault));

    test('two passages in one surah', () async {
      final db = await faulty(SyntheticTafsirFault.twoSurahLevelPassages);
      expect(
        () => db.surahPassageOf(1),
        throwsFailure<PackInconsistent>(
          (f) => f.reason,
          'passages 1 and 2 are both on surah 1 as a whole',
        ),
      );
      expect(db.passagesOfSurah(1).map((p) => p.number), [3]);
    });

    test('a range from ayah 0 that is not 0..0', () async {
      final db = await faulty(SyntheticTafsirFault.rangeFromAyahZero);
      expect(() => db.passagesOfSurah(1), throwsFailure<PackInconsistent>());
      expect(() => db.passageAt(1, 1), throwsFailure<PackInconsistent>());
      expect(db.surahPassageOf(1), isNull);
    });

    test('a text that begins with U+FEFF', () async {
      final pack = await buildSyntheticTafsirPack(
        root,
        passages: const [
          SyntheticPassage.surahLevel(2, '\u{FEFF}Synthetic'),
          SyntheticPassage(2, 1, 1, 'Synthetic'),
        ],
      );
      final db = open(pack);
      expect(
        () => db.surahPassageOf(2),
        throwsFailure<TextEncodingRejected>(_where, (2, null)),
      );
      expect(db.passagesOfSurah(2), hasLength(1));
    });

    test('a text that is not UTF-8', () async {
      final pack = await buildSyntheticTafsirPack(
        root,
        passages: const [SyntheticPassage.surahLevel(2, 'Synthetic')],
      );
      sqlite3.open(pack.file.path)
        ..execute(
          "UPDATE passage SET text = CAST(X'53FF' AS TEXT) WHERE number = 1",
        )
        ..close();
      expect(
        () => open(pack).surahPassageOf(2),
        throwsFailure<TextEncodingRejected>(_where, (2, null)),
      );
    });
  });

  test('reading leaves the file unchanged', () async {
    final pack = await buildSyntheticTafsirPack(root);
    final hash = await fileSha256(pack.file);
    final db = open(pack)..book();
    for (var surah = 1; surah <= 3; surah++) {
      db.passagesOfSurah(surah);
    }
    expect(await fileSha256(pack.file), hash);
    expect(
      pack.directory.listSync().map((e) => e.uri.pathSegments.last).toSet(),
      {tafsirFileName, manifestFileName},
    );
  });
}
