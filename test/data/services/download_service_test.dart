import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:background_downloader/background_downloader.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/services/download_service.dart';
import 'package:holyquran/utils/result.dart';

// background_downloader runs here on its desktop path, against a loopback
// server, as spike S5 found it can under `flutter test`: the target platform
// is Linux (under flutter test it is Android, whose downloader has no native
// side), the task store is in memory (the default one asks path_provider
// from a background isolate, which never answers here), and
// Config.tempFilePath names the folder for partial files. The desktop path
// ignores requiresWiFi and has no space check; both are device checks.
// Every byte served is synthetic.

/// One request as the server answered it.
final class _Served {
  _Served(this.method, this.path, this.range);

  final String method;
  final String path;
  final String? range;
  int status = 0;
  int bytes = 0;
  bool dropped = false;
}

/// An HTTP server on 127.0.0.1 serving [files] by path, with byte ranges and
/// a strong ETag, redirects, a connection dropped after a byte count, and a
/// paced body.
final class _Server {
  _Server._(this._server, this.files) {
    _server.listen((request) => unawaited(_handle(request)));
  }

  static Future<_Server> start(Map<String, Uint8List> files) async => _Server._(
    await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
      ..autoCompress = false,
    files,
  );

  final HttpServer _server;
  final Map<String, Uint8List> files;
  final Map<String, String> redirects = {};
  final Map<String, int> dropAfter = {};
  final Map<String, int> bytesPerSecond = {};
  final List<_Served> requests = [];

  Uri uri(String path) =>
      Uri(scheme: 'http', host: '127.0.0.1', port: _server.port, path: path);

  void reset() {
    redirects.clear();
    dropAfter.clear();
    bytesPerSecond.clear();
    requests.clear();
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    final served = _Served(
      request.method,
      path,
      request.headers.value(HttpHeaders.rangeHeader),
    );
    requests.add(served);
    final response = request.response;
    try {
      if (redirects[path] case final location?) {
        served.status = response.statusCode = HttpStatus.found;
        response.headers.set(HttpHeaders.locationHeader, location);
        return await response.close();
      }
      final body = files[path];
      if (body == null) {
        served.status = response.statusCode = HttpStatus.notFound;
        return await response.close();
      }
      response.headers
        ..set('Accept-Ranges', 'bytes', preserveHeaderCase: true)
        ..set('ETag', '"${sha256.convert(body)}"', preserveHeaderCase: true)
        ..contentType = ContentType.binary;
      var start = 0;
      if (RegExp(r'^bytes=(\d+)-$').firstMatch(served.range ?? '')
          case final match?) {
        start = int.parse(match[1]!);
        response.headers.set(
          'Content-Range',
          'bytes $start-${body.length - 1}/${body.length}',
          preserveHeaderCase: true,
        );
        served.status = response.statusCode = HttpStatus.partialContent;
      } else {
        served.status = response.statusCode = HttpStatus.ok;
      }
      response.contentLength = body.length - start;
      if (request.method == 'HEAD') return await response.close();

      final part = Uint8List.sublistView(body, start);
      final drop = dropAfter.remove(path);
      if (drop == null || drop >= part.length) {
        await _send(part, response, served, bytesPerSecond[path]);
        return await response.close();
      }
      final socket = await response.detachSocket();
      served.dropped = true;
      await _send(Uint8List.sublistView(part, 0, drop), socket, served, null);
      socket.destroy();
    } on IOException {
      // The client went away; the log keeps what was sent.
    }
  }

  static Future<void> _send(
    Uint8List data,
    IOSink sink,
    _Served served,
    int? rate,
  ) async {
    final slice = rate == null ? max(data.length, 1) : max(rate ~/ 20, 1);
    for (var at = 0; at < data.length; at += slice) {
      if (rate != null) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      final chunk = Uint8List.sublistView(
        data,
        at,
        min(at + slice, data.length),
      );
      served.bytes += chunk.length;
      sink.add(chunk);
      await sink.flush();
    }
  }
}

/// background_downloader's task database in memory.
final class _MemoryTaskStorage implements PersistentStorage {
  final Map<String, TaskRecord> _records = {};
  final Map<String, Task> _paused = {};
  final Map<String, ResumeData> _resume = {};

