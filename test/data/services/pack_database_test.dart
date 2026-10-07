import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/services/pack_database.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/surah_info.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../testing/packs/raw_pack.dart';
import '../../../testing/packs/synthetic_pack.dart';

// Every string is synthetic; non-ASCII characters are written as escapes.

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('pack_database_test');
  });
  tearDown(() => root.delete(recursive: true));

  PackDatabase open(SyntheticPack pack) {
    final db = PackDatabase.open(pack.textFile.path, formatVersion: 1);
    addTearDown(db.close);
    return db;
  }

  RawPack raw(SyntheticPack pack) {
    final raw = RawPack.open(pack.textFile);
    addTearDown(raw.close);
    return raw;
  }

  Matcher throwsFailure<T extends PackFailure>([
    Object? Function(T failure)? feature,
    Object? expected,
  ]) => throwsA(
    feature == null ? isA<T>() : isA<T>().having(feature, 'failure', expected),
  );

  group('reads', () {
    late SyntheticPack pack;
    late PackDatabase db;

    setUp(() async {
      pack = await buildSyntheticPack(root);
      db = open(pack);
    });

    test('every surah with its metadata', () {
      final surahs = db.surahs();
      final stored = raw(pack).surahs();
      expect(surahs.map((s) => s.number), [1, 2, 3]);
      for (final (index, surah) in surahs.indexed) {
        final synthetic = pack.surahs[index];
        expect(surah.name.verbatim, synthetic.name);
        expect(utf8.encode(surah.name.verbatim), stored[index].name);
        expect(surah.ayahCount, synthetic.ayat.length);
        expect(surah.revelationOrder, synthetic.revelationOrder);
      }
      expect(surahs.map((s) => s.revelationPlace), [
        RevelationPlace.makki,
        RevelationPlace.madani,
        null,
      ]);
    });

    test('every ayah as its stored bytes, unchanged', () {
      final stored = raw(pack);
      var ayat = 0;
      for (final (s, surah) in pack.surahs.indexed) {
        for (final (number, bytes) in stored.ayat(s + 1)) {
          final text = db.ayahText(s + 1, number)!;
          expect(utf8.encode(text.verbatim), bytes);
          expect(text.verbatim, surah.ayat[number - 1].text);
          expect(bytes, utf8.encode(surah.ayat[number - 1].text));
          ayat++;
        }
      }
      expect(ayat, 8);
    });

    test('NFC-unstable text, edge spaces and non-BMP text byte for byte', () {
      final precomposed = db.ayahText(1, 2)!.verbatim;
      final decomposed = db.ayahText(1, 3)!.verbatim;
      expect(precomposed.codeUnits, contains(0xE9));
      expect(decomposed.codeUnits, containsAllInOrder([0x65, 0x301]));
      final arabic = db.ayahText(1, 4)!.verbatim;
      expect(arabic.codeUnits.first, 0x20);
      expect(arabic.codeUnits.skip(arabic.length - 2), [0x20, 0x20]);
      expect(db.ayahText(2, 1)!.verbatim, 'Synthetic  double  spaces');
      expect(
        utf8.encode(db.ayahText(2, 2)!.verbatim),
        utf8.encode('ab \u{1F600} cd'),
      );
    });

    test('an ayah that is not stored as null', () {
      expect(db.ayahText(1, 5), isNull);
      expect(db.ayahText(4, 1), isNull);
      expect(db.ayahText(0, 1), isNull);
    });

    test('the basmala, or null where the surah has none', () {
      expect(db.basmala(1)!.verbatim, 'Synthetic opening line');
      expect(
        utf8.encode(db.basmala(3)!.verbatim),
        raw(pack).surahs()[2].basmala,
      );
      expect(db.basmala(2), isNull);
      expect(db.basmala(4), isNull);
    });

    test('word spans as stored, in UTF-16 code units', () {
      final stored = raw(pack);
      for (final (s, surah) in pack.surahs.indexed) {
        for (final (a, ayah) in surah.ayat.indexed) {
          expect(db.words(s + 1, a + 1), [
            for (final (n, start, end) in stored.words(s + 1, a + 1))
              (number: n, start: start, end: end),
          ]);
          expect(
            db.words(s + 1, a + 1).map((w) => (w.start, w.end)),
            ayah.spans,
          );
        }
      }
      expect(db.words(2, 2).last, (number: 3, start: 6, end: 8));
      expect(db.words(1, 9), isEmpty);
    });

    test('divisions and sajdas', () {
      expect(db.divisions(), hasLength(defaultSyntheticDivisions.length));
      expect(
        {
          for (final d in db.divisions())
            (d.kind.name, d.number, d.surah, d.ayah),
        },
        {
          for (final d in defaultSyntheticDivisions)
            (d.kind, d.number, d.surah, d.ayah),
        },
      );
      expect(db.divisions().first.kind, Division.hizb);
      expect(db.sajdas(), defaultSyntheticSajdas);
    });

    test('the number of rows of each table', () {
      final counts = db.rowCounts();
      expect(counts.surahs, pack.counts['surahs']);
      expect(counts.ayat, pack.counts['ayat']);
      expect(counts.words, pack.counts['words']);
      expect(counts.divisions, {
        for (final MapEntry(:key, :value)
            in (pack.counts['divisions']! as Map<String, Object?>).entries)
          Division.values.byName(key): value,
      });
      expect(counts.sajdas, pack.counts['sajdas']);
    });

    test('surah digests equal to the manifest and the raw reader', () {
      final stored = raw(pack);
      for (var surah = 1; surah <= 3; surah++) {
        expect(db.surahSha256(surah), pack.surahSha256['$surah']);
        expect(db.surahSha256(surah), stored.surahDigestOf(surah));
      }
      expect(db.surahSha256(4), isNull);
    });
  });

  test('surah digests match the documented test vectors', () async {
    const arabic =
        ' \u{646}\u{635} \u{62A}\u{62C}\u{631}\u{64A}\u{628}\u{64A}  ';
    SyntheticSurah surah(String second, {String? basmala}) => SyntheticSurah(
      name: 'Synthetic vector',
      basmala: basmala,
      ayat: [
        const SyntheticAyah('Synthetic ayah one'),
        SyntheticAyah('Synthetic $second two'),
        const SyntheticAyah(arabic),
      ],
    );
    const basmala = 'Synthetic opening line';
    final pack = await buildSyntheticPack(
      root,
      surahs: [
        surah('e\u{301}', basmala: basmala),
        surah('e\u{301}'),
        surah('\u{E9}', basmala: basmala),
        surah('\u{E9}'),
      ],
      divisions: const [],
      sajdas: const [],
    );
    final db = open(pack);
    expect(
      [for (var s = 1; s <= 4; s++) db.surahSha256(s)],
      [
        '881415c778b801345a189d02c780cfc9d52a5f92e4390af1e176e02c12b73bb8',
        '1e0042fff89902b157ace9af9ce04a42b5059b3babd38e73e803480413d8051c',
        '3e93c75c683b8258ecc0e2698acd10f06c07c025ac7dada60a691f8e46edf177',
        '0b1fede8d41e15b1529f9a121f4a57a590759dd23159e12b707d840cc68816cb',
      ],
    );
  });

  group('open refuses', () {
    Future<void> expectRefused(
      SyntheticFault fault, {
      required int? formatVersion,
    }) async {
      final pack = await buildSyntheticPack(root, fault: fault);
      expect(
        () => PackDatabase.open(pack.textFile.path, formatVersion: 1),
        throwsFailure<UnsupportedPackFormat>((f) => (f.pack, f.formatVersion), (
          pack.textFile.path,
          formatVersion,
        )),
      );
    }

    test('a file left in WAL mode', () async {
      await expectRefused(SyntheticFault.walHeader, formatVersion: 1);
    });

    test('a wrong application_id', () async {
      await expectRefused(SyntheticFault.wrongApplicationId, formatVersion: 1);
    });

    test('a user_version other than the format version', () async {
      await expectRefused(SyntheticFault.wrongUserVersion, formatVersion: 2);
    });

    test('a format version other than the file', () async {
      final pack = await buildSyntheticPack(root);
      expect(
        () => PackDatabase.open(pack.textFile.path, formatVersion: 2),
        throwsFailure<UnsupportedPackFormat>((f) => f.formatVersion, 1),
      );
    });

    test('a file that is not SQLite, or too short for a header', () async {
      final notSqlite = await File(
        '${root.path}/not.sqlite',
      ).writeAsBytes(List.filled(4096, 0x20));
      final short = await File('${root.path}/short.sqlite').writeAsBytes(
        (await (await buildSyntheticPack(
          root,
        )).textFile.readAsBytes()).take(99).toList(),
      );
      for (final file in [notSqlite, short]) {
        expect(
          () => PackDatabase.open(file.path, formatVersion: 1),
          throwsFailure<UnsupportedPackFormat>(),
        );
      }
    });

    test('a missing file, as a file whose bytes differ, and creates none', () {
      for (final path in [
        '${root.path}/missing/text.sqlite',
        '${root.path}/text.sqlite',
      ]) {
        expect(
          () => PackDatabase.open(path, formatVersion: 1),
          throwsFailure<FileHashMismatch>((f) => (f.pack, f.file), (
            path,
            'text.sqlite',
          )),
        );
      }
      expect(root.listSync(), isEmpty);
    });

    test('a directory in place of the file', () async {
      final directory = await Directory('${root.path}/text.sqlite').create();
      expect(
        () => PackDatabase.open(directory.path, formatVersion: 1),
        throwsFailure<FileHashMismatch>(),
      );
    });
  });

  group('text encoding', () {
    test('a leading U+FEFF is refused, not dropped', () async {
      final pack = await buildSyntheticPack(
        root,
        fault: SyntheticFault.leadingBom,
      );
      final db = open(pack);
      expect(
        () => db.ayahText(1, 1),
        throwsFailure<TextEncodingRejected>((f) => (f.pack, f.surah, f.ayah), (
          pack.textFile.path,
          1,
          1,
        )),
      );
      expect(db.ayahText(1, 2)!.verbatim, pack.surahs[0].ayat[1].text);
      expect(db.surahSha256(1), pack.surahSha256['1']);
    });

    test('a leading U+FEFF in a name or basmala is refused', () async {
      final pack = await buildSyntheticPack(
        root,
        surahs: const [
          SyntheticSurah(
            name: '\u{FEFF}Synthetic surah',
            basmala: '\u{FEFF}Synthetic opening line',
            ayat: [SyntheticAyah('Synthetic ayah')],
          ),
        ],
        divisions: const [],
        sajdas: const [],
      );
      final db = open(pack);
      final atName = throwsFailure<TextEncodingRejected>(
        (f) => (f.surah, f.ayah),
        (1, null),
      );
      expect(db.surahs, atName);
      expect(() => db.basmala(1), atName);
    });

    test('a U+FEFF after the start is kept', () async {
      final pack = await buildSyntheticPack(
        root,
        surahs: const [
          SyntheticSurah(
            name: 'Synthetic surah',
            ayat: [SyntheticAyah('Synthetic\u{FEFF} ayah')],
          ),
        ],
        divisions: const [],
        sajdas: const [],
      );
      expect(open(pack).ayahText(1, 1)!.verbatim, 'Synthetic\u{FEFF} ayah');
    });

    test('malformed UTF-8 is refused', () async {
      final pack = await buildSyntheticPack(root);
      final writable = sqlite3.open(pack.textFile.path);
      writable.execute(
        "UPDATE ayah SET text = CAST(X'53FF53' AS TEXT) WHERE surah = 2 AND number = 1",
      );
      writable.close();
      final db = open(pack);
      expect(
        () => db.ayahText(2, 1),
        throwsFailure<TextEncodingRejected>((f) => (f.surah, f.ayah), (2, 1)),
      );
      expect(db.ayahText(2, 2), isNotNull);
    });
  });

  group('open refuses a schema other than format v1:', () {
    var builds = 0;
    Future<SyntheticPack> changed(List<String> statements) async {
      final pack = await buildSyntheticPack(
        Directory('${root.path}/${builds++}'),
      );
      final writable = sqlite3.open(pack.textFile.path);
      try {
        statements.forEach(writable.execute);
      } finally {
        writable.close();
      }
      return pack;
    }

    void expectRefused(SyntheticPack pack) => expect(
      () => PackDatabase.open(pack.textFile.path, formatVersion: 1),
      throwsFailure<UnsupportedPackFormat>((f) => (f.pack, f.formatVersion), (
        pack.textFile.path,
        1,
      )),
    );

    const sajda = 'surah INTEGER NOT NULL, ayah INTEGER NOT NULL';
    const key = 'PRIMARY KEY (surah, ayah)';
    // Each variant replaces the sajda table, or the division table when the
    // change needs a column outside the primary key.
    const variants = {
      'a table that is missing': ('sajda', null),
      'a table that is not STRICT': ('sajda', '($sajda, $key) WITHOUT ROWID'),
      'a table that has a rowid': ('sajda', '($sajda, $key) STRICT'),
      'a column of another type': (
        'sajda',
        '(surah INTEGER NOT NULL, ayah INT NOT NULL, $key) '
            'STRICT, WITHOUT ROWID',
      ),
      'a column that may be null': (
        'division',
        '(kind TEXT NOT NULL, number INTEGER NOT NULL, surah INTEGER, '
            'ayah INTEGER NOT NULL, PRIMARY KEY (kind, number)) '
            'STRICT, WITHOUT ROWID',
      ),
      'a column that is missing': (
        'sajda',
        '(surah INTEGER NOT NULL PRIMARY KEY) STRICT, WITHOUT ROWID',
      ),
      'an extra column': (
        'sajda',
        '($sajda, note TEXT, $key) STRICT, WITHOUT ROWID',
      ),
      'a generated column': (
        'sajda',
        '($sajda, shown INTEGER GENERATED ALWAYS AS (ayah) VIRTUAL, $key) '
            'STRICT, WITHOUT ROWID',
      ),
      'columns in another order': (
        'sajda',
        '(ayah INTEGER NOT NULL, surah INTEGER NOT NULL, $key) '
            'STRICT, WITHOUT ROWID',
      ),
      'another primary key': (
        'sajda',
        '($sajda, PRIMARY KEY (ayah, surah)) STRICT, WITHOUT ROWID',
      ),
    };
    for (final MapEntry(key: name, value: (table, definition))
        in variants.entries) {
      test(name, () async {
        expectRefused(
          await changed([
            'DROP TABLE $table',
            if (definition != null) 'CREATE TABLE $table $definition',
          ]),
        );
      });
    }

    test('an extra table or view', () async {
      expectRefused(
        await changed(['CREATE TABLE synthetic (x INTEGER) STRICT']),
      );
      expectRefused(await changed(['CREATE VIEW synthetic AS SELECT 1']));
    });

    test('the fault nonStrictSchema', () async {
      expectRefused(
        await buildSyntheticPack(root, fault: SyntheticFault.nonStrictSchema),
      );
    });

    test('and accepts the schema rebuilt exactly', () async {
      const division =
          '(kind TEXT NOT NULL, number INTEGER NOT NULL, '
          'surah INTEGER NOT NULL, ayah INTEGER NOT NULL, '
          'PRIMARY KEY (kind, number)) STRICT, WITHOUT ROWID';
      final pack = await changed([
        'DROP TABLE sajda',
        'CREATE TABLE sajda ($sajda, $key) STRICT, WITHOUT ROWID',
        'DROP TABLE division',
        'CREATE TABLE division $division',
      ]);
      final db = open(pack);
      expect(db.sajdas(), isEmpty);
      expect(db.divisions(), isEmpty);
    });
  });

  test('an empty basmala is a text, not an absent one', () async {
    final pack = await buildSyntheticPack(
      root,
      surahs: const [
        SyntheticSurah(
          name: 'Synthetic surah',
          basmala: '',
          ayat: [SyntheticAyah('Synthetic ayah')],
        ),
      ],
      divisions: const [],
      sajdas: const [],
    );
    final db = open(pack);
    expect(db.basmala(1)!.verbatim, isEmpty);
    expect(raw(pack).surahs().single.basmala, isEmpty);
    expect(
      db.surahSha256(1),
      surahDigest([utf8.encode('Synthetic ayah')], basmala: const []),
    );
    expect(
      db.surahSha256(1),
      isNot(surahDigest([utf8.encode('Synthetic ayah')])),
    );
  });

  test('opens a path with spaces and URI characters', () async {
    final pack = await buildSyntheticPack(
      Directory('${root.path}/a b#c?d%20e'),
    );
    final db = open(pack);
    expect(db.ayahText(3, 1)!.verbatim, 'Synthetic last ayah');
  });

  group('read-only', () {
    late SyntheticPack pack;

    setUp(() async {
      pack = await buildSyntheticPack(root);
    });

    Future<void> readEverything() async {
      final db = PackDatabase.open(pack.textFile.path, formatVersion: 1);
      for (final surah in db.surahs()) {
        db
          ..basmala(surah.number)
          ..surahSha256(surah.number);
        for (var ayah = 1; ayah <= surah.ayahCount; ayah++) {
          db
            ..ayahText(surah.number, ayah)
            ..words(surah.number, ayah);
        }
      }
      db
        ..divisions()
        ..sajdas()
        ..rowCounts()
        ..close();
    }

    test('the file is unchanged and no sidecar file appears', () async {
      final hash = await fileSha256(pack.textFile);
      final modified = pack.textFile.lastModifiedSync();
      final names = pack.directory.listSync().map((e) => e.path).toSet();
      await readEverything();
      await readEverything();
      expect(await fileSha256(pack.textFile), hash);
      expect(pack.textFile.lastModifiedSync(), modified);
      expect(pack.directory.listSync().map((e) => e.path).toSet(), names);
      for (final suffix in ['-journal', '-wal', '-shm']) {
        expect(File('${pack.textFile.path}$suffix').existsSync(), isFalse);
      }
    });

    test('a hot journal next to the file is ignored and left as it is, '
        'which only immutable=1 does', () async {
      final journal = File('${pack.textFile.path}-journal');
      final bytes = Uint8List.fromList([
        for (var i = 0; i < 4096; i++) 1 + i % 255,
      ]);
      await journal.writeAsBytes(bytes);
      final hash = await fileSha256(pack.textFile);
      final names = pack.directory.listSync().map((e) => e.path).toSet();

      await readEverything();
      expect(await journal.readAsBytes(), bytes);
      expect(await fileSha256(pack.textFile), hash);
      expect(pack.directory.listSync().map((e) => e.path).toSet(), names);

      // The same journal stops a read-only connection that is not immutable,
      // so the reads above did not succeed by accident.
      final mutable = sqlite3.open(
        'file:${Uri.file(pack.textFile.path).path}?mode=ro',
        mode: OpenMode.readOnly,
        uri: true,
      );
      addTearDown(mutable.close);
      expect(
        () => mutable.select('SELECT count(*) FROM ayah'),
        throwsA(isA<SqliteException>()),
      );
      expect(await journal.readAsBytes(), bytes);
    });
  });
}
