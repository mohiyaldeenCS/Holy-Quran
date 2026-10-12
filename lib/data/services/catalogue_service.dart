import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../../utils/result.dart';
import 'download_service.dart';

/// The application-support directory, under which the catalogue's copy and
/// downloaded recitation files are kept.
Future<String> applicationSupportPath() async =>
    (await getApplicationSupportDirectory()).path;

/// The server answered [url] with [statusCode], not 200.
final class UnexpectedStatus implements Exception {
  const UnexpectedStatus(this.url, this.statusCode);

  final Uri url;
  final int statusCode;

  @override
  String toString() => 'UnexpectedStatus($url): HTTP $statusCode';
}

/// Fetches small files, such as `catalogue.json`, by `GET` over TLS 1.2 or
/// later (NF-15). Release assets redirect to a storage host, so redirects
/// are followed by hand: each hop must pass the policy and keep the scheme
/// of the first URL, at most five times.
final class CatalogueService {
  const CatalogueService();

  static const _maxRedirects = 5;
  static const _maxBytes = 4 << 20;
  static const _timeout = Duration(seconds: 30);

  /// The body of [url]. Fails with [UrlRefused] when [url] or a redirect is
  /// one [policy] refuses, [UnexpectedStatus] for an answer other than 200,
  /// and [UrlUnreachable] when the server cannot be reached, is too slow or
  /// sends more than 4 MiB.
  Future<Result<Uint8List>> fetch(Uri url, UrlPolicy policy) async {
    if (!policy.allows(url)) return Failure(UrlRefused(url));
    final client = HttpClient(
      context: SecurityContext(withTrustedRoots: true)
        ..minimumTlsProtocolVersion = TlsProtocolVersion.tls1_2,
    )..connectionTimeout = _timeout;
    try {
      var current = url;
      for (var followed = 0; ; followed++) {
        final request = await client.getUrl(current)
          ..followRedirects = false;
        final response = await request.close().timeout(_timeout);
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (response.isRedirect && location != null) {
          await response.drain<void>();
          final Uri next;
          try {
            next = current.resolve(location);
          } on FormatException catch (e) {
            return Failure(UrlUnreachable(url, '$e'));
          }
          if (followed == _maxRedirects ||
              next.scheme != url.scheme ||
              !policy.allows(next)) {
            return Failure(UrlRefused(next, from: current));
          }
          current = next;
          continue;
        }
        if (response.statusCode != HttpStatus.ok) {
          await response.drain<void>();
          return Failure(UnexpectedStatus(current, response.statusCode));
        }
        return await _body(response, current);
      }
    } on IOException catch (e) {
      return Failure(UrlUnreachable(url, '$e'));
    } on TimeoutException catch (e) {
      return Failure(UrlUnreachable(url, '$e'));
    } finally {
      client.close(force: true);
    }
  }

  Future<Result<Uint8List>> _body(HttpClientResponse response, Uri url) async {
    final body = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(_timeout)) {
      body.add(chunk);
      if (body.length > _maxBytes) {
        return Failure(UrlUnreachable(url, 'more than $_maxBytes bytes'));
      }
    }
    return Ok(body.takeBytes());
  }
}

/// The last catalogue the app accepted, both files, in [directory]. Each
/// file is written beside its place and renamed over it; a pair cut short
/// by a crash fails its signature check and is not served.
final class CatalogueStore {
  const CatalogueStore(this.directory);

  static const _catalogue = 'catalogue.json';
  static const _signature = 'catalogue.json.sig';
  static const _partial = '.partial';

  final String directory;

  /// The kept catalogue and its signature, or null when no catalogue is
  /// kept. The signature is null when the catalogue had none.
  Future<({Uint8List catalogue, Uint8List? signature})?> read() async {
    final catalogue = await _readIfExists(_catalogue);
    if (catalogue == null) return null;
    return (catalogue: catalogue, signature: await _readIfExists(_signature));
  }

  /// Keeps [catalogue] and [signature] in place of the copy before.
  Future<void> write(Uint8List catalogue, Uint8List? signature) async {
    await Directory(directory).create(recursive: true);
    if (signature == null) {
      await _remove(_signature);
    } else {
      await _replace(_signature, signature);
    }
    await _replace(_catalogue, catalogue);
  }

  Future<Uint8List?> _readIfExists(String name) async {
    try {
      return await File('$directory/$name').readAsBytes();
    } on PathNotFoundException {
      return null;
    }
  }

  Future<void> _replace(String name, Uint8List bytes) async {
    final partial = File('$directory/$name$_partial');
    await partial.writeAsBytes(bytes, flush: true);
    await partial.rename('$directory/$name');
  }

  Future<void> _remove(String name) async {
    try {
      await File('$directory/$name').delete();
    } on PathNotFoundException {
      // Nothing was kept under that name.
    }
  }
}
