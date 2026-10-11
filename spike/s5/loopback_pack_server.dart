import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// A fault the server applies to a request for one path.
sealed class PackServerFault {
  const PackServerFault();
}

/// Sends the headers of the whole response, then closes the connection after
/// [bytes] bytes of its body.
final class DropAfter extends PackServerFault {
  const DropAfter(this.bytes);

  final int bytes;

  @override
  String toString() => 'DropAfter($bytes)';
}

/// Serves the byte at file offset [offset] with its bits inverted.
final class CorruptByte extends PackServerFault {
  const CorruptByte(this.offset);

  final int offset;

  @override
  String toString() => 'CorruptByte($offset)';
}

/// Sends the body at no more than [bytesPerSecond].
final class Throttle extends PackServerFault {
  const Throttle(this.bytesPerSecond);

  final int bytesPerSecond;

  @override
  String toString() => 'Throttle($bytesPerSecond)';
}

/// Waits [duration] before answering.
final class Delay extends PackServerFault {
  const Delay(this.duration);

  final Duration duration;

  @override
  String toString() => 'Delay(${duration.inMilliseconds} ms)';
}

/// Answers with [statusCode] and an empty body.
final class FailWith extends PackServerFault {
  const FailWith(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'FailWith($statusCode)';
}

/// One request as the server answered it.
final class ServedRequest {
  ServedRequest._(this.method, this.path, this.range, this.ifRange);

  final String method;

  /// Relative to the served directory, without a leading slash.
  final String path;
  final String? range;
  final String? ifRange;
  int statusCode = 0;

  /// Body bytes handed to the connection.
  int bytes = 0;
  bool dropped = false;
  final List<PackServerFault> faults = [];

  @override
  String toString() =>
      '$method $path${range == null ? '' : ' $range'}: $statusCode, '
      '$bytes bytes${dropped ? ', dropped' : ''}'
      '${faults.isEmpty ? '' : ' $faults'}';
}

final class _Rule {
  _Rule(this.fault, this.remaining);

  final PackServerFault fault;

  /// Null: every request.
  int? remaining;

  bool get active => remaining != 0;

  void consume() {
    if (remaining case final n?) remaining = n - 1;
  }
}

/// An HTTP server on 127.0.0.1 that serves the files under a directory: one
/// pack directory (`manifest.json`, `manifest.json.sig`, data files) or a
/// tree of `<id>/<version>/` directories. It answers `Range` requests with
/// 206 and `Content-Range`, sends a strong `ETag` (the file's SHA-256) and
/// `Last-Modified`, honours `If-Range`, reads each file afresh per request,
/// and applies the faults injected for a path.
final class LoopbackPackServer {
  LoopbackPackServer._(this._server, this._root, this._rootReal) {
    _server.listen((request) => unawaited(_handle(request)));
  }

  static Future<LoopbackPackServer> start(Directory root) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
      ..autoCompress = false;
    return LoopbackPackServer._(
      server,
      root.absolute.path,
      root.resolveSymbolicLinksSync(),
    );
  }

  final HttpServer _server;
  final String _root;
  final String _rootReal;
  final Map<String, List<_Rule>> _rules = {};
  final List<ServedRequest> _requests = [];

  Uri get baseUri => Uri(scheme: 'http', host: '127.0.0.1', port: _server.port);

  /// The URL of [path], relative to the served directory.
  Uri uriOf(String path) => baseUri.replace(path: '/$path');

  /// Every request so far, in the order they arrived.
  List<ServedRequest> get requests => List.unmodifiable(_requests);

  /// Body bytes handed to connections for [path], over every request.
  int bytesServed(String path) =>
      _requests.where((r) => r.path == path).fold(0, (sum, r) => sum + r.bytes);

  /// Applies [fault] to the next [times] requests for [path] it takes effect
  /// on, or to every one when [times] is null. A [CorruptByte] takes effect
  /// only when its offset is served, a [DropAfter] only when the body is
  /// longer than its byte count, and neither on `HEAD`.
  void inject(String path, PackServerFault fault, {int? times = 1}) =>
      (_rules[path] ??= []).add(_Rule(fault, times));

  void clearFaults() => _rules.clear();

  Future<void> close() => _server.close(force: true);

