import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../testing/packs/synthetic_pack.dart' show amiriQuranFontPath;
import 'device_text.dart';
import 'spike_pack_writer.dart';
import 'tanzil_fixture.dart';

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

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('spike_device_text');
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
  }) => HttpOverrides.runWithHttpOverrides(
    () => fetchTanzilPack(
      url: url(path),
      expectedSha256: sha ?? digest,
      root: into,
      fontBytes: Uint8List.fromList(font),
      now: DateTime.utc(2026, 1, 2),
    ),
    _RealHttp(),
  );

  test('writes and verifies the pack, replacing an earlier one', () async {
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
}
