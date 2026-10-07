import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';

import '../../testing/packs/synthetic_pack.dart';
import 'background_downloader_adapter.dart';
import 'downloader.dart';
import 'filler_pack.dart';
import 'loopback_pack_server.dart';
import 'pack_download_queue.dart';
import 'pack_store.dart';
import 'test_downloader.dart';

// The queue runs on the real adapter (background_downloader's desktop path)
// against the loopback server, with synthetic packs only. Outcomes only the
// native downloaders produce (Wi-Fi wait, low space) come from a fake.

const _verifier = LocalPackRepository(
  files: PackFileService(),
  signatures: SignatureNotConfigured(),
);

/// Serves files from a directory by URL path, without HTTP; reports what a
/// script says for the paths it names.
final class _ScriptedDownloader implements SpikeDownloader {
  _ScriptedDownloader(this.served, this.script);

  final Directory served;
  final Map<String, (List<DownloadState>, DownloadOutcome)> script;
  final List<String> calls = [];

  @override
  Future<DownloadOutcome> download(
    Uri url,
    File target, {
    required bool wifiOnly,
    DownloadListener? onProgress,
  }) async {
    final path = url.path.substring(1);
    calls.add(path);
    if (script[path] case (final states, final outcome)) {
      for (final state in states) {
        onProgress?.call(DownloadProgress(state));
      }
      return outcome;
    }
    final source = File('${served.path}/$path');
    if (!await source.exists()) return const DownloadNotFound();
    await source.copy(target.path);
    return const DownloadCompleted();
  }
}

