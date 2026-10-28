import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/services/pack_database.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/quran_address.dart';
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
      expect(db.words(2, 2).last, (number: 2, start: 6, end: 8));
      expect(db.words(1, 9), isEmpty);
    });

    test('marks as stored, with the word each follows', () {
      final stored = raw(pack);
      for (final (s, surah) in pack.surahs.indexed) {
        for (final (a, ayah) in surah.ayat.indexed) {
          expect(db.marks(s + 1, a + 1), [
            for (final (n, afterWord, start, end) in stored.marks(s + 1, a + 1))
              (number: n, afterWord: afterWord, start: start, end: end),
          ]);
          expect(db.marks(s + 1, a + 1), [
            for (final (index, mark) in ayah.markSpans.indexed)
              (
                number: index + 1,
                afterWord: mark.afterWord,
                start: mark.start,
                end: mark.end,
              ),
          ]);
        }
      }
      expect(db.marks(1, 2).map((m) => m.afterWord), [2, 3, 3]);
      expect(db.marks(1, 3), [(number: 1, afterWord: 0, start: 0, end: 1)]);
      expect(db.marks(2, 2), [(number: 1, afterWord: 1, start: 3, end: 5)]);
      expect(db.marks(1, 1), isEmpty);
      expect(db.marks(1, 9), isEmpty);
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
      expect(counts.marks, pack.counts['marks']);
      expect(counts.marks, 5);
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

    const markColumns =
        'surah INTEGER NOT NULL, ayah INTEGER NOT NULL, '
        'number INTEGER NOT NULL, after_word INTEGER NOT NULL, '
        'start_offset INTEGER NOT NULL, end_offset INTEGER NOT NULL';
    const markKey = 'PRIMARY KEY (surah, ayah, number)';
    const markVariants = {
      'a mark table that is missing': null,
      'a mark table that has a rowid': '($markColumns, $markKey) STRICT',
      'a mark table whose after_word may be null':
          '(surah INTEGER NOT NULL, ayah INTEGER NOT NULL, '
          'number INTEGER NOT NULL, after_word INTEGER, '
          'start_offset INTEGER NOT NULL, end_offset INTEGER NOT NULL, '
          '$markKey) STRICT, WITHOUT ROWID',
      'a mark table with its offsets before after_word':
          '(surah INTEGER NOT NULL, ayah INTEGER NOT NULL, '
          'number INTEGER NOT NULL, start_offset INTEGER NOT NULL, '
          'end_offset INTEGER NOT NULL, after_word INTEGER NOT NULL, '
          '$markKey) STRICT, WITHOUT ROWID',
      'a mark table keyed without its number':
          '($markColumns, PRIMARY KEY (surah, ayah, after_word)) '
          'STRICT, WITHOUT ROWID',
    };
    for (final MapEntry(key: name, value: definition) in markVariants.entries) {
      test(name, () async {
        expectRefused(
          await changed([
            'DROP TABLE mark',
            if (definition != null) 'CREATE TABLE mark $definition',
          ]),
        );
      });
    }

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
        'DROP TABLE mark',
        'CREATE TABLE mark ($markColumns, $markKey) STRICT, WITHOUT ROWID',
      ]);
      final db = open(pack);
      expect(db.sajdas(), isEmpty);
      expect(db.divisions(), isEmpty);
      expect(db.marks(1, 2), isEmpty);
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
    // Windows forbids `?` in a file name; `&` stands in for it there.
    final name = Platform.isWindows ? 'a b#c&d%20e' : 'a b#c?d%20e';
    final pack = await buildSyntheticPack(Directory('${root.path}/$name'));
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
            ..words(surah.number, ayah)
            ..marks(surah.number, ayah);
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

  group('format 2', () {
    late SyntheticPack pack;

    setUp(() async {
      pack = await buildSyntheticPack(root, formatVersion: 2);
    });

    PackDatabase openV2(SyntheticPack pack) {
      final db = PackDatabase.open(pack.textFile.path, formatVersion: 2);
      addTearDown(db.close);
      return db;
    }

    test('opens, and reads the v1 tables as before', () {
      final db = openV2(pack);
      expect(db.surahs().map((s) => s.number), [1, 2, 3]);
      expect(db.ayahText(1, 1)!.verbatim, pack.surahs[0].ayat[0].text);
      expect(db.surahSha256(1), pack.surahSha256['1']);
    });

    test('reads every search form as its stored bytes, by ayah, word and '
        'kind', () {
      final db = openV2(pack);
      final stored = raw(pack).searchForms();
      expect(stored, hasLength(pack.searchForms.length));
      final read = [
        for (var surah = 1; surah <= 3; surah++)
          ...db.searchForms(surah, riwaya: 'hafs'),
      ];
      expect(read, hasLength(stored.length));
      for (final (index, form) in read.indexed) {
        final (surah, ayah, word, kind, bytes) = stored[index];
        final synthetic = pack.searchForms[index];
        expect(form.word, QuranAddress('hafs', surah, ayah, word));
        expect(form.kind, kind);
        expect(utf8.encode(form.form.verbatim), bytes);
        expect(form.form.verbatim, synthetic.form);
        expect(
          (synthetic.surah, synthetic.ayah, synthetic.word),
          (surah, ayah, word),
        );
      }
      expect(
        read.first.form.verbatim,
        ' e\u{301} \u{E9} \u{646}\u{635} '
        '\u{62A}\u{62C}\u{631}\u{64A}\u{628}\u{64A}  ',
      );
      expect(db.searchForms(4, riwaya: 'hafs'), isEmpty);
    });

    test('counts the search forms of each kind', () {
      final words = pack.counts['words']! as int;
      expect(openV2(pack).searchFormCounts(), {
        for (final kind in defaultSyntheticSearchFormKinds) kind: words,
      });
    });

    test('a format 1 pack has no search forms', () async {
      final v1 = open(await buildSyntheticPack(Directory('${root.path}/v1')));
      expect(v1.searchForms(1, riwaya: 'hafs'), isEmpty);
      expect(v1.searchFormCounts(), isEmpty);
    });

    test(
      'is refused when opened as format 1, and a v1 file as format 2',
      () async {
        expect(
          () => PackDatabase.open(pack.textFile.path, formatVersion: 1),
          throwsFailure<UnsupportedPackFormat>((f) => f.formatVersion, 2),
        );
        final v1 = await buildSyntheticPack(Directory('${root.path}/v1'));
        expect(
          () => PackDatabase.open(v1.textFile.path, formatVersion: 2),
          throwsFailure<UnsupportedPackFormat>((f) => f.formatVersion, 1),
        );
      },
    );

    test('a format version no text pack has is refused', () {
      for (final version in [0, 3]) {
        expect(
          () => PackDatabase.open(pack.textFile.path, formatVersion: version),
          throwsFailure<UnsupportedPackFormat>((f) => f.formatVersion, version),
        );
      }
    });

    group('refuses a search_form table', () {
      const columns =
          'surah INTEGER NOT NULL, ayah INTEGER NOT NULL, '
          'word INTEGER NOT NULL, kind TEXT NOT NULL';
      const key = 'PRIMARY KEY (surah, ayah, word, kind)';
      const variants = {
        'that is missing': null,
        'whose form may be null':
            '($columns, form TEXT, $key) STRICT, WITHOUT ROWID',
        'keyed without its kind':
            '($columns, form TEXT NOT NULL, PRIMARY KEY (surah, ayah, word)) '
            'STRICT, WITHOUT ROWID',
        'that has a rowid': '($columns, form TEXT NOT NULL, $key) STRICT',
        'with an extra column':
            '($columns, form TEXT NOT NULL, note TEXT, $key) '
            'STRICT, WITHOUT ROWID',
      };
      for (final MapEntry(key: name, value: definition) in variants.entries) {
        test(name, () async {
          final writable = sqlite3.open(pack.textFile.path);
          try {
            writable.execute('DROP TABLE search_form');
            if (definition != null) {
              writable.execute('CREATE TABLE search_form $definition');
            }
          } finally {
            writable.close();
          }
          expect(
            () => PackDatabase.open(pack.textFile.path, formatVersion: 2),
            throwsFailure<UnsupportedPackFormat>((f) => f.formatVersion, 2),
          );
        });
      }
    });

    test(
      'a search form with a leading U+FEFF or malformed UTF-8 is refused',
      () async {
        for (final (index, bytes) in [
          [0xEF, 0xBB, 0xBF, 0x61],
          [0x61, 0xC3],
        ].indexed) {
          final changed = await buildSyntheticPack(
            Directory('${root.path}/encoding$index'),
            formatVersion: 2,
          );
          final writable = sqlite3.open(changed.textFile.path);
          try {
            writable.execute(
              'UPDATE search_form SET form = CAST(? AS TEXT) '
              'WHERE surah = 2 AND ayah = 1 AND word = 2',
              [Uint8List.fromList(bytes)],
            );
          } finally {
            writable.close();
          }
          expect(
            () => openV2(changed).searchForms(2, riwaya: 'hafs'),
            throwsFailure<TextEncodingRejected>((f) => (f.surah, f.ayah), (
              2,
              1,
            )),
            reason: '$bytes',
          );
        }
      },
    );

    test('a search form kind that is not UTF-8 is refused', () async {
      final writable = sqlite3.open(pack.textFile.path);
      try {
        writable.execute(
          'UPDATE search_form SET kind = CAST(? AS TEXT) '
          "WHERE surah = 3 AND word = 1 AND kind = 'synthetic-plain'",
          [
            Uint8List.fromList([0x61, 0xC3]),
          ],
        );
      } finally {
        writable.close();
      }
      final db = openV2(pack);
      expect(db.searchForms(1, riwaya: 'hafs'), isNotEmpty);
      expect(
        () => db.searchForms(3, riwaya: 'hafs'),
        throwsFailure<UnsupportedPackFormat>((f) => f.pack, pack.textFile.path),
      );
    });

    test('a search form kind of another form is inconsistent', () async {
      final writable = sqlite3.open(pack.textFile.path);
      try {
        writable.execute(
          "UPDATE search_form SET kind = 'Not A ' || kind WHERE surah = 3",
        );
      } finally {
        writable.close();
      }
      final db = openV2(pack);
      expect(db.searchForms(1, riwaya: 'hafs'), isNotEmpty);
      expect(
        () => db.searchForms(3, riwaya: 'hafs'),
        throwsFailure<PackInconsistent>((f) => f.pack, pack.textFile.path),
      );
    });
  });
}
