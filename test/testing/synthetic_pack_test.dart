import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../testing/packs/raw_pack.dart';
import '../../testing/packs/synthetic_pack.dart';

// Self-test of the synthetic pack tooling against docs/CONTENT_PACKS.md.
// Every string is synthetic; non-ASCII characters are written as escapes so
// that no editor can normalise them.

final _hex = RegExp(r'^[0-9a-f]{64}$');
const _bom = [0xEF, 0xBB, 0xBF];

const _vectorBasmala = 'Synthetic opening line';
const _arabicVectorAyah =
    ' \u{646}\u{635} \u{62A}\u{62C}\u{631}\u{64A}\u{628}\u{64A}  ';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('synthetic_pack_test');
  });
  tearDown(() => root.delete(recursive: true));

  group('surah digest', () {
    List<List<int>> encode(List<String> ayat) => [
      for (final ayah in ayat) utf8.encode(ayah),
    ];

    test('frames each field as u32be(number), u32be(length), bytes', () {
      expect(
        digestFields([
          (0, [0x61]),
          (1, [0x62, 0x63]),
        ]),
        sha256.convert([
          ...[0, 0, 0, 0, 0, 0, 0, 1, 0x61],
          ...[0, 0, 0, 1, 0, 0, 0, 2, 0x62, 0x63],
        ]).toString(),
      );
    });

    test('numbers the basmala 0 and the ayat from 1', () {
      final ayat = encode(['x', 'y']);
      final basmala = utf8.encode('b');
      expect(
        surahDigest(ayat, basmala: basmala),
        digestFields([(0, basmala), (1, ayat[0]), (2, ayat[1])]),
      );
      expect(surahDigest(ayat), digestFields([(1, ayat[0]), (2, ayat[1])]));
    });

    // The documented vectors are reproduced only with a decomposed e-acute
    // (U+0065 U+0301) in the second ayah. docs/CONTENT_PACKS.md shows a
    // precomposed U+00E9 there, so its table and its input disagree; the
    // expected values below are the document's, unchanged.
    test('matches the documented test vectors', () {
      final ayat = encode([
        'Synthetic ayah one',
        'Synthetic e\u{301} two',
        _arabicVectorAyah,
      ]);
      expect(
        surahDigest(ayat, basmala: utf8.encode(_vectorBasmala)),
        '881415c778b801345a189d02c780cfc9d52a5f92e4390af1e176e02c12b73bb8',
      );
      expect(
        surahDigest(ayat),
        '1e0042fff89902b157ace9af9ce04a42b5059b3babd38e73e803480413d8051c',
      );
    });

    // Computed independently with Python's hashlib and struct for the input
    // as the document prints it, with a precomposed U+00E9.
    test('matches the vectors for a precomposed e-acute', () {
      final ayat = encode([
        'Synthetic ayah one',
        'Synthetic \u{E9} two',
        _arabicVectorAyah,
      ]);
      expect(
        surahDigest(ayat, basmala: utf8.encode(_vectorBasmala)),
        '3e93c75c683b8258ecc0e2698acd10f06c07c025ac7dada60a691f8e46edf177',
      );
      expect(
        surahDigest(ayat),
        '0b1fede8d41e15b1529f9a121f4a57a590759dd23159e12b707d840cc68816cb',
      );
    });

    test('word offsets count UTF-16 code units', () {
      const text = 'ab \u{1F600} cd';
      expect(text.indexOf('cd'), 6);
      expect(text.runes.toList().indexOf('c'.runes.single), 5);
      expect(const SyntheticAyah(text).spans, [(0, 2), (6, 8)]);
      expect(const SyntheticAyah(text).markSpans, [
        (afterWord: 1, start: 3, end: 5),
      ]);
    });
  });

  group('synthetic tokens', () {
    test(
      'a token with a Latin or Arabic letter is a word, any other a mark',
      () {
        const ayah = SyntheticAyah(
          '\u{6D6} ab \u{6D7} \u{646}\u{640} \u{640} \u{E9}1 2 ',
        );
        expect(ayah.spans, [(2, 4), (7, 9), (12, 14)]);
        expect(ayah.markSpans, [
          (afterWord: 0, start: 0, end: 1),
          (afterWord: 1, start: 5, end: 6),
          (afterWord: 2, start: 10, end: 11),
          (afterWord: 3, start: 15, end: 16),
        ]);
      },
    );

    test('given words come with no marks unless the marks are given', () {
      const words = [(0, 1)];
      expect(const SyntheticAyah('a \u{6D6}', words: words).markSpans, isEmpty);
      const marks = [(afterWord: 1, start: 2, end: 3)];
      expect(
        const SyntheticAyah('a \u{6D6}', words: words, marks: marks).markSpans,
        marks,
      );
      expect(const SyntheticAyah('a \u{6D6}', marks: []).spans, words);
    });
  });

  group('default pack', () {
    late SyntheticPack pack;
    late RawPack raw;

    setUp(() async {
      pack = await buildSyntheticPack(root);
      raw = RawPack.open(pack.textFile);
    });
    tearDown(() => raw.close());

    test('lies at <root>/<id>/<version> with exactly its two files', () async {
      expect(pack.directory.path, '${root.path}/synthetic-text/1');
      expect(await _names(pack.directory), [manifestFileName, textFileName]);
    });

    test('has the header the format requires', () async {
      final header = await RawHeader.read(pack.textFile);
      expect(header.hasMagic, isTrue);
      expect((header.writeVersion, header.readVersion), (1, 1));
      expect(header.textEncoding, 1);
      expect(header.applicationId, hqpkApplicationId);
      expect(header.userVersion, packFormatVersion);
      expect(header.freelistPages, 0, reason: 'the build ends with VACUUM');
    });

    test('reports the same values through its pragmas', () {
      expect(raw.applicationId, hqpkApplicationId);
      expect(raw.userVersion, packFormatVersion);
      expect(raw.encoding, 'UTF-8');
    });

    test('has the six tables of the spec, all STRICT', () {
      final tables = raw.tables();
      expect(tables.map((t) => t.name), [
        'ayah',
        'division',
        'mark',
        'sajda',
        'surah',
        'word',
      ]);
      expect(tables.every((t) => t.strict), isTrue);
      expect(
        {for (final t in tables) t.name: t.withoutRowid},
        {
          'ayah': true,
          'division': true,
          'mark': true,
          'sajda': true,
          'surah': false,
          'word': true,
        },
      );
    });

    test('has the columns, keys and checks of the spec', () {
      const expected = {
        'surah': [
          'number INTEGER pk1',
          'name TEXT NOT NULL',
          'ayah_count INTEGER NOT NULL',
          'revelation_place TEXT',
          'revelation_order INTEGER',
          'basmala TEXT',
        ],
        'ayah': [
          'surah INTEGER NOT NULL pk1',
          'number INTEGER NOT NULL pk2',
          'text TEXT NOT NULL',
        ],
        'word': [
          'surah INTEGER NOT NULL pk1',
          'ayah INTEGER NOT NULL pk2',
          'number INTEGER NOT NULL pk3',
          'start_offset INTEGER NOT NULL',
          'end_offset INTEGER NOT NULL',
        ],
        'mark': [
          'surah INTEGER NOT NULL pk1',
          'ayah INTEGER NOT NULL pk2',
          'number INTEGER NOT NULL pk3',
          'after_word INTEGER NOT NULL',
          'start_offset INTEGER NOT NULL',
          'end_offset INTEGER NOT NULL',
        ],
        'division': [
          'kind TEXT NOT NULL pk1',
          'number INTEGER NOT NULL pk2',
          'surah INTEGER NOT NULL',
          'ayah INTEGER NOT NULL',
        ],
        'sajda': ['surah INTEGER NOT NULL pk1', 'ayah INTEGER NOT NULL pk2'],
      };
      for (final MapEntry(key: table, value: columns) in expected.entries) {
        expect(raw.columns(table).map((c) => '$c'), columns, reason: table);
      }
      expect(
        raw.tableSql('surah'),
        contains("CHECK (revelation_place IN ('makki','madani'))"),
      );
      expect(
        raw.tableSql('division'),
        contains("CHECK (kind IN ('juz','hizb','rub','page'))"),
      );
      expect(raw.foreignKeys('surah'), isEmpty);
      expect(raw.foreignKeys('ayah'), {('ayah', 'surah')});
      for (final table in ['word', 'mark', 'division', 'sajda']) {
        expect(raw.foreignKeys(table), {(table, 'ayah')});
      }
    });

    test('passes integrity_check with no dangling reference', () {
      expect(raw.integrityCheck(), ['ok']);
      expect(raw.foreignKeyViolations(), 0);
    });

    test('stores text as TEXT values', () {
      expect(raw.storageClasses('ayah', 'text'), {'text'});
      expect(raw.storageClasses('surah', 'name'), {'text'});
      expect(raw.storageClasses('surah', 'basmala'), {'text', 'null'});
    });

    test('stores every surah and ayah byte for byte', () {
      final surahs = raw.surahs();
      expect(surahs.map((s) => s.number), [1, 2, 3]);
      for (var s = 0; s < pack.surahs.length; s++) {
        final given = pack.surahs[s];
        final row = surahs[s];
        expect(row.name, utf8.encode(given.name));
        expect(row.ayahCount, given.ayat.length);
        expect(row.revelationPlace, given.revelationPlace);
        expect(row.revelationOrder, given.revelationOrder);
        expect(
          row.basmala,
          given.basmala == null ? isNull : utf8.encode(given.basmala!),
        );
        final ayat = raw.ayat(row.number);
        expect(ayat.map((a) => a.$1), [
          for (var a = 1; a <= given.ayat.length; a++) a,
        ]);
        for (var a = 0; a < ayat.length; a++) {
          expect(
            ayat[a].$2,
            utf8.encode(given.ayat[a].text),
            reason: '${row.number}:${a + 1}',
          );
        }
      }
    });

    test('stores word spans that are ordered, in bounds and numbered', () {
      for (var s = 0; s < pack.surahs.length; s++) {
        final ayat = pack.surahs[s].ayat;
        for (var a = 0; a < ayat.length; a++) {
          final spans = ayat[a].spans;
          expect(raw.words(s + 1, a + 1), [
            for (var w = 0; w < spans.length; w++)
              (w + 1, spans[w].$1, spans[w].$2),
          ]);
          var end = 0;
          for (final (start, stop) in spans) {
            expect(start, greaterThanOrEqualTo(end));
            expect(stop, greaterThan(start));
            end = stop;
          }
          expect(end, lessThanOrEqualTo(ayat[a].text.length));
        }
      }
      expect(raw.words(2, 2).last, (2, 6, 8), reason: "'cd' after U+1F600");
      expect(raw.words(2, 3), [
        (1, 0, 14),
        (2, 15, 21),
      ], reason: 'a hyphen inside a token joins one word');
    });

    test('leaves only U+0020 outside its words and marks', () {
      for (final surah in pack.surahs) {
        for (final ayah in surah.ayat) {
          final covered = List.filled(ayah.text.length, false);
          for (final (start, end) in [
            ...ayah.spans,
            for (final mark in ayah.markSpans) (mark.start, mark.end),
          ]) {
            covered.fillRange(start, end, true);
          }
          for (final (offset, unit) in ayah.text.codeUnits.indexed) {
            if (!covered[offset]) expect(unit, 0x20, reason: '$offset');
          }
        }
      }
    });

    test('stores marks outside every word, each after the word before', () {
      for (var s = 0; s < pack.surahs.length; s++) {
        final ayat = pack.surahs[s].ayat;
        for (var a = 0; a < ayat.length; a++) {
          final marks = ayat[a].markSpans;
          expect(raw.marks(s + 1, a + 1), [
            for (var m = 0; m < marks.length; m++)
              (m + 1, marks[m].afterWord, marks[m].start, marks[m].end),
          ]);
          final words = raw.words(s + 1, a + 1);
          var end = 0;
          for (final (_, afterWord, start, stop) in raw.marks(s + 1, a + 1)) {
            expect(start, greaterThanOrEqualTo(end));
            expect(stop, greaterThan(start));
            expect(stop, lessThanOrEqualTo(ayat[a].text.length));
            for (final (_, wordStart, wordEnd) in words) {
              expect(stop <= wordStart || start >= wordEnd, isTrue);
            }
            expect(
              afterWord,
              words.where((w) => w.$3 <= start).length,
              reason: '${s + 1}:${a + 1}',
            );
            end = stop;
          }
        }
      }
      expect(raw.marks(1, 2), [(1, 2, 12, 13), (2, 3, 18, 19), (3, 3, 20, 21)]);
      expect(raw.marks(1, 3), [(1, 0, 0, 1)]);
      expect(raw.marks(2, 2), [(1, 1, 3, 5)], reason: 'U+1F600 alone');
    });

    test('stores the divisions and sajdas given', () {
      expect(raw.divisions(), [
        for (final kind in ['hizb', 'juz', 'page', 'rub'])
          for (final d in pack.divisions.where((d) => d.kind == kind))
            (d.kind, d.number, d.surah, d.ayah),
      ]);
      expect(raw.sajdas(), pack.sajdas);
    });

    test('draws on text that any normalising or trimming would change', () {
      final texts = [
        for (final surah in pack.surahs)
          for (final ayah in surah.ayat) ayah.text,
      ];
      expect(texts.any((t) => t.contains('\u{E9}')), isTrue);
      expect(texts.any((t) => t.contains('e\u{301}')), isTrue);
      expect(texts.any((t) => t.startsWith(' ')), isTrue);
      expect(texts.any((t) => t.endsWith(' ')), isTrue);
      expect(texts.any((t) => t.contains('  ')), isTrue);
      expect(texts.any((t) => t.runes.any((r) => r > 0xFFFF)), isTrue);
      expect(texts.any((t) => t.contains(_arabicVectorAyah.trim())), isTrue);
      expect(pack.surahs.any((s) => s.basmala != null), isTrue);
      expect(pack.surahs.any((s) => s.basmala == null), isTrue);
    });

    test('has marks before, between and after words, one outside the BMP', () {
      final ayat = [for (final surah in pack.surahs) ...surah.ayat];
      final marks = [for (final ayah in ayat) ...ayah.markSpans];
      expect(marks.any((m) => m.afterWord == 0), isTrue);
      expect(
        ayat.any(
          (a) => a.markSpans.any(
            (m) => m.afterWord > 0 && m.afterWord < a.spans.length,
          ),
        ),
        isTrue,
      );
      expect(
        ayat.any(
          (a) =>
              a.markSpans.where((m) => m.afterWord == a.spans.length).length >
              1,
        ),
        isTrue,
      );
      expect(
        ayat.any(
          (a) => a.markSpans.any(
            (m) => a.text.substring(m.start, m.end).runes.single > 0xFFFF,
          ),
        ),
        isTrue,
      );
    });

    test('writes a UTF-8 manifest without BOM that equals the map', () async {
      final bytes = await pack.manifestFile.readAsBytes();
      expect(bytes.take(3), isNot(_bom));
      expect(jsonDecode(utf8.decode(bytes)), pack.manifest);
    });

    test('has every manifest field of the spec, and no other', () {
      final m = pack.manifest;
      expect(m.keys, [
        'format',
        'format_version',
        'id',
        'kind',
        'version',
        'changelog',
        'riwaya',
        'edition',
        'font',
        'sources',
        'files',
        'surah_sha256',
        'counts',
        'reviews',
      ]);
      expect(m['format'], 'holyquran-pack');
      expect(m['format_version'], packFormatVersion);
      expect(m['kind'], 'text');
      expect(m['id'], 'synthetic-text');
      expect(m['version'], 1);
      expect(_keys(m['changelog'], 0), ['version', 'date', 'summary']);
      expect(_keys(m['reviews'], 0), ['reviewer', 'date', 'scope']);
      final sources = m['sources']! as List<Object?>;
      expect(
        [for (final s in sources) (s! as Map)['role']],
        ['text', 'edition_map'],
      );
      for (var i = 0; i < sources.length; i++) {
        final source = sources[i]! as Map<String, Object?>;
        expect(_keys(sources, i), [
          'role',
          'registry_row',
          'name',
          'publisher',
          'url',
          'version',
          'fetched_on',
          'file_sha256',
          'trust_grade',
          'options',
          'licence',
        ]);
        expect(source['file_sha256'], matches(_hex));
        expect(['A', 'B', 'C'], contains(source['trust_grade']));
        expect((source['licence']! as Map).keys, [
          'text',
          'permission_ref',
          'notice',
          'allows_export',
        ]);
      }
      final options = (sources[0]! as Map)['options']! as Map;
      expect(options, isNotEmpty);
      expect(
        options.values.every((v) => v is String || v is num || v is bool),
        isTrue,
      );
      expect(options.values.map((v) => v.runtimeType).toSet(), hasLength(3));
      expect((sources[1]! as Map)['options'], isNull);
    });

    test('lists the text file with its size and hash', () async {
      final files = pack.manifest['files']! as List<Object?>;
      expect(files, hasLength(1));
      expect(files.single, {
        'name': textFileName,
        'sha256': await fileSha256(pack.textFile),
        'bytes': await pack.textFile.length(),
      });
    });

    test('carries the surah digests of the stored bytes', () {
      final digests = pack.manifest['surah_sha256']! as Map<String, Object?>;
      expect(digests.keys, ['1', '2', '3']);
      for (final MapEntry(:key, :value) in digests.entries) {
        expect(value, matches(_hex));
        expect(value, raw.surahDigestOf(int.parse(key)), reason: key);
      }
      expect(digests, pack.surahSha256);
    });

    test('carries the counts of the stored rows', () {
      final stored = {
        'surahs': raw.count('surah'),
        'ayat': raw.count('ayah'),
        'words': raw.count('word'),
        'marks': raw.count('mark'),
        'divisions': raw.divisionCounts(),
        'sajdas': raw.count('sajda'),
      };
      expect(pack.manifest['counts'], stored);
      expect(pack.counts, stored);
    });

    test('names the pinned Amiri Quran font by its hash', () async {
      expect(pack.manifest['font'], {
        'family': 'Amiri Quran',
        'version': '1.003',
        'sha256': await fileSha256(File(amiriQuranFontPath)),
      });
    });

    test('is reproducible byte for byte', () async {
      final again = await buildSyntheticPack(
        await Directory('${root.path}/again').create(),
      );
      expect(
        await again.textFile.readAsBytes(),
        await pack.textFile.readAsBytes(),
      );
      expect(
        await again.manifestFile.readAsBytes(),
        await pack.manifestFile.readAsBytes(),
      );
    });
  });

  group('fault', () {
    late SyntheticPack clean;

    setUp(() async {
      clean = await buildSyntheticPack(
        await Directory('${root.path}/clean').create(),
      );
    });

    Future<SyntheticPack> build(SyntheticFault fault) async =>
        buildSyntheticPack(
          await Directory('${root.path}/faulty').create(),
          fault: fault,
        );

    Future<void> expectSameFile(SyntheticPack faulty) async => expect(
      await faulty.textFile.readAsBytes(),
      await clean.textFile.readAsBytes(),
    );

    /// Every text, word and mark of [raw] is that of the clean pack, except
    /// the marks of ayah [surah]:[ayah].
    void expectOnlyAyahChanged(RawPack raw, int surah, int ayah) {
      for (final s in raw.surahs()) {
        for (final (number, bytes) in raw.ayat(s.number)) {
          expect(
            bytes,
            utf8.encode(clean.surahs[s.number - 1].ayat[number - 1].text),
          );
          expect(
            raw.words(s.number, number),
            _rawWords(clean, s.number, number),
          );
          if (s.number != surah || number != ayah) {
            expect(
              raw.marks(s.number, number),
              _rawMarks(clean, s.number, number),
            );
          }
        }
      }
    }

    Future<void> expectListedHashIsTrue(SyntheticPack faulty) async {
      final file = _files(faulty.manifest);
      expect(file['sha256'], await fileSha256(faulty.textFile));
      expect(file['bytes'], await faulty.textFile.length());
    }

    final checks = <SyntheticFault, Future<void> Function(SyntheticFault)>{
      SyntheticFault.flippedByte: (fault) async {
        final faulty = await build(fault);
        final before = await clean.textFile.readAsBytes();
        final after = await faulty.textFile.readAsBytes();
        expect(after.length, before.length);
        final changed = [
          for (var i = 0; i < after.length; i++)
            if (after[i] != before[i]) i,
        ];
        expect(changed, hasLength(1));
        expect(changed.single, greaterThanOrEqualTo(100));
        expect(_diff(faulty.manifest, clean.manifest), isEmpty);
        expect(
          await fileSha256(faulty.textFile),
          isNot(_files(faulty.manifest)['sha256']),
        );
        final raw = RawPack.open(faulty.textFile);
        addTearDown(raw.close);
        expect(
          raw.ayat(1).first.$2,
          isNot(utf8.encode(clean.surahs[0].ayat[0].text)),
        );
        expect(raw.ayat(1).skip(1).map((a) => a.$2), [
          for (final ayah in clean.surahs[0].ayat.skip(1))
            utf8.encode(ayah.text),
        ]);
      },
      SyntheticFault.wrongSurahHash: (fault) async {
        final faulty = await build(fault);
        await expectSameFile(faulty);
        expect(_diff(faulty.manifest, clean.manifest), ['surah_sha256/1']);
        final listed = (faulty.manifest['surah_sha256']! as Map)['1'];
        expect(listed, matches(_hex));
        expect(listed, isNot(faulty.surahSha256['1']));
      },
      SyntheticFault.wrongCounts: (fault) async {
        final faulty = await build(fault);
        await expectSameFile(faulty);
        expect(_diff(faulty.manifest, clean.manifest), ['counts/ayat']);
        expect(
          (faulty.manifest['counts']! as Map)['ayat'],
          (clean.counts['ayat']! as int) + 1,
        );
      },
      SyntheticFault.leadingBom: (fault) async {
        final faulty = await build(fault);
        await expectListedHashIsTrue(faulty);
        final raw = RawPack.open(faulty.textFile);
        addTearDown(raw.close);
        final cleanText = utf8.encode(clean.surahs[0].ayat[0].text);
        final first = raw.ayat(1).first.$2;
        expect(first, [..._bom, ...cleanText]);
        // Why the rule exists: Dart's decoder drops the mark silently.
        expect(utf8.decode(first), clean.surahs[0].ayat[0].text);
        expect(raw.words(1, 1), [
          for (final (n, start, end) in _rawWords(clean, 1, 1))
            (n, start + 1, end + 1),
        ]);
        final digests = faulty.manifest['surah_sha256']! as Map;
        expect(digests['1'], raw.surahDigestOf(1));
        final others = [
          for (final s in raw.surahs()) ...[
            ?s.basmala,
            for (final (number, bytes) in raw.ayat(s.number))
              if (s.number != 1 || number != 1) bytes,
          ],
        ];
        expect(others.where((b) => _startsWith(b, _bom)), isEmpty);
        final diff = _diff(faulty.manifest, clean.manifest);
        expect(diff, containsAll(['files/0/sha256', 'surah_sha256/1']));
        expect({
          'files/0/sha256',
          'files/0/bytes',
          'surah_sha256/1',
        }, containsAll(diff));
      },
      SyntheticFault.walHeader: (fault) async {
        final faulty = await build(fault);
        await expectListedHashIsTrue(faulty);
        final header = await RawHeader.read(faulty.textFile);
        expect((header.writeVersion, header.readVersion), (2, 2));
        expect(header.applicationId, hqpkApplicationId);
        expect(header.userVersion, packFormatVersion);
        expect(await _names(faulty.directory), [
          manifestFileName,
          textFileName,
        ]);
        expect({
          'files/0/sha256',
          'files/0/bytes',
        }, containsAll(_diff(faulty.manifest, clean.manifest)));
      },
      SyntheticFault.wrongApplicationId: (fault) async {
        final faulty = await build(fault);
        await expectListedHashIsTrue(faulty);
        final header = await RawHeader.read(faulty.textFile);
        expect(header.applicationId, isNot(hqpkApplicationId));
        expect(header.userVersion, packFormatVersion);
        expect((header.writeVersion, header.readVersion), (1, 1));
        final raw = RawPack.open(faulty.textFile);
        addTearDown(raw.close);
        expect(raw.applicationId, header.applicationId);
        expect(_diff(faulty.manifest, clean.manifest), ['files/0/sha256']);
      },
      SyntheticFault.wrongUserVersion: (fault) async {
        final faulty = await build(fault);
        await expectListedHashIsTrue(faulty);
        final header = await RawHeader.read(faulty.textFile);
        expect(header.userVersion, isNot(packFormatVersion));
        expect(header.applicationId, hqpkApplicationId);
        expect((header.writeVersion, header.readVersion), (1, 1));
        final raw = RawPack.open(faulty.textFile);
        addTearDown(raw.close);
        expect(raw.userVersion, header.userVersion);
        expect(faulty.manifest['format_version'], packFormatVersion);
        expect(_diff(faulty.manifest, clean.manifest), ['files/0/sha256']);
      },
      SyntheticFault.unsupportedFormatVersion: (fault) async {
        final faulty = await build(fault);
        await expectSameFile(faulty);
        expect(_diff(faulty.manifest, clean.manifest), ['format_version']);
        expect(faulty.manifest['format_version'], isNot(packFormatVersion));
      },
      SyntheticFault.pathInFileName: (fault) async {
        final faulty = await build(fault);
        await expectSameFile(faulty);
        expect(_diff(faulty.manifest, clean.manifest), ['files/0/name']);
        expect(_files(faulty.manifest)['name'], '../text.sqlite');
        expect(
          File('${faulty.directory.parent.path}/$textFileName').existsSync(),
          isFalse,
        );
      },
      SyntheticFault.missingFile: (fault) async {
        final faulty = await build(fault);
        expect(await _names(faulty.directory), [manifestFileName]);
        expect(_diff(faulty.manifest, clean.manifest), isEmpty);
      },
      SyntheticFault.wrongFileSize: (fault) async {
        final faulty = await build(fault);
        await expectSameFile(faulty);
        expect(_diff(faulty.manifest, clean.manifest), ['files/0/bytes']);
        final file = _files(faulty.manifest);
        expect(file['bytes'], (await faulty.textFile.length()) + 1);
        expect(file['sha256'], await fileSha256(faulty.textFile));
      },
      SyntheticFault.overlappingSpans: (fault) async {
        final faulty = await build(fault);
        await expectListedHashIsTrue(faulty);
        final raw = RawPack.open(faulty.textFile);
        addTearDown(raw.close);
        final [(_, _, firstEnd), ...] = _rawWords(clean, 1, 1);
        expect(raw.words(1, 1), [
          for (final (n, start, end) in _rawWords(clean, 1, 1))
            (n, n == 2 ? firstEnd - 1 : start, end),
        ]);
        for (final s in raw.surahs()) {
          for (final (number, bytes) in raw.ayat(s.number)) {
            expect(
              bytes,
              utf8.encode(clean.surahs[s.number - 1].ayat[number - 1].text),
            );
            if (s.number != 1 || number != 1) {
              expect(
                raw.words(s.number, number),
                _rawWords(clean, s.number, number),
              );
            }
          }
        }
        expect({
          'files/0/sha256',
          'files/0/bytes',
        }, containsAll(_diff(faulty.manifest, clean.manifest)));
      },
      SyntheticFault.nonStrictSchema: (fault) async {
        final faulty = await build(fault);
        await expectListedHashIsTrue(faulty);
        final raw = RawPack.open(faulty.textFile);
        addTearDown(raw.close);
        expect(
          {for (final t in raw.tables()) t.name: t.strict},
          {
            'ayah': true,
            'division': true,
            'mark': true,
            'sajda': false,
            'surah': true,
            'word': true,
          },
        );
        expect(
          raw.tables().every((t) => t.withoutRowid == (t.name != 'surah')),
          isTrue,
        );
        expect(raw.sajdas(), clean.sajdas);
        expect({
          'files/0/sha256',
          'files/0/bytes',
        }, containsAll(_diff(faulty.manifest, clean.manifest)));
      },
      SyntheticFault.markOverlapsWord: (fault) async {
        final faulty = await build(fault);
        await expectListedHashIsTrue(faulty);
        final raw = RawPack.open(faulty.textFile);
        addTearDown(raw.close);
        final (_, _, wordEnd) = _rawWords(clean, 1, 2)[1];
        expect(raw.marks(1, 2), [
          for (final (n, afterWord, start, end) in _rawMarks(clean, 1, 2))
            (n, afterWord, n == 1 ? wordEnd - 1 : start, end),
        ]);
        expectOnlyAyahChanged(raw, 1, 2);
        expect({
          'files/0/sha256',
          'files/0/bytes',
        }, containsAll(_diff(faulty.manifest, clean.manifest)));
      },
      SyntheticFault.wrongAfterWord: (fault) async {
        final faulty = await build(fault);
        await expectListedHashIsTrue(faulty);
        final raw = RawPack.open(faulty.textFile);
        addTearDown(raw.close);
        expect(raw.marks(1, 2), [
          for (final (n, afterWord, start, end) in _rawMarks(clean, 1, 2))
            (n, n == 1 ? afterWord + 1 : afterWord, start, end),
        ]);
        expectOnlyAyahChanged(raw, 1, 2);
        expect({
          'files/0/sha256',
          'files/0/bytes',
        }, containsAll(_diff(faulty.manifest, clean.manifest)));
      },
      SyntheticFault.wrongMarkCount: (fault) async {
        final faulty = await build(fault);
        await expectSameFile(faulty);
        expect(_diff(faulty.manifest, clean.manifest), ['counts/marks']);
        expect(
          (faulty.manifest['counts']! as Map)['marks'],
          (clean.counts['marks']! as int) + 1,
        );
      },
    };

    test('every fault has a check', () {
      expect(checks.keys.toSet(), SyntheticFault.values.toSet());
    });

    for (final MapEntry(key: fault, value: check) in checks.entries) {
      test('${fault.name} produces exactly its defect', () async {
        await check(fault);
      });
    }
  });
}

