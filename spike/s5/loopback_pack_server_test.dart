import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../testing/packs/synthetic_pack.dart';
import 'loopback_pack_server.dart';

// The pack is synthetic (testing/packs). Bodies are compared by length and
// SHA-256, so a failure prints no stored bytes.

final class _Got {
  _Got(this.status, this.headers, this.body, this.error);

  final int status;
  final HttpHeaders headers;
  final Uint8List body;

  /// Set when the connection closed before the body was complete.
  final IOException? error;

  String? operator [](String name) => headers.value(name);
}

Future<_Got> _fetch(
  Uri uri, {
  String method = 'GET',
  Map<String, String> headers = const {},
}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, uri);
    headers.forEach(request.headers.set);
    final response = await request.close();
    final body = BytesBuilder(copy: false);
    IOException? error;
    try {
      await response.forEach(body.add);
    } on IOException catch (e) {
      error = e;
    }
    return _Got(response.statusCode, response.headers, body.takeBytes(), error);
  } finally {
    client.close(force: true);
  }
}

/// The status line of a request written by hand, so that the path reaches
/// the server exactly as given.
Future<String> _rawStatusLine(Uri base, String target) async {
  final socket = await Socket.connect(base.host, base.port);
  try {
    socket.write(
      'GET $target HTTP/1.1\r\nHost: ${base.host}\r\n'
      'Connection: close\r\n\r\n',
    );
    await socket.flush();
    final reply = await utf8.decoder.bind(socket).join();
    return reply.split('\r\n').first;
  } finally {
    socket.destroy();
  }
}

String _digest(List<int> bytes) => sha256.convert(bytes).toString();

/// The offsets at which [a] and [b] differ, when they have the same length.
List<int> _differingOffsets(List<int> a, List<int> b) {
  expect(a.length, b.length);
  return [
    for (var i = 0; i < a.length; i++)
      if (a[i] != b[i]) i,
  ];
}

