import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../fakes/fake_catalogue_repository.dart';
import '../packs/synthetic_files.dart' show manifestFileName;
import '../packs/synthetic_tafsir_pack.dart';

/// The id of the tafsir pack the flows download.
const flowTafsirId = 'synthetic-tafsir';

/// An HTTP server on the loopback address that serves the files under a
/// directory, as the host of the catalogue and the packs would.
final class FlowServer {
  FlowServer._(this._server, this._root) {
    _server.listen((request) => unawaited(_handle(request)));
  }

  static Future<FlowServer> start(Directory root) async => FlowServer._(
    await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    root,
  );

  final HttpServer _server;
  final Directory _root;

  /// Every request made, as `GET /path`.
  final List<String> requests = [];

  /// How many more `GET`s of a path are answered with one byte inverted.
  final Map<String, int> corrupt = {};

  Uri uri(String path) =>
      Uri(scheme: 'http', host: '127.0.0.1', port: _server.port, path: path);

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    requests.add('${request.method} $path');
    final response = request.response;
    final file = File('${_root.path}$path');
    if (!await file.exists()) {
      response.statusCode = HttpStatus.notFound;
      return response.close();
    }
    final body = await file.readAsBytes();
    if (request.method == 'GET' && (corrupt[path] ?? 0) > 0) {
      corrupt[path] = corrupt[path]! - 1;
      body[body.length ~/ 2] ^= 0xFF;
    }
    response.contentLength = body.length;
    if (request.method == 'GET') response.add(body);
    return response.close();
  }

  /// How many times [path] was fetched.
  int gets(String path) => requests.where((r) => r == 'GET $path').length;
}

/// Builds the tafsir pack under [served] and the catalogue that lists it at
/// `/catalogue.json`, with URLs on [server]: the synthetic catalogue's
/// recitations and its tafsir pack, whose files are the ones built.
Future<SyntheticTafsirPack> serveCatalogue(
  Directory served,
  FlowServer server,
) async {
  final tafsir = await buildSyntheticTafsirPack(served);
  final manifest = await File(
    '${tafsir.directory.path}/$manifestFileName',
  ).readAsBytes();
  final data = await tafsir.file.readAsBytes();
  const base = '/$flowTafsirId/1';
  final json = syntheticCatalogueJson(base: server.uri('/').toString());
  final packs = (json['packs']! as List<Object?>).cast<Map<String, Object?>>();
  packs.firstWhere((pack) => pack['id'] == flowTafsirId)
    ..['version'] = 1
    ..['signature'] = null
    ..['manifest'] = {
      'url': server.uri('$base/$manifestFileName').toString(),
      'bytes': manifest.length,
      'sha256': sha256.convert(manifest).toString(),
    }
    ..['files'] = [
      {
        'name': tafsirFileName,
        'url': server.uri('$base/$tafsirFileName').toString(),
        'bytes': data.length,
        'sha256': sha256.convert(data).toString(),
      },
    ];
  // The base pack is bundled, never downloaded.
  packs.removeWhere((pack) => pack['kind'] == 'text');
  await File(
    '${served.path}/catalogue.json',
  ).writeAsBytes(utf8.encode(jsonEncode(json)));
  return tafsir;
}
