import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../testing/packs/synthetic_pack.dart' show amiriQuranFontPath;
import 'device_text.dart';
import 'spike_pack_writer.dart';
import 'tanzil_fixture.dart';
import 'tanzil_xml.dart';

// The device path against a loopback server serving a synthetic fixture.

/// The test binding answers every request with 400; the loopback server
/// needs a real client.
final class _RealHttp extends HttpOverrides {}

void main() {
  late HttpServer server;
  late Directory root;
  final bytes = tanzilFixtureXml(syntheticFixtureSuras());
  final digest = sha256.convert(bytes).toString();
  final font = File(amiriQuranFontPath).readAsBytesSync();
  late String packDigest;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('spike_device_text');
    final xml = readTanzilXml(bytes);
    final reference = await writeSpikePack(
      Directory('${root.path}/reference'),
      surahs: spikeSurahsOf(xml),
      fontSha256: sha256.convert(font).toString(),
      source: (
        bytes: bytes,
        url: 'https://example.invalid/elsewhere.xml',
        version: tanzilUthmaniVersion,
        fetchedOn: '2030-05-05',
        notice: xml.notice,
      ),
    );
    packDigest = sha256
        .convert(await File('$reference/text.sqlite').readAsBytes())
        .toString();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (request.uri.path == '/quran.xml') {
        request.response.add(bytes);
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });
  });
  tearDownAll(() async {
    await server.close(force: true);
    await root.delete(recursive: true);
  });

  Uri url(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');

  Future<String> fetch(
    Directory into, {
    String path = '/quran.xml',
    String? sha,
    String? packSha,
    Uri? at,
  }) => HttpOverrides.runWithHttpOverrides(
    () => fetchTanzilPack(
      url: at ?? url(path),
      expectedSha256: sha ?? digest,
      expectedPackSha256: packSha ?? packDigest,
      root: into,
      fontBytes: Uint8List.fromList(font),
      now: DateTime.utc(2026, 1, 2),
    ),
    _RealHttp(),
  );

  test('writes the pack the CI run recorded, whatever the date and URL, '
      'replacing an earlier one', () async {
    final into = Directory('${root.path}/ok');
    final first = await fetch(into);
    expect(first, '${into.path}/$spikePackId/$spikePackVersion');
    final manifest = await File('$first/manifest.json').readAsString();
    expect(manifest, contains('"fetched_on": "2026-01-02"'));
    expect(manifest, contains('"file_sha256": "$digest"'));
    expect(await fetch(into), first);
  });

  test('refuses a file with another SHA-256 and writes nothing', () async {
    final into = Directory('${root.path}/mismatch');
    final other = sha256.convert([0]).toString();
    await expectLater(
      fetch(into, sha: other),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'the file has SHA-256 $digest, not $other',
        ),
      ),
    );
    expect(into.existsSync(), isFalse);
  });

  test('refuses an expected SHA-256 that is not lowercase hex', () async {
    await expectLater(
      fetch(Directory('${root.path}/upper'), sha: digest.toUpperCase()),
      throwsStateError,
    );
  });

  test('refuses an answer other than 200', () async {
    await expectLater(
      fetch(Directory('${root.path}/missing'), path: '/none.xml'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'the server answered 404',
        ),
      ),
    );
  });

  test(
    'refuses a pack with another text.sqlite SHA-256, keeping none',
    () async {
      final into = Directory('${root.path}/other pack');
      final other = sha256.convert([1]).toString();
      await expectLater(
        fetch(into, packSha: other),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'the device pack text.sqlite has SHA-256 $packDigest, not $other',
          ),
        ),
      );
      expect(Directory('${into.path}/$spikePackId').existsSync(), isFalse);
    },
  );

  test('refuses an expected pack SHA-256 that is not lowercase hex', () async {
    await expectLater(
      fetch(Directory('${root.path}/no pack sha'), packSha: ''),
      throwsStateError,
    );
  });

  test('reports another exception by its type only', () async {
    final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = closed.port;
    await closed.close();
    await expectLater(
      fetch(
        Directory('${root.path}/refused'),
        at: Uri.parse('http://127.0.0.1:$port/quran.xml'),
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'fetching: SocketException',
        ),
      ),
    );
  });
}