  @override
  (String, int) get currentDatabaseVersion => ('memory', 1);

  @override
  Future<(String, int)> get storedDatabaseVersion async => ('memory', 1);

  @override
  Future<void> initialize() async {}

  @override
  Future<void> storeTaskRecord(TaskRecord record) async =>
      _records[record.taskId] = record;

  @override
  Future<TaskRecord?> retrieveTaskRecord(String taskId) async =>
      _records[taskId];

  @override
  Future<List<TaskRecord>> retrieveAllTaskRecords() async => [
    ..._records.values,
  ];

  @override
  Future<void> removeTaskRecord(String? taskId) async =>
      _remove(_records, taskId);

  @override
  Future<void> storePausedTask(Task task) async => _paused[task.taskId] = task;

  @override
  Future<Task?> retrievePausedTask(String taskId) async => _paused[taskId];

  @override
  Future<List<Task>> retrieveAllPausedTasks() async => [..._paused.values];

  @override
  Future<void> removePausedTask(String? taskId) async =>
      _remove(_paused, taskId);

  @override
  Future<void> storeResumeData(ResumeData resumeData) async =>
      _resume[resumeData.taskId] = resumeData;

  @override
  Future<ResumeData?> retrieveResumeData(String taskId) async =>
      _resume[taskId];

  @override
  Future<List<ResumeData>> retrieveAllResumeData() async => [..._resume.values];

  @override
  Future<void> removeResumeData(String? taskId) async =>
      _remove(_resume, taskId);

  static void _remove(Map<String, Object> map, String? key) =>
      key == null ? map.clear() : map.remove(key);
}

/// About 3 MiB of synthetic bytes.
final _large = Uint8List.fromList(
  List.generate(3 << 20, (i) => (i * 31 + 7) & 0xFF),
);
final _small = Uint8List.fromList(List.generate(1000, (i) => i & 0xFF));

