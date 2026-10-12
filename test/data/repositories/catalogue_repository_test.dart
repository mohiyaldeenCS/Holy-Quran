import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/catalogue_repository.dart';
import 'package:holyquran/data/services/catalogue_service.dart';
import 'package:holyquran/data/services/download_service.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/domain/models/catalogue.dart';
import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/domain/models/resource_state.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_catalogue_repository.dart';

/// Serves [files] by path on 127.0.0.1, answers [statuses] by path, and 404
/// for any other path.
final class _Server {
  _Server._(this._server) : _port = _server.port {
    _server.listen((request) => unawaited(_handle(request)));
  }

  static Future<_Server> start() async =>
      _Server._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;
  final int _port;
  final files = <String, List<int>>{};
  final statuses = <String, int>{};
  final requests = <String>[];

  Uri uri(String path) =>
      Uri(scheme: 'http', host: '127.0.0.1', port: _port, path: path);

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    requests.add(path);
    final response = request.response;
    if (statuses[path] case final status?) {
      response.statusCode = status;
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
  final algorithm = Ed25519();
  final httpOverrides = HttpOverrides.current;
  late SimpleKeyPair key;
  late List<int> publicKey;
  late _Server server;
  late Directory root;

  setUpAll(() async {
    HttpOverrides.global = null;
    key = await algorithm.newKeyPair();
    publicKey = (await key.extractPublicKey()).bytes;
  });
  tearDownAll(() => HttpOverrides.global = httpOverrides);

  setUp(() async {
    server = await _Server.start();
    root = await Directory.systemTemp.createTemp('catalogue_repository');
  });
  tearDown(() async {
    await server.close();
    await root.delete(recursive: true);
  });

  Map<String, Object?> json({int tafsirVersion = 2}) => syntheticCatalogueJson(
    base: server.uri('/packs/').toString(),
    tafsirVersion: tafsirVersion,
  );

  Future<Uint8List> sign(List<int> bytes) async =>
      Uint8List.fromList((await algorithm.sign(bytes, keyPair: key)).bytes);

  /// Publishes [catalogue] with a signature by the key, unless [signed] is
  /// false; [signature] replaces the signature's bytes.
  Future<void> publish(
    Map<String, Object?> catalogue, {
    bool signed = true,
    List<int>? signature,
  }) async {
    final bytes = catalogueBytes(catalogue);
    server.files['/catalogue.json'] = bytes;
    server.files.remove('/catalogue.json.sig');
    if (signed) {
      server.files['/catalogue.json.sig'] = signature ?? await sign(bytes);
    }
  }

  CatalogueStore store() => CatalogueStore('${root.path}/catalogue');

  RemoteCatalogueRepository repository({
    bool acceptUnchecked = false,
    List<List<int>>? keys,
    Future<CatalogueStore> Function()? openStore,
    UrlPolicy policy = http,
    String path = '/catalogue.json',
  }) {
    final repository = RemoteCatalogueRepository(
      address: server.uri(path),
      service: const CatalogueService(),
      openStore: openStore ?? () async => store(),
      verifier: Ed25519ManifestVerifier(keys ?? [publicKey]),
      policy: policy,
      acceptUnchecked: acceptUnchecked,
    );
    addTearDown(repository.dispose);
    return repository;
  }

  Matcher failsWith<T extends CatalogueFailure>() =>
      isA<Failure<Catalogue>>().having((f) => f.error, 'error', isA<T>());

  group('a valid catalogue', () {
    test('is fetched with its signature, served and kept', () async {
      await publish(json());
      final catalogue = repository();
      var notified = 0;
      catalogue.addListener(() => notified++);
      expect(catalogue.catalogue, isNull);

      final result = await catalogue.refresh();

      expect(result, isA<Ok<Catalogue>>());
      expect(catalogue.catalogue, same((result as Ok<Catalogue>).value));
      expect(catalogue.catalogue!.firstUseTafsir!.id, 'synthetic-tafsir');
      expect(notified, 1);
      expect(server.requests, ['/catalogue.json', '/catalogue.json.sig']);
      final kept = await store().read();
      expect(kept!.catalogue, server.files['/catalogue.json']);
      expect(kept.signature, server.files['/catalogue.json.sig']);
    });

    test('one refresh at a time', () async {
      await publish(json());
      final catalogue = repository();
      final first = catalogue.refresh();
      expect(catalogue.refresh(), same(first));
      await first;
      expect(server.requests, hasLength(2));
      await catalogue.refresh();
      expect(server.requests, hasLength(4));
    });

    test('a copy that cannot be kept is still served', () async {
      await publish(json());
      final catalogue = repository(
        openStore: () async =>
            throw const FileSystemException('synthetic failure'),
      );
      expect(await catalogue.refresh(), isA<Ok<Catalogue>>());
      expect(catalogue.catalogue, isNotNull);
    });
  });

  group('the signature policy of D-108', () {
    test('an invalid signature is refused under either policy', () async {
      await publish(json(), signature: Uint8List(64));
      for (final acceptUnchecked in [false, true]) {
        final catalogue = repository(acceptUnchecked: acceptUnchecked);
        expect(
          await catalogue.refresh(),
          failsWith<CatalogueSignatureRejected>(),
        );
        expect(catalogue.catalogue, isNull);
      }
      expect(await store().read(), isNull);
    });

    test('a signature by another key is refused', () async {
      final other = await algorithm.newKeyPair();
      final catalogue = catalogueBytes(json());
      await publish(
        json(),
        signature: (await algorithm.sign(catalogue, keyPair: other)).bytes,
      );
      expect(
        await repository().refresh(),
        failsWith<CatalogueSignatureRejected>(),
      );
    });

    test('an unsigned catalogue is accepted only outside release', () async {
      await publish(json(), signed: false);
      expect(
        await repository().refresh(),
        failsWith<CatalogueSignatureNotChecked>(),
      );
      expect(await store().read(), isNull);

      final debug = repository(acceptUnchecked: true);
      expect(await debug.refresh(), isA<Ok<Catalogue>>());
      expect((await store().read())!.signature, isNull);
    });

    test('with no key in the app nothing is checked', () async {
      await publish(json());
      expect(
        await repository(keys: []).refresh(),
        failsWith<CatalogueSignatureNotChecked>(),
      );
      expect(
        await repository(keys: [], acceptUnchecked: true).refresh(),
        isA<Ok<Catalogue>>(),
      );
    });
  });

  group('a catalogue that is not accepted', () {
    test('is refused when malformed or of another format', () async {
      await publish(json()..['extra'] = true);
      expect(await repository().refresh(), failsWith<CatalogueRejected>());
      await publish(json()..['format_version'] = 2);
      expect(await repository().refresh(), failsWith<CatalogueUnsupported>());
    });

    test('is refused when it names a URL the policy refuses', () async {
      await publish(syntheticCatalogueJson());
      final result = await repository().refresh();
      expect(result, failsWith<CatalogueRejected>());
      expect(
        '${(result as Failure<Catalogue>).error}',
        contains('https://example.invalid/'),
      );
    });

    test('is refused when its address is one the policy refuses', () async {
      await publish(json());
      expect(
        await repository(policy: UrlPolicy.httpsOnly).refresh(),
        failsWith<CatalogueRejected>(),
      );
      expect(server.requests, isEmpty);
    });

    test('is unreachable when it or its signature fails to arrive', () async {
      expect(await repository().refresh(), failsWith<CatalogueUnreachable>());
      await publish(json());
      server.statuses['/catalogue.json.sig'] = HttpStatus.internalServerError;
      final result = await repository().refresh();
      expect(result, failsWith<CatalogueUnreachable>());
      expect(
        ((result as Failure<Catalogue>).error as CatalogueUnreachable).url,
        server.uri('/catalogue.json.sig'),
      );
    });

    test('leaves the last accepted catalogue served', () async {
      await publish(json());
      final catalogue = repository();
      await catalogue.refresh();
      final accepted = catalogue.catalogue;
      final kept = await store().read();

      await publish(json(tafsirVersion: 3), signature: Uint8List(64));
      expect(
        await catalogue.refresh(),
        failsWith<CatalogueSignatureRejected>(),
      );
      expect(catalogue.catalogue, same(accepted));
      expect((await store().read())!.catalogue, kept!.catalogue);
    });
  });

  group('offline', () {
    test('the kept copy is served when nothing can be fetched', () async {
      await publish(json());
      await repository().refresh();
      await server.close();

      final offline = repository();
      var notified = 0;
      offline.addListener(() => notified++);
      expect(await offline.refresh(), failsWith<CatalogueUnreachable>());
      expect(offline.catalogue!.packs, hasLength(4));
      expect(notified, 1);
    });

    test('the kept copy is served before the fetch ends', () async {
      await publish(json());
      await repository().refresh();
      await publish(json(tafsirVersion: 3));

      final catalogue = repository();
      final seen = <int>[];
      catalogue.addListener(
        () => seen.add(catalogue.catalogue!.firstUseTafsir!.version),
      );
      expect(await catalogue.refresh(), isA<Ok<Catalogue>>());
      expect(seen, [2, 3]);
    });

    test('the kept copy is checked again before it is served', () async {
      await publish(json());
      await repository().refresh();
      final kept = (await store().read())!;
      await store().write(
        catalogueBytes(json(tafsirVersion: 9)),
        kept.signature,
      );
      server.files.clear();

      final offline = repository();
      expect(await offline.refresh(), failsWith<CatalogueUnreachable>());
      expect(offline.catalogue, isNull);
    });

    test('an unsigned kept copy follows the policy too', () async {
      await publish(json(), signed: false);
      await repository(acceptUnchecked: true).refresh();
      server.files.clear();

      expect(repository().catalogue, isNull);
      final release = repository();
      await release.refresh();
      expect(release.catalogue, isNull);
      final debug = repository(acceptUnchecked: true);
      await debug.refresh();
      expect(debug.catalogue, isNotNull);
    });

    test('nothing kept and nothing fetched serves nothing', () async {
      final catalogue = repository();
      expect(await catalogue.refresh(), failsWith<CatalogueUnreachable>());
      expect(catalogue.catalogue, isNull);
    });
  });

  test('a newer version in the catalogue shows as an update', () async {
    InstalledPack installed(int version) => InstalledPack(
      manifest: PackManifest(
        formatVersion: 2,
        id: 'synthetic-tafsir',
        kind: PackKind.tafsir,
        version: version,
        changelog: const [],
        riwaya: 'hafs',
        sources: const [],
        files: const [],
        counts: const TafsirCounts(passages: 1),
        reviews: const [],
      ),
      directory: '/synthetic/$version',
      previousVersion: null,
    );
    ResourceState tafsirState(Catalogue catalogue, int version) => resourcesOf(
      catalogue,
      installed: [installed(version)],
      jobs: const [],
    )[1].state;

    final catalogue = repository();
    await publish(json());
    await catalogue.refresh();
    expect(tafsirState(catalogue.catalogue!, 2), const ResourceDownloaded(2));

    await publish(json(tafsirVersion: 3));
    await catalogue.refresh();
    expect(
      tafsirState(catalogue.catalogue!, 2),
      const ResourceUpdateAvailable(installedVersion: 2, version: 3),
    );
    expect(
      catalogue.catalogue!.pack('synthetic-tafsir')!.changes,
      'Synthetic change summary',
    );
  });
}