  /// The first active fault of type [T] for [path] that [when] accepts,
  /// consumed in the same synchronous step, so that concurrent requests do
  /// not share a fault meant for one.
  T? _take<T extends PackServerFault>(
    String path,
    ServedRequest entry, [
    bool Function(T fault)? when,
  ]) {
    for (final rule in _rules[path] ?? const <_Rule>[]) {
      final fault = rule.fault;
      if (rule.active && fault is T && (when == null || when(fault))) {
        rule.consume();
        entry.faults.add(fault);
        return fault;
      }
    }
    return null;
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    final path = _relativePath(request.uri);
    final entry = ServedRequest._(
      request.method,
      path ?? request.uri.path,
      request.headers.value(HttpHeaders.rangeHeader),
      request.headers.value(HttpHeaders.ifRangeHeader),
    );
    _requests.add(entry);
    void answer(int status) {
      entry.statusCode = status;
      response.statusCode = status;
    }

    Future<void> answerEmpty(int status) async {
      answer(status);
      response.contentLength = 0;
      await response.close();
    }

    try {
      final isHead = request.method == 'HEAD';
      if (request.method != 'GET' && !isHead) {
        return await answerEmpty(HttpStatus.methodNotAllowed);
      }
      if (path != null) {
        if (_take<Delay>(path, entry) case final delay?) {
          await Future<void>.delayed(delay.duration);
        }
        if (_take<FailWith>(path, entry) case final failure?) {
          return await answerEmpty(failure.statusCode);
        }
      }
      final file = path == null ? null : _fileAt(path);
      if (file == null) {
        return await answerEmpty(HttpStatus.notFound);
      }

      final bytes = await file.readAsBytes();
      final etag = '"${sha256.convert(bytes)}"';
      final lastModified = HttpDate.format(await file.lastModified());
      response.headers
        ..set('Accept-Ranges', 'bytes', preserveHeaderCase: true)
        ..set('ETag', etag, preserveHeaderCase: true)
        ..set('Last-Modified', lastModified, preserveHeaderCase: true)
        ..contentType = path!.endsWith('.json')
            ? ContentType.json
            : ContentType.binary;

      var start = 0;
      var end = bytes.length;
      final ifRange = entry.ifRange;
      if (entry.range case final range?
          when ifRange == null || ifRange == etag || ifRange == lastModified) {
        switch (_parseRange(range, bytes.length)) {
          case _Part(start: final s, end: final e):
            start = s;
            end = e;
            answer(HttpStatus.partialContent);
            response.headers.set(
              'Content-Range',
              'bytes $s-${e - 1}/${bytes.length}',
              preserveHeaderCase: true,
            );
          case _Unsatisfiable():
            response.headers.set(
              'Content-Range',
              'bytes */${bytes.length}',
              preserveHeaderCase: true,
            );
            return await answerEmpty(HttpStatus.requestedRangeNotSatisfiable);
          case _Whole():
        }
      }
      if (entry.statusCode == 0) answer(HttpStatus.ok);
      response.contentLength = end - start;
      if (isHead) {
        await response.close();
        return;
      }

      final body = Uint8List.fromList(bytes.sublist(start, end));
      if (_take<CorruptByte>(
            path,
            entry,
            (f) => f.offset >= start && f.offset < end,
          )
          case final corrupt?) {
        body[corrupt.offset - start] ^= 0xFF;
      }
      final rate = _take<Throttle>(path, entry)?.bytesPerSecond;
      final drop = _take<DropAfter>(path, entry, (f) => f.bytes < body.length);
      if (drop == null) {
        await _send(body, response, rate, entry);
        await response.close();
        return;
      }
      final socket = await response.detachSocket();
      entry.dropped = true;
      await _send(
        Uint8List.sublistView(body, 0, drop.bytes),
        socket,
        rate,
        entry,
      );
      socket.destroy();
    } on IOException {
      // The client went away; the entry keeps what was sent.
    }
  }

  /// Writes [data] in slices, paced to [bytesPerSecond] when given. Bytes are
  /// counted before they are handed over, so a client never sees more than
  /// the log holds.
  static Future<void> _send(
    Uint8List data,
    IOSink sink,
    int? bytesPerSecond,
    ServedRequest entry,
  ) async {
    final slice = bytesPerSecond == null
        ? max(data.length, 1)
        : max(bytesPerSecond ~/ 10, 1);
    final clock = Stopwatch()..start();
    for (var at = 0; at < data.length; at += slice) {
      if (bytesPerSecond != null) {
        final wait =
            Duration(microseconds: at * 1000000 ~/ bytesPerSecond) -
            clock.elapsed;
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      final chunk = Uint8List.sublistView(
        data,
        at,
        min(at + slice, data.length),
      );
      entry.bytes += chunk.length;
      sink.add(chunk);
      await sink.flush();
    }
  }

  /// The decoded path below the served directory, or null when a segment
  /// could leave it.
  static String? _relativePath(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.isEmpty) return null;
    for (final segment in segments) {
      if (segment.isEmpty ||
          segment == '.' ||
          segment == '..' ||
          segment.contains('/') ||
          segment.contains(r'\') ||
          segment.contains('\u0000')) {
        return null;
      }
    }
    return segments.join('/');
  }

  /// A regular file under the served directory, links resolved.
  File? _fileAt(String path) {
    final file = File('$_root/$path');
    if (file.statSync().type != FileSystemEntityType.file) return null;
    final real = file.resolveSymbolicLinksSync();
    if (!real.startsWith('$_rootReal${Platform.pathSeparator}')) return null;
    return file;
  }
}

sealed class _Range {
  const _Range();
}

/// The `Range` header is not one this server answers in part: malformed, not
/// in bytes, or more than one range. RFC 9110 lets a server ignore it.
final class _Whole extends _Range {
  const _Whole();
}

final class _Unsatisfiable extends _Range {
  const _Unsatisfiable();
}

/// The half-open byte range [start, end).
final class _Part extends _Range {
  const _Part(this.start, this.end);

  final int start;
  final int end;
}

final _byteRange = RegExp(r'^bytes=(\d*)-(\d*)$');

_Range _parseRange(String header, int size) {
  final match = _byteRange.firstMatch(header.trim());
  if (match == null) return const _Whole();
  final first = match[1]!;
  final last = match[2]!;
  if (first.isEmpty) {
    final suffix = int.tryParse(last);
    if (suffix == null) return const _Whole();
    if (suffix == 0 || size == 0) return const _Unsatisfiable();
    return _Part(max(size - suffix, 0), size);
  }
  final start = int.tryParse(first);
  final end = last.isEmpty ? null : int.tryParse(last);
  if (start == null || (last.isNotEmpty && end == null)) return const _Whole();
  if (end != null && end < start) return const _Whole();
  if (start >= size) return const _Unsatisfiable();
  return _Part(start, min(end == null ? size : end + 1, size));
}
