import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/services/catalogue_service.dart';
import 'package:holyquran/data/services/download_service.dart';
import 'package:holyquran/utils/result.dart';

/// Serves [files] by path on 127.0.0.1, with redirects by path; any other
/// path is 404.
final class _Server {
  _Server._(this._server) {
    _server.listen((request) => unawaited(_handle(request)));
  }

  static Future<_Server> start() async =>
      _Server._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;
  final files = <String, List<int>>{};
  final redirects = <String, String>{};
  final requests = <String>[];

  Uri uri(String path) =>
      Uri(scheme: 'http', host: '127.0.0.1', port: _server.port, path: path);

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    requests.add('${request.method} $path');
    final response = request.response;
    if (redirects[path] case final location?) {
      response
        ..statusCode = HttpStatus.found
        ..headers.set(HttpHeaders.locationHeader, location);
    } else if (files[path] case final body?) {
      response.add(body);
    } else {
      response.statusCode = HttpStatus.notFound;
    }
    await response.close();
  }
}

void main() {
  const http = UrlPolicy(scheme: 'http');
  const service = CatalogueService();
  late _Server server;
  final httpOverrides = HttpOverrides.current;

  setUpAll(() => HttpOverrides.global = null);
  tearDownAll(() => HttpOverrides.global = httpOverrides);
  setUp(() async => server = await _Server.start());
  tearDown(() => server.close());

  group('CatalogueService', () {
    test('fetches a body by GET', () async {
      server.files['/catalogue.json'] = utf8.encode('synthetic body');
      final result = await service.fetch(server.uri('/catalogue.json'), http);
      expect(utf8.decode((result as Ok<Uint8List>).value), 'synthetic body');
      expect(server.requests, ['GET /catalogue.json']);
    });

    test('follows redirects that keep the scheme', () async {
      server
        ..files['/storage/catalogue.json'] = utf8.encode('moved')
        ..redirects['/a'] = '/b'
        ..redirects['/b'] = server.uri('/storage/catalogue.json').toString();
      final result = await service.fetch(server.uri('/a'), http);
      expect(utf8.decode((result as Ok<Uint8List>).value), 'moved');
      expect(server.requests, [
        'GET /a',
        'GET /b',
        'GET /storage/catalogue.json',
      ]);
    });

    test('refuses a URL or a redirect the policy refuses', () async {
      final refused = await service.fetch(
        Uri.parse('ftp://127.0.0.1/catalogue.json'),
        http,
      );
      expect(
        (refused as Failure<Uint8List>).error,
        isA<UrlRefused>().having((e) => e.from, 'from', isNull),
      );

      server.redirects['/a'] = 'https://127.0.0.1/catalogue.json';
      final redirected = await service.fetch(server.uri('/a'), http);
      expect(
        (redirected as Failure<Uint8List>).error,
        isA<UrlRefused>()
            .having((e) => e.url.scheme, 'scheme', 'https')
            .having((e) => e.from, 'from', server.uri('/a')),
      );
      expect(server.requests, ['GET /a']);
    });

    test('refuses more than five redirects', () async {
      for (var i = 0; i < 6; i++) {
        server.redirects['/$i'] = '/${i + 1}';
      }
      server.files['/6'] = [1];
      final result = await service.fetch(server.uri('/0'), http);
      expect((result as Failure<Uint8List>).error, isA<UrlRefused>());
      expect(server.requests, hasLength(6));
    });

    test('reports an answer other than 200 with its status', () async {
      final result = await service.fetch(server.uri('/missing'), http);
      expect(
        (result as Failure<Uint8List>).error,
        isA<UnexpectedStatus>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.url, 'url', server.uri('/missing')),
      );
      expect('${result.error}', contains('HTTP 404'));
    });

    test('refuses a body over 4 MiB', () async {
      server.files['/big'] = Uint8List((4 << 20) + 1);
      final result = await service.fetch(server.uri('/big'), http);
      expect((result as Failure<Uint8List>).error, isA<UrlUnreachable>());
    });

    test('reports a server it cannot reach', () async {
      final url = server.uri('/catalogue.json');
      await server.close();
      final result = await service.fetch(url, http);
      expect((result as Failure<Uint8List>).error, isA<UrlUnreachable>());
    });
  });

  group('CatalogueStore', () {
    late Directory root;

    setUp(
      () async => root = await Directory.systemTemp.createTemp('catalogue'),
    );
    tearDown(() => root.delete(recursive: true));

    test('keeps nothing at first', () async {
      expect(await CatalogueStore('${root.path}/catalogue').read(), isNull);
    });

    test(
      'keeps a catalogue with its signature, in place of the last',
      () async {
        final store = CatalogueStore('${root.path}/catalogue');
        await store.write(Uint8List.fromList([1, 2]), Uint8List.fromList([3]));
        var kept = await store.read();
        expect(kept!.catalogue, [1, 2]);
        expect(kept.signature, [3]);

        await store.write(Uint8List.fromList([4]), null);
        kept = await store.read();
        expect(kept!.catalogue, [4]);
        expect(kept.signature, isNull);
        expect(
          Directory('${root.path}/catalogue').listSync().map((e) => e.path),
          ['${root.path}/catalogue${Platform.pathSeparator}catalogue.json'],
        );
      },
    );
  });
}