void main() {
  late Directory temp;
  late _Server server;
  late FileDownloader plugin;
  late BackgroundDownloadService service;
  final httpOverrides = HttpOverrides.current;

  setUpAll(() async {
    HttpOverrides.global = null;
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    temp = await Directory.systemTemp.createTemp('download_service_test');
    plugin = FileDownloader(persistentStorage: _MemoryTaskStorage());
    await plugin.ready;
    await plugin.configure(
      globalConfig: (Config.tempFilePath, '${temp.path}/partial'),
    );
    server = await _Server.start({'/large.bin': _large, '/small.bin': _small});
    service = BackgroundDownloadService.under(plugin, '${temp.path}/root');
    await service.start();
  });

  tearDownAll(() async {
    debugDefaultTargetPlatformOverride = null;
    HttpOverrides.global = httpOverrides;
    await server.close();
    await temp.delete(recursive: true);
  });

  tearDown(() async {
    server.reset();
    final root = Directory('${temp.path}/root');
    if (await root.exists()) await root.delete(recursive: true);
  });

  File landed(String path) => File('${temp.path}/root/$path');

  FileOrder order(String served, String path) =>
      FileOrder(url: server.uri(served), path: path, wifiOnly: true);

  group('UrlPolicy', () {
    test('allows its scheme with a host only', () {
      expect(
        UrlPolicy.httpsOnly.allows(Uri.parse('https://a.invalid/x')),
        true,
      );
      for (final url in [
        'http://a.invalid/x',
        'HTTPS-x://a.invalid/x',
        'https:///x',
        'file:///x',
        'ftp://a.invalid/x',
      ]) {
        expect(UrlPolicy.httpsOnly.allows(Uri.parse(url)), false, reason: url);
      }
      expect(
        const UrlPolicy(scheme: 'http').allows(Uri.parse('http://a.invalid')),
        true,
      );
    });
  });

  group('BackgroundDownloadService', () {
    test('task ids follow the URL and the relative path', () {
      final url = server.uri('/small.bin');
      final id = BackgroundDownloadService.taskIdFor(url, 'a/b.bin');
      expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(BackgroundDownloadService.taskIdFor(url, 'a/b.bin'), id);
      expect(BackgroundDownloadService.taskIdFor(url, 'a/c.bin'), isNot(id));
      expect(
        BackgroundDownloadService.taskIdFor(server.uri('/x'), 'a/b.bin'),
        isNot(id),
      );
    });

    test('a download before start is a programming error', () {
      final unstarted = BackgroundDownloadService.under(plugin, temp.path);
      expect(
        () => unstarted.download(order('/small.bin', 'x.bin'), (_) {}),
        throwsStateError,
      );
    });

    test('a file lands at its relative path, with progress', () async {
      final updates = <FileTaskUpdate>[];
      final outcome = await service.download(
        order('/large.bin', 'pack-staging/synthetic/1/large.bin'),
        updates.add,
      );
      expect(outcome, isA<FileDownloaded>());
      expect(
        await landed('pack-staging/synthetic/1/large.bin').readAsBytes(),
        _large,
      );
      expect([
        for (final u in updates) u.status,
      ], containsAllInOrder([FileTaskStatus.enqueued, FileTaskStatus.running]));
      expect(
        updates.map((u) => u.progress?.totalBytes).whereType<int>(),
        everyElement(_large.length),
      );
      expect(server.requests.single.status, HttpStatus.ok);
    });

    test('a 404 fails with its status and writes nothing', () async {
      final outcome = await service.download(
        order('/absent.bin', 'staging/absent.bin'),
        (_) {},
      );
      expect(
        outcome,
        isA<FileDownloadFailed>().having(
          (o) => o.statusCode,
          'statusCode',
          HttpStatus.notFound,
        ),
      );
      expect(await landed('staging/absent.bin').exists(), isFalse);
    });

    test('a drop at 1.5 MiB resumes with Range and 206, re-fetching no '
        'finished bytes', () async {
      server.dropAfter['/large.bin'] = 3 << 19;
      final statuses = <FileTaskStatus>[];
      final outcome = await service.download(
        order('/large.bin', 'staging/large.bin'),
        (u) => statuses.add(u.status),
      );
      expect(outcome, isA<FileDownloaded>());
      expect(await landed('staging/large.bin').readAsBytes(), _large);
      expect(statuses, contains(FileTaskStatus.retrying));
      final [first, resumed] = server.requests;
      expect((first.status, first.dropped), (HttpStatus.ok, true));
      expect(
        (resumed.status, resumed.dropped),
        (HttpStatus.partialContent, false),
      );
      final from = int.parse(
        RegExp(r'^bytes=(\d+)-$').firstMatch(resumed.range!)![1]!,
      );
      expect(from, greaterThan(1 << 20));
      expect(from, lessThanOrEqualTo(first.bytes));
      expect(
        first.bytes + resumed.bytes,
        lessThanOrEqualTo(_large.length + (64 << 10)),
      );
    });

    test(
      'pause holds the download and resume continues it with Range',
      () async {
        server.bytesPerSecond['/large.bin'] = 2 << 20;
        final target = order('/large.bin', 'staging/paced.bin');
        final paused = Completer<void>();
        var pausing = false;
        final outcome = service.download(target, (u) {
          if (u.status == FileTaskStatus.paused && !paused.isCompleted) {
            paused.complete();
          }
          if (!pausing && (u.progress?.receivedBytes ?? 0) > (5 << 18)) {
            pausing = true;
            unawaited(service.pause(target));
          }
        });
        await paused.future;
        await service.resume(target);
        expect(await outcome, isA<FileDownloaded>());
        expect(await landed('staging/paced.bin').readAsBytes(), _large);
        expect(server.requests.last.status, HttpStatus.partialContent);
        expect(server.requests.last.range, matches(RegExp(r'^bytes=\d+-$')));
      },
    );

    test('a resume before the pause is reported waits for it, then resumes '
        'with Range instead of starting a second download', () async {
      server.bytesPerSecond['/large.bin'] = 2 << 20;
      final target = order('/large.bin', 'staging/early.bin');
      var pausing = false;
      final outcome = service.download(target, (u) {
        if (!pausing && (u.progress?.receivedBytes ?? 0) > (5 << 18)) {
          pausing = true;
          unawaited(() async {
            await service.pause(target);
            await service.resume(target);
          }());
        }
      });
      expect(await outcome, isA<FileDownloaded>());
      expect(await landed('staging/early.bin').readAsBytes(), _large);
      expect(
        [for (final r in server.requests) r.status],
        [HttpStatus.ok, HttpStatus.partialContent],
      );
    });

    test('cancel ends the download as canceled', () async {
      server.bytesPerSecond['/large.bin'] = 1 << 20;
      final target = order('/large.bin', 'staging/canceled.bin');
      final running = Completer<void>();
      final outcome = service.download(target, (u) {
        if ((u.progress?.receivedBytes ?? 0) > 0 && !running.isCompleted) {
          running.complete();
        }
      });
      await running.future;
      await service.cancel(target);
      expect(await outcome, isA<FileDownloadCanceled>());
      expect(await landed('staging/canceled.bin').exists(), isFalse);
    });

    test('an order made again after a stop is a task of its own, which the '
        'stopped one cannot end', () async {
      server.bytesPerSecond['/large.bin'] = 1 << 20;
      final first = order('/large.bin', 'staging/again.bin');
      final running = Completer<void>();
      final stopped = service.download(first, (u) {
        if ((u.progress?.receivedBytes ?? 0) > 0 && !running.isCompleted) {
          running.complete();
        }
      });
      await running.future;
      server.bytesPerSecond.remove('/large.bin');
      final again = FileOrder(
        url: first.url,
        path: first.path,
        wifiOnly: false,
        attempt: 1,
      );

      await service.cancel(first);
      final outcome = service.download(again, (_) {});

      expect(await stopped, isA<FileDownloadCanceled>());
      expect(await outcome, isA<FileDownloaded>());
      expect(await landed('staging/again.bin').readAsBytes(), _large);
    });

    test(
      'the first attempt keeps the id it always had, a later one differs',
      () {
        final url = server.uri('/small.bin');
        final id = BackgroundDownloadService.taskIdFor(url, 'a/b.bin');

        expect(
          BackgroundDownloadService.taskIdFor(url, 'a/b.bin', 1),
          isNot(id),
        );
        expect(
          BackgroundDownloadService.taskIdFor(url, 'a/b.bin', 1),
          isNot(BackgroundDownloadService.taskIdFor(url, 'a/b.bin', 2)),
        );
      },
    );

    test('pause, resume and cancel of an unknown order do nothing', () async {
      final unknown = order('/small.bin', 'staging/unknown.bin');
      expect(await service.pause(unknown), isFalse);
      await service.resume(unknown);
      await service.cancel(unknown);
      expect(server.requests, isEmpty);
    });
  });

  group('HttpUrlCheck', () {
    const http = UrlPolicy(scheme: 'http');

    test('a URL that does not redirect is its own end', () async {
      final url = server.uri('/small.bin');
      expect(
        await const HttpUrlCheck().checkRedirects(url, http),
        isA<Ok<Uri>>().having((r) => r.value, 'value', url),
      );
      expect([for (final r in server.requests) r.method], ['HEAD']);
    });

    test('follows redirects that keep the scheme, relative ones too', () async {
      server.redirects['/a'] = server.uri('/b').toString();
      server.redirects['/b'] = '/c';
      server.redirects['/c'] = 'small.bin';
      expect(
        await const HttpUrlCheck().checkRedirects(server.uri('/a'), http),
        isA<Ok<Uri>>().having(
          (r) => r.value,
          'value',
          server.uri('/small.bin'),
        ),
      );
      expect(
        [for (final r in server.requests) r.path],
        ['/a', '/b', '/c', '/small.bin'],
      );
    });

    test('refuses a redirect that changes the scheme, before any request '
        'reaches its target', () async {
      final target = await _Server.start({'/small.bin': _small});
      addTearDown(target.close);
      final elsewhere = target.uri('/small.bin').replace(scheme: 'https');
      server.redirects['/a'] = elsewhere.toString();
      expect(
        await const HttpUrlCheck().checkRedirects(server.uri('/a'), http),
        isA<Failure<Uri>>().having(
          (f) => f.error,
          'error',
          isA<UrlRefused>()
              .having((e) => e.url, 'url', elsewhere)
              .having((e) => e.from, 'from', server.uri('/a')),
        ),
      );
      expect(target.requests, isEmpty);
    });

    test('refuses a sixth redirect', () async {
      for (var hop = 0; hop < 6; hop++) {
        server.redirects['/$hop'] = '/${hop + 1}';
      }
      final refused = await const HttpUrlCheck().checkRedirects(
        server.uri('/0'),
        http,
      );
      expect(
        refused,
        isA<Failure<Uri>>().having(
          (f) => f.error,
          'error',
          isA<UrlRefused>()
              .having((e) => e.url, 'url', server.uri('/6'))
              .having((e) => e.from, 'from', server.uri('/5')),
        ),
      );
      expect(server.requests, hasLength(6));
      expect(
        await const HttpUrlCheck().checkRedirects(server.uri('/1'), http),
        isA<Ok<Uri>>().having((r) => r.value, 'value', server.uri('/6')),
      );
    });

    test('a URL the policy refuses makes no request', () async {
      final url = server.uri('/small.bin');
      expect(
        await const HttpUrlCheck().checkRedirects(url, UrlPolicy.httpsOnly),
        isA<Failure<Uri>>().having(
          (f) => f.error,
          'error',
          isA<UrlRefused>()
              .having((e) => e.url, 'url', url)
              .having((e) => e.from, 'from', isNull),
        ),
      );
      expect(server.requests, isEmpty);
    });

    test('a server that does not answer is unreachable', () async {
      final closed = await _Server.start({});
      final url = closed.uri('/small.bin');
      await closed.close();
      expect(
        await const HttpUrlCheck().checkRedirects(url, http),
        isA<Failure<Uri>>().having(
          (f) => f.error,
          'error',
          isA<UrlUnreachable>().having((e) => e.url, 'url', url),
        ),
      );
    });
  });

  // Last, because each relaunched service takes over the plugin's callbacks
  // for the packs group from the services before it.
  group('after a relaunch', () {
    test('a call for a paused task resumes it with Range', () async {
      server.bytesPerSecond['/large.bin'] = 2 << 20;
      final target = order('/large.bin', 'staging/relaunch-paused.bin');
      final paused = Completer<void>();
      var pausing = false;
      unawaited(
        service.download(target, (u) {
          if (u.status == FileTaskStatus.paused && !paused.isCompleted) {
            paused.complete();
          }
          if (!pausing && (u.progress?.receivedBytes ?? 0) > (5 << 18)) {
            pausing = true;
            unawaited(service.pause(target));
          }
        }),
      );
      await paused.future;

      final relaunched = BackgroundDownloadService.under(
        plugin,
        '${temp.path}/root',
      );
      await relaunched.start();
      expect(await relaunched.download(target, (_) {}), isA<FileDownloaded>());
      expect(await landed('staging/relaunch-paused.bin').readAsBytes(), _large);
      expect(
        [for (final r in server.requests) r.status],
        [HttpStatus.ok, HttpStatus.partialContent],
      );
    });

    test('a call for a running task attaches to it', () async {
      server.bytesPerSecond['/large.bin'] = 2 << 20;
      final first = BackgroundDownloadService.under(
        plugin,
        '${temp.path}/root',
      );
      await first.start();
      final target = order('/large.bin', 'staging/relaunch-running.bin');
      final running = Completer<void>();
      unawaited(
        first.download(target, (u) {
          if ((u.progress?.receivedBytes ?? 0) > 0 && !running.isCompleted) {
            running.complete();
          }
        }),
      );
      await running.future;

      final relaunched = BackgroundDownloadService.under(
        plugin,
        '${temp.path}/root',
      );
      await relaunched.start();
      expect(await relaunched.download(target, (_) {}), isA<FileDownloaded>());
      expect(
        await landed('staging/relaunch-running.bin').readAsBytes(),
        _large,
      );
      expect([for (final r in server.requests) r.status], [HttpStatus.ok]);
    });
  });
}
