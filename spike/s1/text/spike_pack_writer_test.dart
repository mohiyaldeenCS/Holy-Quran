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
  url: 'https://example.invalid/synthetic.xml',
  version: tanzilUthmaniVersion,
  fetchedOn: '2026-01-01',
  notice: xml.notice,
);

Future<String> _write(Directory root, Uint8List bytes) {
  final xml = readTanzilXml(bytes);
  return writeSpikePack(
    root,
    surahs: spikeSurahsOf(xml),
    fontSha256: _fontSha256,
    source: _sourceOf(bytes, xml),
  );
}

/// Enough ayat for several units of every synthetic division.
List<FixtureSura> _longerSuras() => [
  ...syntheticFixtureSuras(),
  for (final (n, count) in [(4, 230), (5, 9)])
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

  test('takes words as the runs between U+0020, in UTF-16 units', () async {
    final raw = RawPack.open(File('${await written.future}/text.sqlite'));
    addTearDown(raw.close);
    expect(raw.words(2, 1), [(1, 1, 10), (2, 12, 18), (3, 20, 26)]);
    expect(raw.words(2, 2), [(1, 0, 2), (2, 3, 5), (3, 6, 8)]);
    expect(spikeWordSpans('  '), isEmpty);
    expect(spikeWordSpans('a'), [(0, 1)]);
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
      expect(summary, allOf(contains('U+0020'), contains('synthetic')));
      final counts = manifest['counts']! as Map;
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

  test(
    'refuses a value that is not the source bytes, leaving nothing',
    () async {
      final xml = readTanzilXml(bytes);
      final surahs = spikeSurahsOf(xml);
      final first = surahs.first;
      final shifted = [
        (
          name: first.name,
          basmala: first.basmala,
          ayat: [
            (
              value: first.ayat.first.value,
              byteOffset: first.ayat.first.byteOffset + 1,
            ),
            ...first.ayat.skip(1),
          ],
        ),
        ...surahs.skip(1),
      ];
      final target = Directory('${root.path}/d');
      await expectLater(
        writeSpikePack(
          target,
          surahs: shifted,
          fontSha256: _fontSha256,
          source: _sourceOf(bytes, xml),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'ayah 1:1 differs from the source bytes at byte '
                '${first.ayat.first.byteOffset + 1}',
          ),
        ),
      );
      expect(Directory('${target.path}/$spikePackId/1').existsSync(), isFalse);
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