Future<List<String>> _names(Directory directory) async {
  final names = [
    await for (final entity in directory.list())
      entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
  ]..sort();
  return names;
}

List<Object?> _keys(Object? list, int index) =>
    ((list! as List<Object?>)[index]! as Map).keys.toList();

Map<String, Object?> _files(Map<String, Object?> manifest) =>
    (manifest['files']! as List<Object?>).single! as Map<String, Object?>;

List<(int, int, int)> _rawWords(SyntheticPack pack, int surah, int ayah) {
  final raw = RawPack.open(pack.textFile);
  try {
    return raw.words(surah, ayah);
  } finally {
    raw.close();
  }
}

List<(int, int, int, int)> _rawMarks(SyntheticPack pack, int surah, int ayah) {
  final raw = RawPack.open(pack.textFile);
  try {
    return raw.marks(surah, ayah);
  } finally {
    raw.close();
  }
}

bool _startsWith(List<int> bytes, List<int> prefix) =>
    bytes.length >= prefix.length &&
    [
      for (var i = 0; i < prefix.length; i++) bytes[i] == prefix[i],
    ].every((same) => same);

/// The JSON paths at which [a] and [b] differ.
List<String> _diff(Object? a, Object? b, [String at = '']) {
  String path(Object key) => at.isEmpty ? '$key' : '$at/$key';
  if (a is Map && b is Map) {
    return [
      for (final key in {...a.keys, ...b.keys})
        ..._diff(a[key], b[key], path(key as Object)),
    ];
  }
  if (a is List && b is List && a.length == b.length) {
    return [for (var i = 0; i < a.length; i++) ..._diff(a[i], b[i], path(i))];
  }
  return a == b ? const [] : [at];
}
