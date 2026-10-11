import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';
import 'package:holyquran/domain/models/verified_pack.dart';
import 'package:holyquran/utils/result.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../test/integrity/pack_integrity_suite.dart';
import '../../../testing/packs/raw_pack.dart';
import '../../../testing/packs/synthetic_pack.dart' show amiriQuranFontPath;
import 'spike_pack_writer.dart';
import 'tanzil_fixture.dart';
import 'tanzil_xml.dart';

// Every value is synthetic; non-ASCII characters are written as escapes.

final _fontSha256 = sha256
    .convert(File(amiriQuranFontPath).readAsBytesSync())
    .toString();

SpikeSource _sourceOf(Uint8List bytes, TanzilXml xml) => (
  bytes: bytes,
  url: _url,
  version: tanzilUthmaniVersion,
  fetchedOn: '2026-01-01',
  notice: xml.notice,
);

const _url =
    'https://example.invalid/synthetic.xml?quranType=synthetic&marks=true'
    '&agree=true';

Future<String> _write(Directory root, Uint8List bytes) {
  final xml = readTanzilXml(bytes);
  return writeSpikePack(
    root,
    surahs: spikeSurahsOf(xml),
    fontSha256: _fontSha256,
    source: _sourceOf(bytes, xml),
  );
}

/// The marks sura, and enough ayat for several units of every synthetic
/// division.
List<FixtureSura> _longerSuras() => [
  ...syntheticFixtureSuras(),
  markFixtureSura(),
  for (final (n, count) in [(5, 230), (6, 9)])
    (
      name: 'Synthetic sura $n',
      bismillah: 'Synthetic opening $n',
      ayat: [for (var a = 1; a <= count; a++) 'Synthetic $n $a  x'],
    ),
];

