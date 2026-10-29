import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/services/connectivity_service.dart';
import 'package:holyquran/data/services/download_service.dart';
import 'package:holyquran/data/services/free_space_service.dart';
import 'package:holyquran/data/services/installed_packs_store.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';
import 'package:holyquran/domain/models/install_job.dart';
import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/packs/synthetic_pack.dart';

// The installer runs against synthetic packs served by a loopback HTTP
// server, through the real URL check, store and verification. The
// downloader is a fake that fetches over the loopback with HttpClient; the
// plugin's own resume within a file is tested in download_service_test.dart.
// The network, the free space and the signature keys are fakes or are made
// here; no key is real.

/// An HTTP server on 127.0.0.1 serving the files under a directory, with
/// redirects and faults injected per path.
final class _PackServer {
  _PackServer._(this._server, this._root) {
    _server.listen((request) => unawaited(_handle(request)));
  }

  static Future<_PackServer> start(Directory root) async => _PackServer._(
    await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    root,
  );

  final HttpServer _server;
  final Directory _root;
  final List<(String, String)> requests = [];
  final Map<String, String> redirects = {};

  /// How many more `GET`s of a path are served with one byte inverted.
  final Map<String, int> corrupt = {};

  /// The status the next `GET` of a path answers with, once.
  final Map<String, int> failOnce = {};

  Uri uri(String path) =>
      Uri(scheme: 'http', host: '127.0.0.1', port: _server.port, path: path);

  int gets(String path) => requests.where((r) => r == ('GET', path)).length;

  void reset() {
    requests.clear();
    redirects.clear();
    corrupt.clear();
    failOnce.clear();
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    final isGet = request.method == 'GET';
    requests.add((request.method, path));
    final response = request.response;
    if (redirects[path] case final location?) {
      response
        ..statusCode = HttpStatus.found
        ..headers.set(HttpHeaders.locationHeader, location);
      return response.close();
    }
    final file = File('${_root.path}$path');
    if (!await file.exists()) {
      response.statusCode = HttpStatus.notFound;
      return response.close();
    }
    final status = isGet ? failOnce.remove(path) : null;
    if (status != null) {
      response.statusCode = status;
      return response.close();
    }
    final body = await file.readAsBytes();
    if (isGet && (corrupt[path] ?? 0) > 0) {
      corrupt[path] = corrupt[path]! - 1;
      body[body.length ~/ 2] ^= 0xFF;
    }
    response.contentLength = body.length;
    if (isGet) response.add(body);
    return response.close();
  }
}

/// Fetches over HTTP into the download root. [outcomes] answer the next
/// downloads of a file name without a request; a download of a file named
/// in [gates] waits for its gate, and announces it on [reached].
final class _Downloads implements DownloadService {
  _Downloads(this.root);

  final String root;
  final List<FileOrder> orders = [];
  final Map<String, List<FileDownloadOutcome>> outcomes = {};
  final Map<String, Completer<void>> gates = {};
  final StreamController<String> reached = StreamController.broadcast(
    sync: true,
  );
  final List<FileOrder> resumed = [];
  bool pausable = false;

  /// Called as each download starts, with the file name.
  void Function(String name)? onDownload;

  /// Reports to the repository as the downloader would, for the download
  /// that started last.
  void Function(FileTaskUpdate update)? report;
  int active = 0;
  int maxActive = 0;
  final Map<String, Completer<FileDownloadOutcome>> _ends = {};
  final Map<String, Completer<void>> _paused = {};

  List<String> get names => [for (final o in orders) o.path.split('/').last];

  @override
  Future<void> start() async {}

  @override
  Future<FileDownloadOutcome> download(
    FileOrder order,
    void Function(FileTaskUpdate update) onUpdate,
  ) async {
    final name = order.path.split('/').last;
    orders.add(order);
    active++;
    maxActive = max(active, maxActive);
    final ended = _ends[order.path] = Completer();
    try {
      report = onUpdate;
      onDownload?.call(name);
      onUpdate((status: FileTaskStatus.enqueued, progress: null));
      if (outcomes[name] case [final outcome, ...]) {
        outcomes[name]!.removeAt(0);
        return outcome;
      }
      if (gates[name] case final gate?) {
        reached.add(name);
        if (await _until(gate.future, ended) case final outcome?) {
          return outcome;
        }
      }
      if (_paused[order.path] case final paused?) {
        if (await _until(paused.future, ended) case final outcome?) {
          return outcome;
        }
      }
      return await _fetch(order, onUpdate);
    } finally {
      active--;
      _ends.remove(order.path);
    }
  }

  /// Null once [future] completes; the outcome if the download ends first.
  static Future<FileDownloadOutcome?> _until(
    Future<void> future,
    Completer<FileDownloadOutcome> ended,
  ) => Future.any([future.then((_) => null), ended.future]);