void main() {
  late Directory root;
  late SyntheticPack pack;
  late LoopbackPackServer server;
  late Uint8List text;
  late String textPath;
  late String manifestPath;
  late String signaturePath;

  // The test binding answers every HttpClient request with 400; these tests
  // talk to a real server on 127.0.0.1.
  setUpAll(() => HttpOverrides.global = null);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('loopback_pack_server');
    pack = await buildSyntheticPack(Directory('${root.path}/served'));
    await File(
      '${pack.directory.path}/manifest.json.sig',
    ).writeAsBytes(List.generate(64, (i) => i));
    text = await pack.textFile.readAsBytes();
    textPath = 'synthetic-text/1/$textFileName';
    manifestPath = 'synthetic-text/1/$manifestFileName';
    signaturePath = 'synthetic-text/1/manifest.json.sig';
    server = await LoopbackPackServer.start(Directory('${root.path}/served'));
  });

  tearDown(() async {
    await server.close();
    await root.delete(recursive: true);
  });

  test('binds to 127.0.0.1 only', () {
    expect(server.baseUri.host, '127.0.0.1');
    expect(server.baseUri.port, isNonZero);
  });

  test(
    'serves each file of the pack whole, with the headers for resume',
    () async {
      for (final path in [manifestPath, signaturePath, textPath]) {
        final file = File('${root.path}/served/$path');
        final bytes = await file.readAsBytes();
        final got = await _fetch(server.uriOf(path));
        expect(got.status, HttpStatus.ok, reason: path);
        expect(got.error, isNull, reason: path);
        expect(got.body.length, bytes.length, reason: path);
        expect(_digest(got.body), _digest(bytes), reason: path);
        expect(got.headers.contentLength, bytes.length, reason: path);
        expect(got['accept-ranges'], 'bytes', reason: path);
        expect(got['etag'], '"${_digest(bytes)}"', reason: path);
        expect(got['etag'], isNot(startsWith('W/')), reason: path);
        expect(
          HttpDate.parse(got['last-modified']!),
          (await file.lastModified()).toUtc().copyWith(
            millisecond: 0,
            microsecond: 0,
          ),
          reason: path,
        );
        expect(got['content-range'], isNull, reason: path);
      }
      expect(
        (await _fetch(
          server.uriOf(manifestPath),
        )).headers.contentType?.mimeType,
        'application/json',
      );
      expect(
        (await _fetch(server.uriOf(textPath))).headers.contentType?.mimeType,
        'application/octet-stream',
      );
    },
  );

  test(
    'sends the resume headers in the case the native downloader reads',
    () async {
      final socket = await Socket.connect('127.0.0.1', server.baseUri.port);
      socket.write(
        'HEAD /$textPath HTTP/1.1\r\nHost: 127.0.0.1\r\nRange: bytes=1-2\r\n'
        'Connection: close\r\n\r\n',
      );
      await socket.flush();
      final head = await utf8.decoder.bind(socket).join();
      socket.destroy();
      for (final name in ['ETag', 'Accept-Ranges', 'Content-Range']) {
        expect(head, contains('\r\n$name: '), reason: name);
      }
    },
  );

  test('answers HEAD with the headers and no body', () async {
    final got = await _fetch(server.uriOf(textPath), method: 'HEAD');
    expect(got.status, HttpStatus.ok);
    expect(got.headers.contentLength, text.length);
    expect(got.body, isEmpty);
    expect(server.bytesServed(textPath), 0);
  });

  test('answers a byte range with 206 and Content-Range', () async {
    final size = text.length;
    final cases = {
      'bytes=10-19': (10, 20),
      'bytes=${size - 7}-': (size - 7, size),
      'bytes=-5': (size - 5, size),
      'bytes=0-${size + 100}': (0, size),
      'bytes=-${size + 100}': (0, size),
    };
    for (final MapEntry(key: range, value: (start, end)) in cases.entries) {
      final got = await _fetch(
        server.uriOf(textPath),
        headers: {'Range': range},
      );
      expect(got.status, HttpStatus.partialContent, reason: range);
      expect(
        got['content-range'],
        'bytes $start-${end - 1}/$size',
        reason: range,
      );
      expect(got.headers.contentLength, end - start, reason: range);
      expect(
        _digest(got.body),
        _digest(text.sublist(start, end)),
        reason: range,
      );
    }
  });

  test('refuses an unsatisfiable range with 416', () async {
    for (final range in ['bytes=${text.length}-', 'bytes=-0']) {
      final got = await _fetch(
        server.uriOf(textPath),
        headers: {'Range': range},
      );
      expect(
        got.status,
        HttpStatus.requestedRangeNotSatisfiable,
        reason: range,
      );
      expect(got['content-range'], 'bytes */${text.length}', reason: range);
      expect(got.body, isEmpty, reason: range);
    }
  });

  test(
    'serves the whole file for a range it does not answer in part',
    () async {
      for (final range in [
        'bytes=5-2',
        'bytes=0-1,4-5',
        'items=0-1',
        'bytes=-',
        'bytes=0-99999999999999999999',
      ]) {
        final got = await _fetch(
          server.uriOf(textPath),
          headers: {'Range': range},
        );
        expect(got.status, HttpStatus.ok, reason: range);
        expect(got.body.length, text.length, reason: range);
      }
    },
  );

  test(
    'honours If-Range: a range for this version, the whole for another',
    () async {
      final first = await _fetch(server.uriOf(textPath));
      for (final validator in [first['etag']!, first['last-modified']!]) {
        final got = await _fetch(
          server.uriOf(textPath),
          headers: {'Range': 'bytes=4-', 'If-Range': validator},
        );
        expect(got.status, HttpStatus.partialContent, reason: validator);
        expect(got.body.length, text.length - 4, reason: validator);
      }
      final other = await _fetch(
        server.uriOf(textPath),
        headers: {'Range': 'bytes=4-', 'If-Range': '"another-version"'},
      );
      expect(other.status, HttpStatus.ok);
      expect(other.body.length, text.length);
    },
  );

  test('keeps the ETag while the file is unchanged and changes it with the '
      'content', () async {
    final a = await _fetch(server.uriOf(signaturePath));
    final b = await _fetch(server.uriOf(signaturePath));
    expect(b['etag'], a['etag']);
    await File(
      '${root.path}/served/$signaturePath',
    ).writeAsBytes(List.generate(64, (i) => 63 - i));
    final c = await _fetch(server.uriOf(signaturePath));
    expect(c['etag'], isNot(a['etag']));
  });

  test('answers 404 for missing files, directories and paths that leave '
      'the served directory', () async {
    await File('${root.path}/outside.txt').writeAsString('synthetic');
    for (final path in ['synthetic-text/1/missing.bin', 'synthetic-text/1']) {
      expect((await _fetch(server.uriOf(path))).status, HttpStatus.notFound);
    }
    for (final target in [
      '/../outside.txt',
      '/%2E%2E/outside.txt',
      '/synthetic-text/%2E%2E/%2E%2E/%2E%2E/outside.txt',
      '/synthetic-text%2F1%2Fmanifest.json',
      '/',
    ]) {
      expect(
        await _rawStatusLine(server.baseUri, target),
        startsWith('HTTP/1.1 404'),
        reason: target,
      );
    }
    expect(
      (await _fetch(server.uriOf(manifestPath), method: 'POST')).status,
      HttpStatus.methodNotAllowed,
    );
  });

  test('drops the connection after N bytes once; a Range request resumes '
      'and the bytes served add up to the size', () async {
    const cut = 1000;
    server.inject(textPath, const DropAfter(cut));
    final first = await _fetch(server.uriOf(textPath));
    expect(first.status, HttpStatus.ok);
    expect(first.headers.contentLength, text.length);
    expect(first.error, isA<HttpException>());
    expect(first.body.length, cut);

    final rest = await _fetch(
      server.uriOf(textPath),
      headers: {'Range': 'bytes=$cut-', 'If-Range': first['etag']!},
    );
    expect(rest.status, HttpStatus.partialContent);
    expect(rest['etag'], first['etag']);
    expect(rest.error, isNull);
    expect(_digest([...first.body, ...rest.body]), _digest(text));

    expect(server.bytesServed(textPath), text.length);
    expect(
      [
        for (final r in server.requests)
          (r.path, r.range, r.statusCode, r.bytes, r.dropped),
      ],
      [
        (textPath, null, 200, cut, true),
        (textPath, 'bytes=$cut-', 206, text.length - cut, false),
      ],
    );
    expect(server.requests.first.faults, [const DropAfter(cut)]);
  });

  test('drops a range response after N bytes of the range', () async {
    server.inject(textPath, const DropAfter(10));
    final got = await _fetch(
      server.uriOf(textPath),
      headers: {'Range': 'bytes=100-199'},
    );
    expect(got.status, HttpStatus.partialContent);
    expect(got.error, isA<HttpException>());
    expect(_digest(got.body), _digest(text.sublist(100, 110)));
  });

  test('a drop at or beyond the body length does not take effect and stays '
      'pending', () async {
    server.inject(textPath, const DropAfter(100));
    final short = await _fetch(
      server.uriOf(textPath),
      headers: {'Range': 'bytes=0-99'},
    );
    expect(short.error, isNull);
    expect(short.body.length, 100);
    final whole = await _fetch(server.uriOf(textPath));
    expect(whole.error, isA<HttpException>());
    expect(whole.body.length, 100);
    expect(server.requests.map((r) => r.dropped), [false, true]);
  });

  test('corrupts one byte once, only when that byte is served', () async {
    final offset = text.length ~/ 2;
    server.inject(textPath, CorruptByte(offset));
    final before = await _fetch(
      server.uriOf(textPath),
      headers: {'Range': 'bytes=0-${offset - 1}'},
    );
    expect(_digest(before.body), _digest(text.sublist(0, offset)));

    final corrupted = await _fetch(server.uriOf(textPath));
    expect(_differingOffsets(corrupted.body, text), [offset]);
    expect(corrupted.body[offset], text[offset] ^ 0xFF);
    expect(corrupted['etag'], '"${_digest(text)}"');

    final again = await _fetch(server.uriOf(textPath));
    expect(_digest(again.body), _digest(text));
    expect(server.requests.map((r) => r.faults.length), [0, 1, 0]);
  });

  test('corrupts a byte inside a range at its place in the range', () async {
    server.inject(textPath, const CorruptByte(150));
    final got = await _fetch(
      server.uriOf(textPath),
      headers: {'Range': 'bytes=100-199'},
    );
    expect(_differingOffsets(got.body, text.sublist(100, 200)), [50]);
  });

  test('corrupts always when told so', () async {
    server.inject(manifestPath, const CorruptByte(3), times: null);
    final manifest = await pack.manifestFile.readAsBytes();
    for (var i = 0; i < 3; i++) {
      final got = await _fetch(server.uriOf(manifestPath));
      expect(_differingOffsets(got.body, manifest), [3]);
    }
    server.clearFaults();
    final clean = await _fetch(server.uriOf(manifestPath));
    expect(_digest(clean.body), _digest(manifest));
  });

  test('corrupts the next two requests when told twice', () async {
    server.inject(textPath, const CorruptByte(0), times: 2);
    final bodies = [
      for (var i = 0; i < 3; i++) (await _fetch(server.uriOf(textPath))).body,
    ];
    expect(
      [for (final b in bodies) _differingOffsets(b, text)],
      [
        [0],
        [0],
        <int>[],
      ],
    );
  });

  test('throttles the body to a byte rate', () async {
    server.inject(textPath, const Throttle(4000));
    final clock = Stopwatch()..start();
    final got = await _fetch(
      server.uriOf(textPath),
      headers: {'Range': 'bytes=0-1999'},
    );
    clock.stop();
    expect(_digest(got.body), _digest(text.sublist(0, 2000)));
    // A lower bound only: 2000 bytes at 4000 per second in slices of 400,
    // the last slice due at 400 ms. Timers may round down to the millisecond.
    expect(clock.elapsedMilliseconds, greaterThanOrEqualTo(395));

    final unthrottled = await _fetch(server.uriOf(textPath));
    expect(unthrottled.body.length, text.length);
  });

  test('throttles a dropped response too', () async {
    server
      ..inject(textPath, const Throttle(2000))
      ..inject(textPath, const DropAfter(600));
    final clock = Stopwatch()..start();
    final got = await _fetch(server.uriOf(textPath));
    expect(got.body.length, 600);
    expect(got.error, isA<HttpException>());
    expect(clock.elapsedMilliseconds, greaterThanOrEqualTo(195));
    expect(server.requests.single.faults, [
      const Throttle(2000),
      const DropAfter(600),
    ]);
  });

  test('delays the answer', () async {
    server.inject(manifestPath, const Delay(Duration(milliseconds: 300)));
    final clock = Stopwatch()..start();
    final got = await _fetch(server.uriOf(manifestPath));
    expect(got.status, HttpStatus.ok);
    expect(clock.elapsedMilliseconds, greaterThanOrEqualTo(295));
  });

  test('answers 404 or 500 when told, then serves again', () async {
    server
      ..inject(manifestPath, const FailWith(HttpStatus.notFound))
      ..inject(textPath, const FailWith(HttpStatus.internalServerError));
    final manifest = await _fetch(server.uriOf(manifestPath));
    final data = await _fetch(server.uriOf(textPath));
    expect(manifest.status, HttpStatus.notFound);
    expect(data.status, HttpStatus.internalServerError);
    expect(manifest.body, isEmpty);
    expect(data.body, isEmpty);
    expect((await _fetch(server.uriOf(manifestPath))).status, HttpStatus.ok);
    expect((await _fetch(server.uriOf(textPath))).status, HttpStatus.ok);
  });

  test('applies a fault only to its path', () async {
    server.inject(textPath, const FailWith(HttpStatus.internalServerError));
    expect((await _fetch(server.uriOf(manifestPath))).status, HttpStatus.ok);
    expect(
      (await _fetch(server.uriOf(textPath))).status,
      HttpStatus.internalServerError,
    );
  });

  test(
    'a one-time fault serves exactly one of two concurrent requests',
    () async {
      server.inject(textPath, const CorruptByte(0));
      final bodies = await Future.wait([
        for (var i = 0; i < 2; i++)
          _fetch(server.uriOf(textPath)).then((got) => got.body),
      ]);
      expect(
        bodies.where((b) => _differingOffsets(b, text).isNotEmpty),
        hasLength(1),
      );
    },
  );

  test('logs every request and counts the bytes served per file', () async {
    await _fetch(server.uriOf(manifestPath));
    await _fetch(server.uriOf(textPath), headers: {'Range': 'bytes=0-99'});
    await _fetch(server.uriOf(textPath), headers: {'Range': 'bytes=100-'});
    await _fetch(server.uriOf(textPath), method: 'HEAD');
    await _fetch(server.uriOf('synthetic-text/1/missing.bin'));
    final manifestBytes = (await pack.manifestFile.readAsBytes()).length;
    expect(server.bytesServed(manifestPath), manifestBytes);
    expect(server.bytesServed(textPath), text.length);
    expect(server.bytesServed('synthetic-text/1/missing.bin'), 0);
    expect(server.bytesServed(signaturePath), 0);
    expect(
      [for (final r in server.requests) (r.method, r.statusCode, r.bytes)],
      [
        ('GET', 200, manifestBytes),
        ('GET', 206, 100),
        ('GET', 206, text.length - 100),
        ('HEAD', 200, 0),
        ('GET', 404, 0),
      ],
    );
    expect('${server.requests[1]}', 'GET $textPath bytes=0-99: 206, 100 bytes');
  });

  test('serves a single pack directory as its root', () async {
    final single = await LoopbackPackServer.start(pack.directory);
    addTearDown(single.close);
    final got = await _fetch(single.uriOf(textFileName));
    expect(got.status, HttpStatus.ok);
    expect(_digest(got.body), _digest(text));
    expect(single.bytesServed(textFileName), text.length);
    expect(server.requests, isEmpty);
  });
}