void main() {
  late Directory temp;
  late Directory served;
  late FileDownloader plugin;
  late LoopbackPackServer server;
  late Directory storeRoot;
  late PackStore store;
  late PackDownloadQueue queue;
  late List<QueueEvent> events;

  setUpAll(() async {
    HttpOverrides.global = null;
    temp = await Directory.systemTemp.createTemp('s5_queue');
    plugin = await startDesktopDownloaderForTests(temp);
    served = Directory('${temp.path}/served');
    await buildSyntheticPack(served);
    await buildSyntheticPack(
      served,
      version: 2,
      surahs: fillerSurahs(bytes: 40000, tag: 'v2'),
    );
    await buildSyntheticPack(served, id: 'synthetic-other');
    final signed = await buildSyntheticPack(served, id: 'synthetic-signed');
    await File(
      '${signed.directory.path}/manifest.json.sig',
    ).writeAsBytes(List.generate(64, (i) => i));
    await buildSyntheticPack(
      served,
      id: 'synthetic-filler',
      surahs: fillerSurahs(bytes: 3 << 20, tag: 'large'),
    );
    server = await LoopbackPackServer.start(served);
  });

  tearDownAll(() async {
    stopDesktopDownloaderForTests();
    await server.close();
    await temp.delete(recursive: true);
  });

  PackDownloadQueue queueOn(SpikeDownloader downloader) {
    final created = PackDownloadQueue(
      downloader: downloader,
      store: store,
      verifier: _verifier,
    );
    created.events.listen(events.add);
    return created;
  }

  setUp(() async {
    storeRoot = await Directory(
      '${temp.path}/store-${DateTime.now().microsecondsSinceEpoch}',
    ).create();
    store = PackStore(storeRoot);
    events = [];
    queue = queueOn(BackgroundDownloaderAdapter(plugin, retries: 2));
  });

  tearDown(() async {
    server.clearFaults();
    await queue.close();
  });

  PackRequest request(String id, int version) => PackRequest(
    id: id,
    version: version,
    base: server.uriOf('$id/$version/'),
    wifiOnly: false,
  );

  Future<String> digest(String path) async =>
      sha256.convert(await File(path).readAsBytes()).toString();

  Future<void> expectInstalledAsServed(String id, int version) async {
    for (final name in [manifestFileName, textFileName]) {
      expect(
        await digest('${store.directoryOf(id, version).path}/$name'),
        await digest('${served.path}/$id/$version/$name'),
        reason: name,
      );
    }
  }

  List<ServedRequest> requestsFor(String path, int from) =>
      server.requests.skip(from).where((r) => r.path == path).toList();

  test('downloads, verifies and activates a pack; an absent signature is '
      'allowed and flagged as not checked', () async {
    final outcome = await queue.enqueue(request('synthetic-text', 1));
    expect(outcome, isA<PackActivated>());
    outcome as PackActivated;
    expect(outcome.versions, (active: 1, previous: null));
    expect(outcome.signatureChecked, isFalse);
    expect(await store.currentVersion('synthetic-text'), 1);
    await expectInstalledAsServed('synthetic-text', 1);
    expect(
      await File(
        '${store.directoryOf('synthetic-text', 1).path}/manifest.json.sig',
      ).exists(),
      isFalse,
    );
    expect(
      await Directory('${storeRoot.path}/staging/synthetic-text/1').exists(),
      isFalse,
    );
    expect(
      [
        for (final e in events)
          if (e is! FileProgressed) e.runtimeType,
      ],
      [
        PackQueued,
        PackStarted,
        FileFinished,
        FileFinished,
        FileFinished,
        PackFinished,
      ],
    );
    expect(
      [
        for (final e in events.whereType<FileFinished>())
          (e.file, e.outcome.runtimeType),
      ],
      [
        (manifestFileName, DownloadCompleted),
        ('manifest.json.sig', DownloadNotFound),
        (textFileName, DownloadCompleted),
      ],
    );
  });

  test('a signature file the server has is kept with the pack', () async {
    final outcome = await queue.enqueue(request('synthetic-signed', 1));
    expect(outcome, isA<PackActivated>());
    expect(
      await digest(
        '${store.directoryOf('synthetic-signed', 1).path}/manifest.json.sig',
      ),
      await digest('${served.path}/synthetic-signed/1/manifest.json.sig'),
    );
  });

  test('a connection dropped after N bytes is resumed with Range; the bytes '
      'served stay within the size plus one chunk', () async {
    const path = 'synthetic-filler/1/$textFileName';
    final size = await File('${served.path}/$path').length();
    const cut = 3 << 19;
    server.inject(path, const DropAfter(cut));
    final from = server.requests.length;
    final outcome = await queue.enqueue(request('synthetic-filler', 1));
    expect(outcome, isA<PackActivated>());
    await expectInstalledAsServed('synthetic-filler', 1);
    final requests = requestsFor(path, from);
    expect(requests, hasLength(2));
    expect(requests.first.dropped, isTrue);
    expect(requests.last.statusCode, HttpStatus.partialContent);
    expect(requests.last.range, matches(RegExp(r'^bytes=\d+-$')));
    expect(
      requests.fold<int>(0, (sum, r) => sum + r.bytes),
      lessThanOrEqualTo(size + (64 << 10)),
    );
    expect(
      events.whereType<FileProgressed>().map((e) => e.progress.state),
      contains(DownloadState.retrying),
    );
  });

  test(
    'a file corrupted once is rejected, fetched again and activated',
    () async {
      const path = 'synthetic-text/1/$textFileName';
      final size = await File('${served.path}/$path').length();
      server.inject(path, CorruptByte(size ~/ 2));
      final from = server.requests.length;
      final outcome = await queue.enqueue(request('synthetic-text', 1));
      expect(outcome, isA<PackActivated>());
      await expectInstalledAsServed('synthetic-text', 1);
      expect(requestsFor(path, from), hasLength(2));
      expect(
        [
          for (final e in events.whereType<FileRejected>())
            (e.file, e.willRetry),
        ],
        [(textFileName, true)],
      );
    },
  );

  test('a file corrupted twice is not activated; the previous version stays '
      'current and staging is deleted', () async {
    expect(
      await queue.enqueue(request('synthetic-text', 1)),
      isA<PackActivated>(),
    );
    const path = 'synthetic-text/2/$textFileName';
    final size = await File('${served.path}/$path').length();
    server.inject(path, CorruptByte(size ~/ 2), times: 2);
    final outcome = await queue.enqueue(request('synthetic-text', 2));
    expect(outcome, isA<PackNotActivated>());
    outcome as PackNotActivated;
    expect(outcome.reason, NotActivatedReason.verification);
    expect(outcome.detail, contains('FileHashMismatch'));
    expect(await store.versionsOf('synthetic-text'), (
      active: 1,
      previous: null,
    ));
    expect(await store.hasVersion('synthetic-text', 2), isFalse);
    expect(
      await Directory('${storeRoot.path}/staging/synthetic-text/2').exists(),
      isFalse,
    );
    expect(
      [for (final e in events.whereType<FileRejected>()) e.willRetry],
      [true, false],
    );
  });

  test('updates v1 to v2, then rolls back to v1', () async {
    await queue.enqueue(request('synthetic-text', 1));
    final update = await queue.enqueue(request('synthetic-text', 2));
    expect((update as PackActivated).versions, (active: 2, previous: 1));
    await expectInstalledAsServed('synthetic-text', 2);
    await expectInstalledAsServed('synthetic-text', 1);
    await store.rollback('synthetic-text');
    expect(await store.currentVersion('synthetic-text'), 1);
    await expectInstalledAsServed('synthetic-text', 1);
  });

  test('two queued packs never overlap', () async {
    server
      ..inject('synthetic-text/1/$textFileName', const Throttle(100000))
      ..inject('synthetic-other/1/$textFileName', const Throttle(100000));
    final from = server.requests.length;
    final outcomes = await Future.wait([
      queue.enqueue(request('synthetic-text', 1)),
      queue.enqueue(request('synthetic-other', 1)),
    ]);
    expect(outcomes, everyElement(isA<PackActivated>()));
    final order = [
      for (final r in server.requests.skip(from)) r.path.split('/').first,
    ];
    expect(order, [
      ...List.filled(3, 'synthetic-text'),
      ...List.filled(3, 'synthetic-other'),
    ]);
    final lifecycle = [
      for (final e in events)
        if (e is PackStarted || e is PackFinished)
          '${e.runtimeType} ${e.request}',
    ];
    expect(lifecycle, [
      'PackStarted synthetic-text/1',
      'PackFinished synthetic-text/1',
      'PackStarted synthetic-other/1',
      'PackFinished synthetic-other/1',
    ]);
  });

  test('after recovery from leftover staging and temp files a download '
      'succeeds', () async {
    await queue.enqueue(request('synthetic-text', 1));
    final leftover = await store.stagingFor('synthetic-text', 2);
    await File('${leftover.path}/$textFileName').writeAsString('partial');
    await File(
      '${storeRoot.path}/packs/synthetic-text/current.tmp',
    ).writeAsString('2\n1\n');
    expect(await store.recover(), [
      'deleted staging (1 files)',
      'synthetic-text: deleted current.tmp',
    ]);
    expect(await store.currentVersion('synthetic-text'), 1);
    expect(
      await queue.enqueue(request('synthetic-text', 2)),
      isA<PackActivated>(),
    );
    await expectInstalledAsServed('synthetic-text', 2);
  });

  test('refuses to download a version that is installed', () async {
    await queue.enqueue(request('synthetic-text', 1));
    final from = server.requests.length;
    final outcome = await queue.enqueue(request('synthetic-text', 1));
    expect(
      (outcome as PackNotActivated).reason,
      NotActivatedReason.versionExists,
    );
    expect(server.requests.skip(from), isEmpty);
    await expectInstalledAsServed('synthetic-text', 1);
  });

  test('a missing manifest stops the pack', () async {
    final outcome = await queue.enqueue(request('synthetic-missing', 1));
    expect((outcome as PackNotActivated).reason, NotActivatedReason.download);
    expect(outcome.detail, '$manifestFileName: not found');
    expect(
      await Directory('${storeRoot.path}/staging/synthetic-missing/1').exists(),
      isFalse,
    );
  });

  test('low space stops the pack with its reason; a wait for the network is '
      'passed on', () async {
    await queue.enqueue(request('synthetic-text', 1));
    await queue.close();
    events = [];
    final fake = _ScriptedDownloader(served, {
      'synthetic-text/2/$textFileName': (
        [DownloadState.queued, DownloadState.waitingForNetwork],
        const DownloadInsufficientSpace(),
      ),
    });
    queue = queueOn(fake);
    final outcome = await queue.enqueue(request('synthetic-text', 2));
    expect(
      (outcome as PackNotActivated).reason,
      NotActivatedReason.insufficientSpace,
    );
    expect(fake.calls, [
      'synthetic-text/2/$manifestFileName',
      'synthetic-text/2/manifest.json.sig',
      'synthetic-text/2/$textFileName',
    ]);
    expect(events.whereType<FileProgressed>().map((e) => e.progress.state), [
      DownloadState.queued,
      DownloadState.waitingForNetwork,
    ]);
    expect(await store.versionsOf('synthetic-text'), (
      active: 1,
      previous: null,
    ));
    expect(
      await Directory('${storeRoot.path}/staging/synthetic-text/2').exists(),
      isFalse,
    );
  });
}
