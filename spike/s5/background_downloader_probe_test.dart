import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../testing/packs/synthetic_pack.dart';
import 'background_downloader_adapter.dart';
import 'downloader.dart';
import 'filler_pack.dart';
import 'loopback_pack_server.dart';
import 'test_downloader.dart';

// Does background_downloader 9.5.9 run under `flutter test` against the
// loopback server? Yes, on its desktop path, given three things:
//
// 1. defaultTargetPlatform is android under flutter test, which would pick
//    the Android downloader (a method channel with no native side); the
//    platform is overridden to linux before the first FileDownloader().
// 2. The default task store (LocalStorePersistentStorage) asks path_provider
//    for its directory from a background isolate; under flutter test
//    `FileDownloader().ready` never completed (observed: still pending after
//    10 s). An in-memory store replaces it.
// 3. The download isolate asks path_provider for a temporary directory
//    unless Config.tempFilePath names one.
//
// RootIsolateToken.instance, which the download isolate needs, exists under
// flutter test. The desktop path ignores requiresWiFi and does not implement
// the free-space check: both are device checks. Retries resume from the bytes
// received only after more than 1 MiB has arrived; the Android runner has
// the same threshold (DownloadTaskRunner.kt).

void main() {
  late Directory temp;
  late FileDownloader plugin;
  late BackgroundDownloaderAdapter adapter;
  late LoopbackPackServer server;
  late Uint8List text;
  const textPath = 'synthetic-filler/1/$textFileName';

  setUpAll(() async {
    HttpOverrides.global = null;
    expect(defaultTargetPlatform, TargetPlatform.android);
    expect(RootIsolateToken.instance, isNotNull);
    temp = await Directory.systemTemp.createTemp('s5_probe');
    plugin = await startDesktopDownloaderForTests(temp);
    final pack = await buildSyntheticPack(
      Directory('${temp.path}/served'),
      id: 'synthetic-filler',
      surahs: fillerSurahs(bytes: 3 << 20, tag: 'probe'),
    );
    text = await pack.textFile.readAsBytes();
    expect(text.length, greaterThan(2 << 20));
    server = await LoopbackPackServer.start(Directory('${temp.path}/served'));
  });

  tearDownAll(() async {
    stopDesktopDownloaderForTests();
    await server.close();
    await temp.delete(recursive: true);
  });

  setUp(() {
    adapter = BackgroundDownloaderAdapter(plugin, retries: 2);
  });

  tearDown(() async {
    server.clearFaults();
    final out = Directory('${temp.path}/out');
    if (await out.exists()) await out.delete(recursive: true);
  });

  File target() => File('${temp.path}/out/$textFileName');

  Future<String> digestOf(File file) async =>
      sha256.convert(await file.readAsBytes()).toString();

  test('downloads a file whole; a Wi-Fi-only task runs without Wi-Fi on '
      'desktop', () async {
    final states = <DownloadState>[];
    final outcome = await adapter.download(
      server.uriOf(textPath),
      target(),
      wifiOnly: true,
      onProgress: (p) => states.add(p.state),
    );
    expect(outcome, isA<DownloadCompleted>());
    expect(await digestOf(target()), sha256.convert(text).toString());
    expect(
      states,
      containsAllInOrder([DownloadState.queued, DownloadState.running]),
    );
    expect(server.bytesServed(textPath), text.length);
  });

  test('start tracks tasks; task ids follow the URL and the target', () async {
    await adapter.start(rescheduleKilledTasks: false);
    final url = server.uriOf(textPath);
    expect(
      BackgroundDownloaderAdapter.taskIdFor(url, target()),
      BackgroundDownloaderAdapter.taskIdFor(url, File(target().path)),
    );
    expect(
      BackgroundDownloaderAdapter.taskIdFor(url, target()),
      isNot(
        BackgroundDownloaderAdapter.taskIdFor(url, File('${target().path}.b')),
      ),
    );
    expect(
      BackgroundDownloaderAdapter.taskIdFor(url, target()),
      matches(RegExp(r'^[0-9a-f]{32}$')),
    );
  });

  test('the free-space check is not implemented on desktop', () async {
    expect(await adapter.requireFreeSpace(1 << 20), 'not implemented');
    expect(await adapter.requireFreeSpace(null), 'not implemented');
  });

  test('a 404 ends as not found and writes nothing', () async {
    final outcome = await adapter.download(
      server.uriOf('synthetic-filler/1/manifest.json.sig'),
      File('${temp.path}/out/manifest.json.sig'),
      wifiOnly: false,
    );
    expect(outcome, isA<DownloadNotFound>());
    expect(await File('${temp.path}/out/manifest.json.sig').exists(), isFalse);
  });

  test('a drop after more than 1 MiB is resumed with Range', () async {
    const cut = 3 << 19;
    server.inject(textPath, const DropAfter(cut));
    final before = server.requests.length;
    final states = <DownloadState>[];
    final outcome = await adapter.download(
      server.uriOf(textPath),
      target(),
      wifiOnly: false,
      onProgress: (p) => states.add(p.state),
    );
    expect(outcome, isA<DownloadCompleted>());
    expect(await digestOf(target()), sha256.convert(text).toString());
    expect(states, contains(DownloadState.retrying));
    final requests = server.requests.skip(before).toList();
    expect(
      [for (final r in requests) (r.statusCode, r.dropped)],
      [(HttpStatus.ok, true), (HttpStatus.partialContent, false)],
    );
    final resumedAt = int.parse(
      RegExp(r'^bytes=(\d+)-$').firstMatch(requests.last.range!)![1]!,
    );
    expect(resumedAt, greaterThan(1 << 20));
    expect(resumedAt, lessThanOrEqualTo(requests.first.bytes));
    expect(
      requests.fold<int>(0, (sum, r) => sum + r.bytes),
      lessThanOrEqualTo(text.length + (64 << 10)),
    );
  });

  test('a drop before 1 MiB is retried from the start', () async {
    server.inject(textPath, const DropAfter(100000));
    final before = server.requests.length;
    final outcome = await adapter.download(
      server.uriOf(textPath),
      target(),
      wifiOnly: false,
    );
    expect(outcome, isA<DownloadCompleted>());
    expect(await digestOf(target()), sha256.convert(text).toString());
    final requests = server.requests.skip(before).toList();
    expect(
      [for (final r in requests) (r.range, r.statusCode, r.dropped)],
      [(null, HttpStatus.ok, true), (null, HttpStatus.ok, false)],
    );
  });
}