void main() {
  late Directory root;
  final bytes = tanzilFixtureXml(_longerSuras());
  final written = Completer<String>();

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('spike_pack_writer');
    written.complete(_write(Directory('${root.path}/a'), bytes));
  });
  tearDownAll(() => root.delete(recursive: true));

  definePackIntegritySuite('the spike pack', () => written.future);

  test('passes LocalPackRepository.verify', () async {
    final verified = await const LocalPackRepository(
      files: PackFileService(),
      signatures: SignatureNotConfigured(),
    ).verify(await written.future);
    expect(verified, isA<Ok<VerifiedPack>>());
  });

  test('stores every value as the source bytes at its offset', () async {
    final xml = readTanzilXml(bytes);
    final raw = RawPack.open(File('${await written.future}/text.sqlite'));
    addTearDown(raw.close);
    List<int> at(int offset, String value) =>
        bytes.sublist(offset, offset + utf8.encode(value).length);
    for (final (s, sura) in xml.suras.indexed) {
      final stored = raw.surahs()[s];
      expect(stored.name, at(sura.nameByteOffset, sura.name));
      final ayat = xml.ayat.where((a) => a.surah == s + 1).toList();
      expect(stored.basmala, switch ((
        ayat.first.basmala,
        ayat.first.basmalaByteOffset,
      )) {
        (final String b, final int o) => at(o, b),
        _ => isNull,
      });
      expect(
        [
          for (final (number, stored) in raw.ayat(s + 1)) [number, ...stored],
        ],
        [
          for (final a in ayat) [a.ayah, ...at(a.byteOffset, a.text)],
        ],
      );
    }
  });

  test('stores the words and marks of every ayah, by D-083, in UTF-16 '
      'units', () async {
    final raw = RawPack.open(File('${await written.future}/text.sqlite'));
    addTearDown(raw.close);
    final explicit = {
      (2, 1): ([(1, 1, 10), (2, 12, 18), (3, 20, 26)], <StoredMark>[]),
      (2, 2): ([(1, 0, 2), (2, 6, 8)], [(1, 1, 3, 5)]),
      (4, 1): (
        [(1, 0, 9), (2, 12, 17), (3, 22, 25)],
        [(1, 1, 10, 11), (2, 2, 18, 19), (3, 2, 20, 21), (4, 3, 26, 27)],
      ),
      (4, 2): ([(1, 2, 5), (2, 6, 15)], [(1, 0, 0, 1)]),
      (4, 3): (
        [(1, 0, 9), (2, 19, 20), (3, 21, 26)],
        [(1, 1, 10, 12), (2, 1, 13, 15), (3, 1, 16, 18)],
      ),
    };
    for (final MapEntry(key: (surah, ayah), value: (words, marks))
        in explicit.entries) {
      expect(raw.words(surah, ayah), words, reason: '$surah:$ayah words');
      expect(raw.marks(surah, ayah), marks, reason: '$surah:$ayah marks');
    }
    final wordCounts = {
      (1, 1): 3,
      (1, 2): 3,
      (1, 3): 7,
      (1, 4): 3,
      (2, 3): 12,
      (3, 1): 2,
    };
    for (final MapEntry(key: (surah, ayah), value: count)
        in wordCounts.entries) {
      expect(raw.words(surah, ayah), hasLength(count), reason: '$surah:$ayah');
      expect(raw.marks(surah, ayah), isEmpty, reason: '$surah:$ayah');
    }
    for (final surah in [5, 6]) {
      for (final (ayah, _) in raw.ayat(surah)) {
        final digits = '$ayah'.length;
        expect(raw.words(surah, ayah), [
          (1, 0, 9),
          (2, 14 + digits, 15 + digits),
        ]);
        expect(raw.marks(surah, ayah), [
          (1, 1, 10, 11),
          (2, 1, 12, 12 + digits),
        ]);
      }
    }
  });

  test('sorts tokens into words and marks by general category L', () {
    expect(spikeSpansOf('  ').words, isEmpty);
    expect(spikeSpansOf('  ').marks, isEmpty);
    expect(spikeSpansOf('a').words, [(0, 1)]);
    expect(spikeSpansOf('\u0640').words, [(0, 1)], reason: 'U+0640 is Lm');
    expect(spikeSpansOf('\u06E5 \u06E6').words, [(0, 1), (2, 3)]);
    expect(spikeSpansOf('\u{1F600}').marks, [(afterWord: 0, start: 0, end: 2)]);
    expect(spikeSpansOf(' \u06D6  a \u06D6\u06D7 ').marks, [
      (afterWord: 0, start: 1, end: 2),
      (afterWord: 1, start: 6, end: 8),
    ]);
  });

  test('takes the options of a Tanzil URL, all but agree, as strings', () {
    expect(
      tanzilDownloadOptions(
        'https://tanzil.net/pub/download/index.php?quranType=uthmani'
        '&outType=xml&marks=true&sajdah=true&rub=false&agree=true',
      ),
      {
        'quranType': 'uthmani',
        'outType': 'xml',
        'marks': 'true',
        'sajdah': 'true',
        'rub': 'false',
      },
    );
    expect(tanzilDownloadOptions('https://example.invalid/a.xml'), isNull);
    expect(tanzilDownloadOptions('https://example.invalid/a.xml?'), isNull);
    expect(tanzilDownloadOptions('https://example.invalid/?agree=1'), isNull);
    expect(
      tanzilDownloadOptions('https://example.invalid/?a%20b=c+d%2Be&flag'),
      {'a b': 'c d+e', 'flag': ''},
    );
    for (final (url, reason) in [
      ('https://example.invalid/?a=1&a=2', 'repeats the query parameter a'),
      ('https://example.invalid/?agree=1&agree=1', 'parameter agree'),
      ('https://example.invalid/?a=1&=2', 'with no name'),
      ('https://example.invalid/?a=1&&b=2', 'with no name'),
    ]) {
      expect(
        () => tanzilDownloadOptions(url),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains(reason),
          ),
        ),
        reason: url,
      );
    }
  });

  test(
    'records the source, the notice verbatim and the spike caveats',
    () async {
      final manifest =
          jsonDecode(
                await File(
                  '${await written.future}/manifest.json',
                ).readAsString(),
              )
              as Map<String, Object?>;
      final source = (manifest['sources']! as List<Object?>).single! as Map;
      expect(source['file_sha256'], sha256.convert(bytes).toString());
      expect(source['registry_row'], 1);
      expect(source['role'], 'text');
      final licence = source['licence']! as Map;
      expect(
        utf8.encode(licence['notice']! as String),
        utf8.encode(fixtureNotice),
      );
      expect(licence['permission_ref'], contains('row 1'));
      final summary =
          ((manifest['changelog']! as List<Object?>).single! as Map)['summary']!
              as String;
      expect(
        summary,
        allOf(
          contains('U+0020'),
          contains('general category L (Lm included)'),
          contains('B0.4'),
          contains('synthetic'),
        ),
      );
      expect(source['options'], {'quranType': 'synthetic', 'marks': 'true'});
      final counts = manifest['counts']! as Map;
      // Suras 1 to 3, the marks sura, then two words and two digit marks
      // in each of the 239 ayat of suras 5 and 6.
      expect(counts['words'], 16 + 17 + 2 + 8 + 2 * 239);
      expect(counts['marks'], 1 + 8 + 2 * 239);
      expect(counts['sajdas'], 0);
      expect(counts['divisions'], {'juz': 2, 'hizb': 3, 'rub': 10, 'page': 25});
      expect(manifest['reviews'], isEmpty);
    },
  );

  test('gives the same bytes for the same input', () async {
    final again = await _write(Directory('${root.path}/b'), bytes);
    for (final file in ['text.sqlite', 'manifest.json']) {
      expect(
        await File('$again/$file').readAsBytes(),
        await File('${await written.future}/$file').readAsBytes(),
        reason: file,
      );
    }
  });

  test('never rewrites a version', () async {
    final target = Directory('${root.path}/c');
    await _write(target, bytes);
    await expectLater(_write(target, bytes), throwsStateError);
  });

  group('refuses, leaving nothing,', () {
    final xml = readTanzilXml(bytes);
    final surahs = spikeSurahsOf(xml);
    final first = surahs.first.ayat.first;

    /// The surahs with the first ayah replaced by [ayah].
    List<SpikeSurah> withFirstAyah(SpikeText ayah) => [
      (
        name: surahs.first.name,
        basmala: surahs.first.basmala,
        ayat: [ayah, ...surahs.first.ayat.skip(1)],
      ),
      ...surahs.skip(1),
    ];

    Future<void> expectRefused(
      String name,
      List<SpikeSurah> given,
      String reason, {
      SpikeSource? source,
    }) async {
      final target = Directory('${root.path}/refused $name');
      await expectLater(
        writeSpikePack(
          target,
          surahs: given,
          fontSha256: _fontSha256,
          source: source ?? _sourceOf(bytes, xml),
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'message', reason)),
      );
      expect(target.existsSync(), isFalse);
    }

    final range =
        '[${first.byteOffset}, ${first.byteOffset + first.byteLength})';

    test('a value at another offset', () async {
      await expectRefused(
        'shifted',
        withFirstAyah((
          value: first.value,
          byteOffset: first.byteOffset + 1,
          byteLength: first.byteLength,
        )),
        'ayah 1:1 is not the quoted source bytes '
            '[${first.byteOffset + 1}, ${first.byteOffset + 1 + first.byteLength})',
      );
    });

    test('a value truncated at its offset', () async {
      final short = first.value.substring(0, 5);
      await expectRefused(
        'truncated',
        withFirstAyah((
          value: short,
          byteOffset: first.byteOffset,
          byteLength: utf8.encode(short).length,
        )),
        'ayah 1:1 is not the quoted source bytes '
            '[${first.byteOffset}, ${first.byteOffset + 5})',
      );
      await expectRefused(
        'truncated, full length',
        withFirstAyah((
          value: short,
          byteOffset: first.byteOffset,
          byteLength: first.byteLength,
        )),
        'ayah 1:1 is not the quoted source bytes $range',
      );
    });

    test('a notice that does not name Tanzil and the version', () async {
      for (final (name, notice) in [
        ('no Tanzil', ' Synthetic notice, Version 1.1 '),
        ('no version', ' Synthetic Tanzil notice '),
        ('another version', ' Synthetic Tanzil notice, Version 1.10 '),
        ('a longer version', ' Synthetic Tanzil notice, Version 1.1.2 '),
      ]) {
        await expectRefused(
          name,
          surahs,
          'the notice does not name Tanzil and Version 1.1',
          source: (
            bytes: bytes,
            url: 'https://example.invalid/synthetic.xml',
            version: tanzilUthmaniVersion,
            fetchedOn: '2026-01-01',
            notice: notice,
          ),
        );
      }
    });

    test('an ayah holding a separator other than U+0020', () async {
      for (final (name, separator) in [
        ('U+00A0', '\u00A0'),
        ('U+2029', '\u2029'),
        ('U+3000', '\u3000'),
      ]) {
        final spaced = tanzilFixtureXml([
          ...syntheticFixtureSuras(),
          (
            name: 'Synthetic separators',
            bismillah: null,
            ayat: ['Synthetic one', 'Synthetic${separator}two'],
          ),
        ]);
        final read = readTanzilXml(spaced);
        await expectRefused(
          name,
          spikeSurahsOf(read),
          'ayah 4:2 holds $name, a separator other than U+0020',
          source: _sourceOf(spaced, read),
        );
      }
    });

    test('a source URL that repeats or leaves out a parameter name', () async {
      for (final (name, url, reason) in [
        (
          'repeated',
          'https://example.invalid/x?marks=true&marks=false',
          'the source URL repeats the query parameter marks',
        ),
        (
          'unnamed',
          'https://example.invalid/x?marks=true&=false',
          'the source URL has a query parameter with no name',
        ),
      ]) {
        await expectRefused(
          name,
          surahs,
          reason,
          source: (
            bytes: bytes,
            url: url,
            version: tanzilUthmaniVersion,
            fetchedOn: '2026-01-01',
            notice: xml.notice,
          ),
        );
      }
    });

    test(
      'on a SQLite failure after creating the directory, naming no value',
      () async {
        var deep = '${root.path}/deep';
        while (deep.length < 700) {
          deep = '$deep/${'d' * 100}';
        }
        final target = Directory(deep);
        await target.create(recursive: true);
        final message = await writeSpikePack(
          target,
          surahs: surahs,
          fontSha256: _fontSha256,
          source: _sourceOf(bytes, xml),
        ).then<String>((_) => fail('written'), onError: (Object e) => '$e');
        expect(message, endsWith('/text.sqlite: SQLite error 14'));
        expect(Directory('$deep/$spikePackId').existsSync(), isFalse);
        expect(target.existsSync(), isTrue);
        for (final sura in _longerSuras()) {
          for (final value in [sura.name, ?sura.bismillah, ...sura.ayat]) {
            expect(message, isNot(contains(value)));
          }
        }
      },
    );
  });

  test('sqliteStep names the step and the code, never the bound values', () {
    final db = sqlite3.open(':memory:')
      ..execute('CREATE TABLE t (a TEXT NOT NULL, b INTEGER NOT NULL) STRICT');
    addTearDown(db.close);
    const value = 'Synthetic bound value';
    void insert() =>
        db.execute('INSERT INTO t VALUES (?, ?)', [value, 'Synthetic other']);
    expect(insert, throwsA(predicate((Object e) => '$e'.contains(value))));
    expect(
      () => sqliteStep('ayah 1:1', insert),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'ayah 1:1: SQLite error 3091',
        ),
      ),
    );
  });

  test(
    'stores no date: another fetch date gives the same text.sqlite',
    () async {
      final xml = readTanzilXml(bytes);
      final again = await writeSpikePack(
        Directory('${root.path}/other date'),
        surahs: spikeSurahsOf(xml),
        fontSha256: _fontSha256,
        source: (
          bytes: bytes,
          url: _url,
          version: tanzilUthmaniVersion,
          fetchedOn: '2027-12-31',
          notice: xml.notice,
        ),
      );
      expect(
        await File('$again/text.sqlite').readAsBytes(),
        await File('${await written.future}/text.sqlite').readAsBytes(),
      );
    },
  );

  test('ends with VACUUM in DELETE journal mode', () async {
    final header = await RawHeader.read(
      File('${await written.future}/text.sqlite'),
    );
    expect(
      (header.writeVersion, header.readVersion, header.freelistPages),
      (1, 1, 0),
    );
  });
}