  Future<FileDownloadOutcome> _fetch(
    FileOrder order,
    void Function(FileTaskUpdate update) onUpdate,
  ) async {
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(order.url)).close();
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return FileDownloadFailed('synthetic', statusCode: response.statusCode);
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response) {
        bytes.add(chunk);
        onUpdate((status: FileTaskStatus.running, progress: null));
      }
      final target = File('$root/${order.path}');
      await target.parent.create(recursive: true);
      final partial = File('${target.path}.part');
      await partial.writeAsBytes(bytes.takeBytes(), flush: true);
      await partial.rename(target.path);
      return const FileDownloaded();
    } on IOException catch (e) {
      return FileDownloadFailed('$e');
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<bool> pause(FileOrder order) async {
    if (pausable) _paused[order.path] = Completer();
    return pausable;
  }

  @override
  Future<void> resume(FileOrder order) async {
    resumed.add(order);
    _paused.remove(order.path)?.complete();
  }

  @override
  Future<void> cancel(FileOrder order) async {
    _ends[order.path]?.complete(const FileDownloadCanceled());
  }
}

final class _Network implements ConnectivityService {
  _Network(this.kind);

  NetworkKind kind;
  final StreamController<NetworkKind> _changes = StreamController.broadcast();

  void set(NetworkKind value) => _changes.add(kind = value);

  @override
  Future<NetworkKind> current() async => kind;

  @override
  Stream<NetworkKind> get changes => _changes.stream;
}

final class _Space implements FreeSpaceService {
  int? free;

  @override
  Future<int?> freeBytesAt(String directory) async => free;
}

/// Ed25519 over the manifest's exact bytes with a list of accepted public
/// keys (D-080, D-108), as the app's verifier will be; the keys are made by
/// the test.
final class _Ed25519Signatures implements ManifestSignatureVerifier {
  const _Ed25519Signatures(this.keys);

  final List<SimplePublicKey> keys;

  @override
  Future<SignatureCheck> verify({
    required Uint8List manifest,
    required Uint8List? signature,
  }) async {
    if (signature == null) return SignatureCheck.invalid;
    for (final key in keys) {
      if (await Ed25519().verify(
        manifest,
        signature: Signature(signature, publicKey: key),
      )) {
        return SignatureCheck.valid;
      }
    }
    return SignatureCheck.invalid;
  }
}

const _http = UrlPolicy(scheme: 'http');
const _text = 'synthetic-text';
const _other = 'synthetic-other';

