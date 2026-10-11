import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../testing/packs/synthetic_pack.dart';
import 'loopback_forwarder.dart';
import 'loopback_pack_server.dart';

void main() {
  late Directory temp;
  late LoopbackPackServer server;
  late LoopbackForwarder forwarder;
  late SyntheticPack pack;
  const path = 'synthetic-text/1/$textFileName';

  setUpAll(() => HttpOverrides.global = null);

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('s5_forwarder');
    pack = await buildSyntheticPack(temp);
    server = await LoopbackPackServer.start(temp);
    forwarder = await LoopbackForwarder.start(
      port: 0,
      targetPort: server.baseUri.port,
    );
  });

  tearDown(() async {
    await forwarder.close();
    await server.close();
    await temp.delete(recursive: true);
  });

  Future<(int, List<int>, Object?)> get(Uri uri) async {
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(uri)).close();
      final body = <int>[];
      Object? error;
      try {
        await response.forEach(body.addAll);
      } on IOException catch (e) {
        error = e;
      }
      return (response.statusCode, body, error);
    } finally {
      client.close(force: true);
    }
  }

  test('passes a request and its answer through', () async {
    final (status, body, error) = await get(
      forwarder.baseUri.replace(path: '/$path'),
    );
    expect(status, HttpStatus.ok);
    expect(error, isNull);
    expect(
      sha256.convert(body),
      sha256.convert(await pack.textFile.readAsBytes()),
    );
    expect(server.requests.single.path, path);
  });

  test('a connection the server drops is dropped for the client', () async {
    server.inject(path, const DropAfter(1000));
    final (status, body, error) = await get(
      forwarder.baseUri.replace(path: '/$path'),
    );
    expect(status, HttpStatus.ok);
    expect(body.length, 1000);
    expect(error, isA<HttpException>());
  });

  test('closes the client when nothing listens on the target port', () async {
    await server.close();
    expect(
      () => get(forwarder.baseUri.replace(path: '/$path')),
      throwsA(isA<IOException>()),
    );
  });
}