void main() {
  late Directory temp;
  late Directory served;
  late _PackServer server;
  late _Ed25519Signatures signatures;
  final httpOverrides = HttpOverrides.current;
  var supports = 0;

  late Directory support;
  late _Downloads downloads;
  late _Network network;
  late _Space space;

  setUpAll(() async {
    HttpOverrides.global = null;
    temp = await Directory.systemTemp.createTemp('pack_install_test');
    served = Directory('${temp.path}/served');
    // buildSyntheticPack's default id is _text.
    await buildSyntheticPack(served);
    await buildSyntheticPack(served, version: 2);
    await buildSyntheticPack(served, version: 3);
    await buildSyntheticPack(served, id: _other);

    final inUse = await Ed25519().newKeyPair();
    final spare = await Ed25519().newKeyPair();
    final unknown = await Ed25519().newKeyPair();
    signatures = _Ed25519Signatures([
      await inUse.extractPublicKey(),
      await spare.extractPublicKey(),
    ]);
    for (final (id, key) in [
      ('synthetic-signed', spare),
      ('synthetic-forged', unknown),
    ]) {
      final pack = await buildSyntheticPack(served, id: id);
      final signature = await Ed25519().sign(
        await pack.manifestFile.readAsBytes(),
        keyPair: key,
      );
      await File(
        '${pack.directory.path}/manifest.json.sig',
      ).writeAsBytes(signature.bytes);
    }
    server = await _PackServer.start(served);
  });

  tearDownAll(() async {
    HttpOverrides.global = httpOverrides;
    await server.close();
    await temp.delete(recursive: true);
  });

  setUp(() async {
    support = await Directory('${temp.path}/support-${supports++}').create();
    downloads = _Downloads(support.path);
    network = _Network(NetworkKind.unmetered);
    space = _Space();
  });

  tearDown(() => server.reset());

  Future<LocalPackInstallRepository> started({
    ManifestSignatureVerifier signatures = const SignatureNotConfigured(),
    bool acceptUnchecked = true,
    UrlPolicy policy = _http,
    void Function(String packId)? onPackChanged,
  }) async {
    final repository = LocalPackInstallRepository(
      openStore: () async => InstalledPacksStore(support),
      downloads: downloads,
      urlCheck: const HttpUrlCheck(),
      connectivity: network,
      freeSpace: space,
      files: const PackFileService(),
      verifier: LocalPackRepository(
        files: const PackFileService(),
        signatures: signatures,
      ),
      policy: policy,
      acceptUnchecked: acceptUnchecked,
      onPackChanged: onPackChanged,
    );
    addTearDown(repository.dispose);
    expect(await repository.start(), isA<Ok<void>>());
    return repository;
  }

  Future<InstallRequest> requestFor(
    String id,
    int version, {
    bool wifiOnly = false,
    String? manifestSha256,
    Uri? manifestUrl,
    Map<String, Uri>? files,
  }) async {
    final base = '/$id/$version';
    final manifest = await File(
      '${served.path}$base/manifest.json',
    ).readAsBytes();
    final signed = await File('${served.path}$base/manifest.json.sig').exists();
    return InstallRequest(
      packId: id,
      version: version,
      manifest: RemoteFile(
        url: manifestUrl ?? server.uri('$base/manifest.json'),
        sha256: manifestSha256 ?? sha256.convert(manifest).toString(),
        bytes: manifest.length,
      ),
      signature: signed ? server.uri('$base/manifest.json.sig') : null,
      files: files ?? {textFileName: server.uri('$base/text.sqlite')},
      wifiOnly: wifiOnly,
    );
  }

  Future<Result<InstalledPack>> install(
    LocalPackInstallRepository repository,
    String id,
    int version,
  ) async => repository.install(await requestFor(id, version));

  bool exists(String path) =>
      FileSystemEntity.typeSync('${support.path}/$path') !=
      FileSystemEntityType.notFound;

  InstallState? stateOf(PackInstallRepository repository, String id) =>
      repository.jobs.where((j) => j.request.packId == id).firstOrNull?.state;

  Future<void> until(PackInstallRepository repository, bool Function() test) {
    final done = Completer<void>();
    void check() {
      if (test() && !done.isCompleted) done.complete();
    }

    repository.addListener(check);
    check();
    return done.future
        .timeout(const Duration(seconds: 20))
        .whenComplete(() => repository.removeListener(check));
  }

  Matcher installedAs(String id, int version, {int? previous}) =>
      isA<Ok<InstalledPack>>().having(
        (r) => (r.value.id, r.value.version, r.value.previousVersion),
        'pack',
        (id, version, previous),
      );

  Matcher failedWith(Matcher failure) =>
      isA<Failure<Object?>>().having((f) => f.error, 'error', failure);

  Future<void> expectServedBytes(String id, int version) async {
    for (final name in [manifestFileName, textFileName]) {
      expect(
        await File('${support.path}/packs/$id/$version/$name').readAsBytes(),
        await File('${served.path}/$id/$version/$name').readAsBytes(),
        reason: name,
      );
    }
  }

  group('install', () {
    test('fetches, verifies and activates a pack', () async {
      final repository = await started();
      final states = <Type>[];
      repository.addListener(() {
        if (stateOf(repository, _text) case final state?) {
          states.add(state.runtimeType);
        }
      });

      final result = await install(repository, _text, 1);

      expect(result, installedAs(_text, 1));
      expect(
        (result as Ok<InstalledPack>).value.directory,
        '${support.path}/packs/$_text/1',
      );
      await expectServedBytes(_text, 1);
      expect([for (final p in repository.installed) p.id], [_text]);
      expect(repository.jobs, isEmpty);
      expect(exists('pack-staging/$_text/1'), isFalse);
      expect(
        states,
        containsAllInOrder([InstallDownloading, InstallVerifying]),
      );
      expect(downloads.names, [manifestFileName, textFileName]);
      expect(
        downloads.orders.first.path,
        'pack-staging/$_text/1/manifest.json',
      );
      expect(server.gets('/$_text/1/manifest.json'), 1);
      expect(server.gets('/$_text/1/text.sqlite'), 1);
    });

    test('after a network failure, resumes without fetching again what '
        'arrived', () async {
      final repository = await started();
      server.failOnce['/$_text/1/text.sqlite'] = HttpStatus.serviceUnavailable;

      expect(
        await install(repository, _text, 1),
        failedWith(
          isA<DownloadFailed>()
              .having((f) => f.file, 'file', textFileName)
              .having(
                (f) => f.statusCode,
                'statusCode',
                HttpStatus.serviceUnavailable,
              ),
        ),
      );
      expect(exists('pack-staging/$_text/1/manifest.json'), isTrue);
      expect(stateOf(repository, _text), isA<InstallFailed>());

      expect(await install(repository, _text, 1), installedAs(_text, 1));
      expect(server.gets('/$_text/1/manifest.json'), 1);
      expect(server.gets('/$_text/1/text.sqlite'), 2);
      expect(repository.jobs, isEmpty);
    });

    test('a file corrupted once is rejected and fetched again', () async {
      final repository = await started();
      server.corrupt['/$_text/1/text.sqlite'] = 1;

      expect(await install(repository, _text, 1), installedAs(_text, 1));
      expect(server.gets('/$_text/1/text.sqlite'), 2);
      await expectServedBytes(_text, 1);
    });

    test(
      'a file corrupted twice is refused and the active version stays',
      () async {
        final repository = await started();
        expect(await install(repository, _text, 1), installedAs(_text, 1));
        server.corrupt['/$_text/2/text.sqlite'] = 2;

        expect(
          await install(repository, _text, 2),
          failedWith(
            isA<FileRejected>().having((f) => f.file, 'file', textFileName),
          ),
        );
        expect(server.gets('/$_text/2/text.sqlite'), 2);
        expect(
          [for (final p in repository.installed) (p.id, p.version)],
          [(_text, 1)],
        );
        expect(exists('packs/$_text/2'), isFalse);
        expect(exists('pack-staging/$_text/2'), isFalse);
        await expectServedBytes(_text, 1);
      },
    );

    test('a manifest that differs from the request is refused after a '
        'second fetch', () async {
      final repository = await started();
      expect(
        await repository.install(
          await requestFor(_text, 1, manifestSha256: 'f' * 64),
        ),
        failedWith(isA<ManifestRejected>()),
      );
      expect(server.gets('/$_text/1/manifest.json'), 2);
      expect(server.gets('/$_text/1/text.sqlite'), 0);
      expect(exists('pack-staging/$_text/1'), isFalse);
      expect(repository.installed, isEmpty);
    });

    test('a manifest corrupted once is fetched again', () async {
      final repository = await started();
      server.corrupt['/$_text/1/manifest.json'] = 1;
      expect(await install(repository, _text, 1), installedAs(_text, 1));
      expect(server.gets('/$_text/1/manifest.json'), 2);
    });

    test('a file the request has no URL for is refused', () async {
      final repository = await started();
      expect(
        await repository.install(await requestFor(_text, 1, files: {})),
        failedWith(
          isA<FileUrlMissing>().having((f) => f.file, 'file', textFileName),
        ),
      );
    });
  });

  group('signatures', () {
    test('a pack signed by the spare key is accepted where only a valid '
        'signature is', () async {
      final repository = await started(
        signatures: signatures,
        acceptUnchecked: false,
      );
      expect(
        await install(repository, 'synthetic-signed', 1),
        installedAs('synthetic-signed', 1),
      );
      expect(exists('packs/synthetic-signed/1/manifest.json.sig'), isTrue);
    });

    test('a signature by an unknown key is refused', () async {
      final repository = await started(signatures: signatures);
      expect(
        await install(repository, 'synthetic-forged', 1),
        failedWith(
          isA<VerificationFailed>().having(
            (f) => f.failure,
            'failure',
            isA<SignatureRejected>(),
          ),
        ),
      );
      expect(exists('pack-staging/synthetic-forged/1'), isFalse);
      expect(repository.installed, isEmpty);
    });

    test('an unchecked signature is refused in a release build, accepted '
        'otherwise', () async {
      final release = await started(acceptUnchecked: false);
      expect(
        await install(release, _text, 1),
        failedWith(isA<SignatureNotChecked>()),
      );
      expect(release.installed, isEmpty);
      expect(exists('pack-staging/$_text/1'), isFalse);

      final debug = await started();
      expect(await install(debug, _text, 1), installedAs(_text, 1));
    });
  });

  group('URLs', () {
    // The app's policy is https only, and every redirect must keep the
    // scheme of the first URL. The loopback server speaks http, so these
    // tests allow http: a redirect that stays on http is followed, and one
    // to https is a change of scheme, refused by the same rule that refuses
    // a redirect from https to http in the app.
    test('a redirect that keeps the scheme is followed', () async {
      final repository = await started();
      server.redirects['/release/manifest.json'] = '/$_text/1/manifest.json';
      expect(
        await repository.install(
          await requestFor(
            _text,
            1,
            manifestUrl: server.uri('/release/manifest.json'),
          ),
        ),
        installedAs(_text, 1),
      );
    });

    test('a redirect that changes the scheme is refused', () async {
      final repository = await started();
      final elsewhere = server
          .uri('/$_text/1/text.sqlite')
          .replace(scheme: 'https');
      server.redirects['/release/text.sqlite'] = elsewhere.toString();
      expect(
        await repository.install(
          await requestFor(
            _text,
            1,
            files: {textFileName: server.uri('/release/text.sqlite')},
          ),
        ),
        failedWith(
          isA<RedirectRefused>()
              .having((f) => f.from, 'from', server.uri('/release/text.sqlite'))
              .having((f) => f.to, 'to', elsewhere),
        ),
      );
      expect(downloads.names, [manifestFileName]);
      expect(server.gets('/$_text/1/text.sqlite'), 0);
    });

    test(
      'an http URL is refused under the app\'s policy, with no request',
      () async {
        final repository = await started(policy: UrlPolicy.httpsOnly);
        final request = await requestFor(_text, 1);
        expect(
          await repository.install(request),
          failedWith(
            isA<UrlNotAllowed>().having(
              (f) => f.url,
              'url',
              request.manifest.url,
            ),
          ),
        );
        expect(server.requests, isEmpty);
        expect(downloads.orders, isEmpty);
        expect(repository.jobs, isEmpty);
      },
    );

    test('an invalid pack id is refused', () async {
      final repository = await started();
      final request = await requestFor(_text, 1);
      expect(
        await repository.install(
          InstallRequest(
            packId: '../$_text',
            version: 1,
            manifest: request.manifest,
            signature: null,
            files: request.files,
            wifiOnly: false,
          ),
        ),
        failedWith(isA<InvalidPackId>()),
      );
      expect(server.requests, isEmpty);
    });
  });

  group('rollback and delete', () {
    test('rollback restores the previous version, and can be undone', () async {
      final repository = await started();
      expect(await install(repository, _text, 1), installedAs(_text, 1));
      expect(
        await install(repository, _text, 2),
        installedAs(_text, 2, previous: 1),
      );

      expect(
        await repository.rollback(_text),
        installedAs(_text, 1, previous: 2),
      );
      expect(
        [for (final p in repository.installed) (p.version, p.previousVersion)],
        [(1, 2)],
      );
      expect(
        await repository.rollback(_text),
        installedAs(_text, 2, previous: 1),
      );
      expect(
        await repository.rollback(_other),
        failedWith(isA<NoPreviousVersion>()),
      );
    });

    test('tells of a pack installed, rolled back or deleted, and of no '
        'other', () async {
      final changed = <String>[];
      final repository = await started(onPackChanged: changed.add);

      await install(repository, _text, 1);
      await install(repository, _text, 1);
      expect(changed, [_text]);
      await install(repository, _text, 2);
      await repository.rollback(_text);
      await repository.rollback(_other);
      await repository.delete(_text);

      expect(changed, [_text, _text, _text, _text]);
    });

    test('tells of a deleted or rolled back pack even when the read of the '
        'packs that follows fails', () async {
      final changed = <String>[];
      final repository = await started(onPackChanged: changed.add);
      await install(repository, _text, 1);
      await install(repository, _text, 2);
      await install(repository, _other, 1);
      changed.clear();
      // A manifest that is a folder makes reading the installed packs throw.
      final manifest = File('${support.path}/packs/$_other/1/manifest.json');
      await manifest.delete();
      await Directory(manifest.path).create();

      expect(await repository.rollback(_text), failedWith(isA<StoreFailed>()));
      expect(changed, [_text]);
      expect(await repository.delete(_text), failedWith(isA<StoreFailed>()));
      expect(changed, [_text, _text]);
      expect(exists('packs/$_text'), isFalse);
    });

    test('does not tell of a delete that failed', () async {
      final changed = <String>[];
      final repository = await started(onPackChanged: changed.add);

      expect(
        await repository.delete('Not A Pack Id'),
        failedWith(isA<InvalidPackId>()),
      );

      expect(changed, isEmpty);
    });

    test('an installed version, active or previous, is refused', () async {
      final repository = await started();
      await install(repository, _text, 1);
      await install(repository, _text, 2);
      for (final version in [1, 2]) {
        expect(
          await install(repository, _text, version),
          failedWith(
            isA<AlreadyInstalled>().having(
              (f) => f.version,
              'version',
              version,
            ),
          ),
        );
      }
      expect(
        await install(repository, _text, 3),
        installedAs(_text, 3, previous: 2),
      );
      expect(exists('packs/$_text/1'), isFalse);
    });

    test(
      'delete leaves other packs and every other folder untouched',
      () async {
        final repository = await started();
        await install(repository, _text, 1);
        await install(repository, _text, 2);
        await install(repository, _other, 1);
        await File(
          '${support.path}/user.sqlite',
        ).writeAsBytes(List.generate(4096, (i) => i * 7 & 0xFF));
        final foreign = File('${support.path}/packs/synthetic-foreign/1/x.bin');
        await foreign.create(recursive: true);
        await foreign.writeAsBytes([1, 2, 3]);
        await Directory(
          '${support.path}/pack-staging/$_text/9',
        ).create(recursive: true);

        // A file's URI separates its segments with `/` on every platform.
        Future<Map<String, List<int>>> others() async => {
          await for (final entity in support.list(recursive: true))
            if (entity is File &&
                !entity.uri.path.contains('/packs/$_text/') &&
                !entity.uri.path.contains('/pack-staging/$_text/'))
              entity.path: await entity.readAsBytes(),
        };
        final before = await others();
        expect(before.keys, hasLength(5));

        expect(await repository.delete(_text), isA<Ok<void>>());

        expect(await others(), before);
        expect(exists('packs/$_text'), isFalse);
        expect(exists('pack-staging/$_text'), isFalse);
        expect([for (final p in repository.installed) p.id], [_other]);
        expect(await repository.delete('synthetic-foreign'), isA<Ok<void>>());
        expect(await foreign.readAsBytes(), [1, 2, 3]);
      },
    );

    test(
      'a pack with a job in the queue is neither rolled back nor deleted',
      () async {
        final repository = await started();
        downloads.gates[textFileName] = Completer();
        final installing = install(repository, _text, 1);
        await downloads.reached.stream.first;
        expect(
          await repository.rollback(_text),
          failedWith(isA<AlreadyQueued>()),
        );
        expect(
          await repository.delete(_text),
          failedWith(isA<AlreadyQueued>()),
        );
        downloads.gates[textFileName]!.complete();
        expect(await installing, installedAs(_text, 1));
      },
    );
  });

  group('the queue', () {
    test('runs one job at a time, in order', () async {
      final repository = await started();
      final requests = [
        await requestFor(_text, 1),
        await requestFor(_other, 1),
      ];
      final results = await Future.wait(requests.map(repository.install));
      expect(results[0], installedAs(_text, 1));
      expect(results[1], installedAs(_other, 1));
      expect(downloads.maxActive, 1);
      expect(
        [for (final o in downloads.orders) o.path.split('/')[1]],
        [_text, _text, _other, _other],
      );
    });

    test('refuses a pack already in the queue', () async {
      final repository = await started();
      downloads.gates[textFileName] = Completer();
      final first = install(repository, _text, 1);
      await downloads.reached.stream.first;
      expect(
        await install(repository, _text, 2),
        failedWith(isA<AlreadyQueued>()),
      );
      downloads.gates[textFileName]!.complete();
      expect(await first, installedAs(_text, 1));
    });

    test('a Wi-Fi-only job waits for Wi-Fi, then goes on', () async {
      network.kind = NetworkKind.other;
      final repository = await started();
      final installing = repository.install(
        await requestFor(_text, 1, wifiOnly: true),
      );
      await until(
        repository,
        () => stateOf(repository, _text) is InstallWaitingForNetwork,
      );
      expect(
        (stateOf(repository, _text)! as InstallWaitingForNetwork).wifiOnly,
        isTrue,
      );
      expect(downloads.orders, isEmpty);
      expect(server.requests, isEmpty);

      network.set(NetworkKind.unmetered);
      expect(await installing, installedAs(_text, 1));
      expect(downloads.orders.first.wifiOnly, isTrue);
    });

    test('a Wi-Fi-only download shows the wait when Wi-Fi goes', () async {
      downloads.gates[textFileName] = Completer();
      final repository = await started();
      final installing = repository.install(
        await requestFor(_text, 1, wifiOnly: true),
      );
      await downloads.reached.stream.first;
      network.set(NetworkKind.other);
      await pumpEventQueue();
      expect(stateOf(repository, _text), isA<InstallWaitingForNetwork>());
      downloads.report!((status: FileTaskStatus.retrying, progress: null));
      expect(stateOf(repository, _text), isA<InstallWaitingForNetwork>());

      network.set(NetworkKind.unmetered);
      await pumpEventQueue();
      downloads.report!((status: FileTaskStatus.running, progress: null));
      expect(stateOf(repository, _text), isA<InstallDownloading>());
      downloads.gates[textFileName]!.complete();
      expect(await installing, installedAs(_text, 1));
    });

    test('a download that failed while the network was gone is fetched again '
        'once it returns', () async {
      downloads
        ..outcomes[textFileName] = [const FileDownloadFailed('synthetic')]
        ..onDownload = (name) {
          if (name != textFileName) return;
          network.kind = NetworkKind.none;
          downloads.onDownload = null;
        };
      final repository = await started();
      final installing = install(repository, _text, 1);
      await until(
        repository,
        () => stateOf(repository, _text) is InstallWaitingForNetwork,
      );
      expect(downloads.names, [manifestFileName, textFileName]);

      network.set(NetworkKind.other);
      expect(await installing, installedAs(_text, 1));
      expect(downloads.names, [manifestFileName, textFileName, textFileName]);
    });

    test('a failure with the network up ends the job', () async {
      downloads.outcomes[textFileName] = [
        const FileDownloadFailed('synthetic'),
      ];
      final repository = await started();
      expect(
        await install(repository, _text, 1),
        failedWith(
          isA<DownloadFailed>().having((f) => f.statusCode, 'statusCode', null),
        ),
      );
      expect(exists('pack-staging/$_text/1/manifest.json'), isTrue);
    });

    test('any job waits while there is no network', () async {
      network.kind = NetworkKind.none;
      final repository = await started();
      final installing = install(repository, _text, 1);
      await until(
        repository,
        () => stateOf(repository, _text) is InstallWaitingForNetwork,
      );
      expect(downloads.orders, isEmpty);
      network.set(NetworkKind.other);
      expect(await installing, installedAs(_text, 1));
    });

    test('low space stops the queue until a resume finds room', () async {
      space.free = 1000;
      final repository = await started();
      final requests = [
        await requestFor(_text, 1),
        await requestFor(_other, 1),
      ];
      final first = repository.install(requests[0]);
      final second = repository.install(requests[1]);
      await until(
        repository,
        () => stateOf(repository, _text) is InstallStoppedLowSpace,
      );
      final stopped = stateOf(repository, _text)! as InstallStoppedLowSpace;
      final textBytes = await File(
        '${served.path}/$_text/1/text.sqlite',
      ).length();
      expect(stopped.neededBytes, textBytes + packSpaceReserveBytes);
      expect(stopped.freeBytes, 1000);
      expect(stateOf(repository, _other), isA<InstallQueued>());
      expect(downloads.names, [manifestFileName]);

      await repository.resume(_text);
      await until(
        repository,
        () => stateOf(repository, _text) is InstallStoppedLowSpace,
      );
      expect(downloads.names, [manifestFileName]);

      space.free = textBytes + packSpaceReserveBytes;
      await repository.resume(_text);
      expect(await first, installedAs(_text, 1));
      expect(await second, installedAs(_other, 1));
    });

    test('low space reported by the downloader stops the job too', () async {
      downloads.outcomes[textFileName] = [const FileDownloadNoSpace()];
      final repository = await started();
      final installing = install(repository, _text, 1);
      await until(
        repository,
        () => stateOf(repository, _text) is InstallStoppedLowSpace,
      );
      expect(
        (stateOf(repository, _text)! as InstallStoppedLowSpace).freeBytes,
        isNull,
      );
      await repository.resume(_text);
      expect(await installing, installedAs(_text, 1));
      expect(downloads.names, [manifestFileName, textFileName, textFileName]);
    });

    test('an unknown free space never stops a job', () async {
      space.free = null;
      final repository = await started();
      expect(await install(repository, _text, 1), installedAs(_text, 1));
    });

    test(
      'pause holds a download the downloader can pause; resume goes on',
      () async {
        downloads.pausable = true;
        downloads.gates[textFileName] = Completer();
        final repository = await started();
        final installing = install(repository, _text, 1);
        await downloads.reached.stream.first;

        await repository.pause(_text);
        expect(stateOf(repository, _text), isA<InstallPaused>());
        downloads.gates[textFileName]!.complete();
        await pumpEventQueue();
        expect(stateOf(repository, _text), isA<InstallPaused>());

        await repository.resume(_text);
        expect(await installing, installedAs(_text, 1));
        expect(downloads.resumed, hasLength(1));
        expect(server.gets('/$_text/1/text.sqlite'), 1);
      },
    );

    test('pause ends a download the downloader cannot pause; resume starts '
        'that file again', () async {
      downloads.gates[textFileName] = Completer();
      final repository = await started();
      final installing = install(repository, _text, 1);
      await downloads.reached.stream.first;

      await repository.pause(_text);
      await pumpEventQueue();
      expect(stateOf(repository, _text), isA<InstallPaused>());
      expect(downloads.active, 0);

      downloads.gates.remove(textFileName);
      await repository.resume(_text);
      expect(await installing, installedAs(_text, 1));
      expect(downloads.names, [manifestFileName, textFileName, textFileName]);
    });

    test('a resume while the pause is under way keeps the download', () async {
      downloads.gates[textFileName] = Completer();
      final repository = await started();
      final installing = install(repository, _text, 1);
      await downloads.reached.stream.first;

      final pausing = repository.pause(_text);
      await repository.resume(_text);
      await pausing;
      expect(downloads.active, 1);
      downloads.gates[textFileName]!.complete();
      expect(await installing, installedAs(_text, 1));
      expect(downloads.names, [manifestFileName, textFileName]);
    });

    test('a paused job holds the queue', () async {
      downloads.gates[textFileName] = Completer();
      final repository = await started();
      final first = install(repository, _text, 1);
      await downloads.reached.stream.first;
      await repository.pause(_text);
      final second = install(repository, _other, 1);
      await until(repository, () => stateOf(repository, _other) != null);
      await pumpEventQueue();
      expect(stateOf(repository, _other), isA<InstallQueued>());
      expect(downloads.orders.where((o) => o.path.contains(_other)), isEmpty);

      downloads.gates.remove(textFileName);
      await repository.resume(_text);
      expect(await first, installedAs(_text, 1));
      expect(await second, installedAs(_other, 1));
    });

    test('cancel ends the running job and discards its staging', () async {
      downloads.gates[textFileName] = Completer();
      final repository = await started();
      final installing = install(repository, _text, 1);
      await downloads.reached.stream.first;

      await repository.cancel(_text);
      expect(await installing, failedWith(isA<InstallCancelled>()));
      expect(exists('pack-staging/$_text/1'), isFalse);
      expect(repository.jobs, isEmpty);
      expect(repository.installed, isEmpty);
    });

    test('cancel removes a queued job before it starts', () async {
      downloads.gates[textFileName] = Completer();
      final repository = await started();
      final first = install(repository, _text, 1);
      await downloads.reached.stream.first;
      final second = install(repository, _other, 1);
      await until(repository, () => stateOf(repository, _other) != null);

      await repository.cancel(_other);
      expect(await second, failedWith(isA<InstallCancelled>()));
      expect([for (final j in repository.jobs) j.request.packId], [_text]);
      downloads.gates[textFileName]!.complete();
      expect(await first, installedAs(_text, 1));
      expect(downloads.orders.where((o) => o.path.contains(_other)), isEmpty);
    });

    test('a failed job is listed until cancelled; it does not block the '
        'queue', () async {
      final repository = await started();
      server.failOnce['/$_text/1/manifest.json'] = HttpStatus.notFound;
      final requests = [
        await requestFor(_text, 1),
        await requestFor(_other, 1),
      ];
      final results = await Future.wait(requests.map(repository.install));
      expect(
        results[0],
        failedWith(
          isA<DownloadFailed>().having(
            (f) => f.statusCode,
            'statusCode',
            HttpStatus.notFound,
          ),
        ),
      );
      expect(results[1], installedAs(_other, 1));
      final failed = repository.jobs.single;
      expect(failed.request.packId, _text);
      expect((failed.state as InstallFailed).failure, isA<DownloadFailed>());

      await repository.cancel(_text);
      expect(repository.jobs, isEmpty);
    });
  });

  group('start', () {
    test('a store that cannot open is a failure, not a throw', () async {
      final repository = LocalPackInstallRepository(
        openStore: () async =>
            throw const FileSystemException('synthetic failure'),
        downloads: downloads,
        urlCheck: const HttpUrlCheck(),
        connectivity: network,
        freeSpace: space,
        files: const PackFileService(),
        verifier: const LocalPackRepository(
          files: PackFileService(),
          signatures: SignatureNotConfigured(),
        ),
        policy: _http,
        acceptUnchecked: true,
      );
      addTearDown(repository.dispose);

      expect(await repository.start(), failedWith(isA<FileSystemException>()));
      expect(await repository.started, failedWith(isA<FileSystemException>()));
      expect(
        await install(repository, _text, 1),
        failedWith(isA<FileSystemException>()),
      );
      expect(
        await repository.rollback(_text),
        failedWith(isA<FileSystemException>()),
      );
      expect(server.requests, isEmpty);
    });

    test('an Error in the start is rethrown, and the start still completes '
        'as a failure', () async {
      final repository = LocalPackInstallRepository(
        openStore: () async => throw StateError('synthetic bug'),
        downloads: downloads,
        urlCheck: const HttpUrlCheck(),
        connectivity: network,
        freeSpace: space,
        files: const PackFileService(),
        verifier: const LocalPackRepository(
          files: PackFileService(),
          signatures: SignatureNotConfigured(),
        ),
        policy: _http,
        acceptUnchecked: true,
      );
      addTearDown(repository.dispose);

      await expectLater(repository.start(), throwsStateError);

      expect(await repository.started, failedWith(isA<StoreFailed>()));
      expect(
        await install(repository, _text, 1),
        failedWith(isA<StoreFailed>()),
      );
    });

    test('lists the installed packs and names one whose manifest is '
        'unreadable', () async {
      final first = await started();
      await install(first, _text, 1);
      await install(first, _other, 1);
      await File(
        '${support.path}/packs/$_other/1/manifest.json',
      ).writeAsString('synthetic, not a manifest');

      final repository = LocalPackInstallRepository(
        openStore: () async => InstalledPacksStore(support),
        downloads: downloads,
        urlCheck: const HttpUrlCheck(),
        connectivity: network,
        freeSpace: space,
        files: const PackFileService(),
        verifier: const LocalPackRepository(
          files: PackFileService(),
          signatures: SignatureNotConfigured(),
        ),
        policy: _http,
        acceptUnchecked: true,
      );
      addTearDown(repository.dispose);
      expect(await repository.start(), failedWith(isA<ManifestUnreadable>()));
      expect([for (final p in repository.installed) p.id], [_text]);
      expect(
        await install(repository, _text, 2),
        installedAs(_text, 2, previous: 1),
      );
    });
  });
}
