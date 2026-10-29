import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:background_downloader/background_downloader.dart';
import 'package:crypto/crypto.dart';

import '../../domain/models/download_progress.dart';
import '../../utils/result.dart';
import 'free_space_service.dart';

/// Which URLs a pack may come from: [scheme] only, with a host. The app
/// allows `https`; tests inject `http` for a loopback server.
final class UrlPolicy {
  const UrlPolicy({required this.scheme});

  static const httpsOnly = UrlPolicy(scheme: 'https');

  final String scheme;

  bool allows(Uri url) => url.scheme == scheme && url.host.isNotEmpty;
}

/// One file to fetch from [url] to [path], which is relative to the
/// download root and separated by `/`.
final class FileOrder {
  const FileOrder({
    required this.url,
    required this.path,
    required this.wifiOnly,
    this.attempt = 0,
    this.separateAttempts = false,
  });

  final Uri url;
  final String path;
  final bool wifiOnly;

  /// Which order for this file it is: one made again after another was
  /// stopped is a task of its own, so that the stopped one can neither end
  /// it nor lend it its network requirement. The service numbers it above
  /// any task of the file it finds, so [FileDownloaded.attempt] says which
  /// one it was.
  final int attempt;

  /// Whether each attempt lands in a file of its own, [targetAt], so that a
  /// task that outlives its stop cannot write over what a later one fetched.
  final bool separateAttempts;

  /// Where the file of [attempt] lands, relative to the download root.
  String targetAt(int attempt) =>
      separateAttempts ? pathAt(path, attempt) : path;

  /// Where the file of this order lands.
  String get target => targetAt(attempt);

  /// [path] for the first attempt; for a later one, with `.a<attempt>`
  /// before the extension.
  static String pathAt(String path, int attempt) {
    if (attempt == 0) return path;
    final dot = path.lastIndexOf('.');
    return dot > path.lastIndexOf('/')
        ? '${path.substring(0, dot)}.a$attempt${path.substring(dot)}'
        : '$path.a$attempt';
  }
}

enum FileTaskStatus { enqueued, running, retrying, paused }

/// [progress] is null when the downloader did not report it.
typedef FileTaskUpdate = ({FileTaskStatus status, DownloadProgress? progress});

sealed class FileDownloadOutcome {
  const FileDownloadOutcome();
}

final class FileDownloaded extends FileDownloadOutcome {
  const FileDownloaded({this.attempt = 0});

  /// The attempt whose file arrived, see [FileOrder.attempt].
  final int attempt;
}

final class FileDownloadCanceled extends FileDownloadOutcome {
  const FileDownloadCanceled();
}

/// The device lacks the space the downloader's check asks for.
final class FileDownloadNoSpace extends FileDownloadOutcome {
  const FileDownloadNoSpace();
}

final class FileDownloadFailed extends FileDownloadOutcome {
  const FileDownloadFailed(this.reason, {this.statusCode});

  final String reason;
  final int? statusCode;

  @override
  String toString() => 'FileDownloadFailed($reason, $statusCode)';
}

/// Downloads one file per call. A call completes only with a final outcome;
/// while paused, retrying or waiting for its network it stays pending.
abstract interface class DownloadService {
  Future<void> start();

  Future<FileDownloadOutcome> download(
    FileOrder order,
    void Function(FileTaskUpdate update) onUpdate,
  );

  /// Whether the download of [order] was paused; when it was not, it goes
  /// on, or ends.
  Future<bool> pause(FileOrder order);

  Future<void> resume(FileOrder order);

  Future<void> cancel(FileOrder order);
}

/// [DownloadService] on `background_downloader` (D-107). Each file is one
/// task that can pause and resume, with retries; a retry continues from the
/// bytes received once more than 1 MiB has arrived (S5). The task id
/// follows from the URL, the path and the order's attempt, and the task
/// keeps both in its meta data. A call for a file looks for the plugin's
/// tasks for it, at any attempt, so that after a relaunch it attaches to the
/// one that needs the network now asked for, stops the others, and makes a
/// task of a later attempt only when none fits.
final class BackgroundDownloadService implements DownloadService {
  /// Files land under the application-support directory, named relative to
  /// it, because iOS moves the app's container between launches.
  BackgroundDownloadService.applicationSupport()
    : _open = FileDownloader.new,
      _base = BaseDirectory.applicationSupport,
      _root = null;

  /// Files land under the absolute directory [root]; for desktop tests.
  BackgroundDownloadService.under(FileDownloader downloader, String root)
    : _open = (() => downloader),
      _base = BaseDirectory.root,
      _root = root;

  static const _group = 'packs';
  static const _retries = 3;

  /// How the plugin's failure message begins when its space check refuses a
  /// file; it reports low space no other way (S5).
  static const _insufficientSpace = 'Insufficient space';

  final FileDownloader Function() _open;
  final BaseDirectory _base;
  final String? _root;
  final Map<String, _Pending> _pending = {};
  final Map<String, _Pending> _byFile = {};

  /// Ids of tasks this service asked the plugin to stop: they are never
  /// attached to, whatever the plugin still lists.
  final Set<String> _stopping = {};
  FileDownloader? _downloader;

  /// The plugin's task id for [url] and [path]; a later [attempt] is another
  /// task, and the first one's id is as it was before attempts existed.
  static String taskIdFor(Uri url, String path, [int attempt = 0]) {
    final text = attempt == 0 ? '$url\n$path' : '$url\n$path\n$attempt';
    return sha256.convert(utf8.encode(text)).toString().substring(0, 32);
  }

  /// Creates the plugin, tracks its tasks and delivers what happened while
  /// the app was not running.
  @override
  Future<void> start() async {
    if (_downloader != null) return;
    final downloader = _open()
      ..registerCallbacks(
        group: _group,
        taskStatusCallback: _onStatus,
        taskProgressCallback: _onProgress,
      );
    _downloader = downloader;
    await downloader.configure(
      globalConfig: (Config.checkAvailableSpace, packSpaceReserveBytes >> 20),
    );
    // No automatic clean-up: it removes records by age whatever their state,
    // and a paused task is told from a running one only by its record.
    await downloader.start();
  }

  @override
  Future<FileDownloadOutcome> download(
    FileOrder order,
    void Function(FileTaskUpdate update) onUpdate,
  ) async {
    final downloader = _started;
    final key = _fileKey(order);
    if (_byFile[key] case final pending?) return pending.done.future;
    final pending = _byFile[key] = _Pending(key, onUpdate);
    try {
      final found = await _tasksOfFile(downloader, order);
      // Tasks of the file the plugin kept, from before a relaunch or from an
      // order since replaced: at most one that needs the network now asked
      // for is attached to, the rest are stopped, so that no second
      // download of the file runs beside it.
      final alive = [
        for (final task in found)
          if (!_stopping.contains(task.task.taskId)) task,
      ];
      final keep = alive
          .where((task) => task.task.requiresWiFi == order.wifiOnly)
          .firstOrNull;
      await _stop([
        for (final task in found)
          if (task != keep && !_stopping.contains(task.task.taskId))
            task.task.taskId,
      ]);
      if (pending.canceled) {
        _end(pending, const FileDownloadCanceled());
      } else if (keep != null) {
        _attach(pending, keep.task, keep.attempt);
        if (keep.paused) await _resumeOrRestart(downloader, keep.task);
      } else {
        final next = found.fold(
          order.attempt,
          (n, task) => max(n, task.attempt + 1),
        );
        final task = _taskFor(order, next);
        _attach(pending, task, next);
        if (!await downloader.enqueue(task)) {
          _end(
            pending,
            const FileDownloadFailed('the downloader refused the task'),
          );
        }
      }
    } on Exception catch (e) {
      _end(pending, FileDownloadFailed('$e'));
    }
    return pending.done.future;
  }

  @override
  Future<bool> pause(FileOrder order) async {
    final pending = _byFile[_fileKey(order)];
    final task = pending?.task;
    if (pending == null || task == null) return false;
    pending.resumeWanted = false;
    try {
      return await _started.pause(task);
    } on Exception {
      return false;
    }
  }

  @override
  Future<void> resume(FileOrder order) async {
    final pending = _byFile[_fileKey(order)];
    if (pending == null) return;
    // Until the plugin reports the task paused it has no resume data, and
    // enqueuing the running task again would start a second writer.
    if (!pending.paused) {
      pending.resumeWanted = true;
      return;
    }
    await _resumePaused(pending);
  }

  Future<void> _resumePaused(_Pending pending) async {
    pending.paused = false;
    try {
      await _resumeOrRestart(_started, pending.task!);
    } on Exception catch (e) {
      _end(pending, FileDownloadFailed('$e'));
    }
  }

  /// Stops every task of the file of [order], also those a relaunch left,
  /// and ends its download as canceled, also when the plugin could not stop
  /// a task.
  @override
  Future<void> cancel(FileOrder order) async {
    final pending = _byFile[_fileKey(order)];
    pending?.canceled = true;
    List<_Found> found;
    try {
      found = await _tasksOfFile(_started, order);
    } on Exception {
      found = const [];
    }
    await _stop({
      for (final task in found) task.task.taskId,
      ?pending?.task?.taskId,
    });
    if (pending != null) _end(pending, const FileDownloadCanceled());
  }

  /// Asks the plugin to stop the tasks [ids]. A task it cannot stop is left
  /// out of every later choice, and its statuses are ignored.
  Future<void> _stop(Iterable<String> ids) async {
    final stopping = ids.toList();
    if (stopping.isEmpty) return;
    _stopping.addAll(stopping);
    try {
      await _started.cancelTasksWithIds(stopping);
    } on Exception {
      // The outcome ends the call either way.
    }
  }

  FileDownloader get _started =>
      _downloader ?? (throw StateError('start() was not called'));

  /// The plugin's tasks for the file of [order], at any attempt.
  Future<List<_Found>> _tasksOfFile(
    FileDownloader downloader,
    FileOrder order,
  ) async {
    final found = <_Found>[];
    for (final task in await downloader.allTasks(group: _group)) {
      if (task is! DownloadTask || task.url != order.url.toString()) continue;
      final attempt = _attemptOf(task, order);
      if (attempt == null) continue;
      final record = await downloader.database.recordForId(task.taskId);
      found.add((
        task: task,
        attempt: attempt,
        paused: record?.status == TaskStatus.paused,
      ));
    }
    return found;
  }

  /// The attempt [task] is for the file of [order]; null when it is for
  /// another file.
  static int? _attemptOf(DownloadTask task, FileOrder order) {
    final colon = task.metaData.indexOf(':');
    if (colon > 0 && task.metaData.substring(colon + 1) == order.path) {
      return int.tryParse(task.metaData.substring(0, colon));
    }
    // A task made before attempts existed.
    return task.taskId == taskIdFor(order.url, order.path) ? 0 : null;
  }

  static String _fileKey(FileOrder order) => '${order.url}\n${order.path}';

  void _attach(_Pending pending, DownloadTask task, int attempt) {
    pending
      ..task = task
      ..attempt = attempt;
    _pending[task.taskId] = pending;
  }

  /// Resumes [task] from its received bytes, or starts it again when the
  /// plugin kept none.
  Future<void> _resumeOrRestart(
    FileDownloader downloader,
    DownloadTask task,
  ) async {
    if (await downloader.resume(task)) return;
    if (!await downloader.enqueue(task)) {
      _end(
        _pending[task.taskId]!,
        const FileDownloadFailed('the downloader refused the task'),
      );
    }
  }

  DownloadTask _taskFor(FileOrder order, int attempt) {
    final target = order.targetAt(attempt);
    final slash = target.lastIndexOf('/');
    final directory = slash < 0 ? '' : target.substring(0, slash);
    return DownloadTask(
      taskId: taskIdFor(order.url, order.path, attempt),
      url: order.url.toString(),
      baseDirectory: _base,
      directory: _root == null ? directory : '$_root/$directory',
      filename: target.substring(slash + 1),
      group: _group,
      updates: Updates.statusAndProgress,
      requiresWiFi: order.wifiOnly,
      retries: _retries,
      allowPause: true,
      metaData: '$attempt:${order.path}',
    );
  }

  void _onStatus(TaskStatusUpdate update) {
    final id = update.task.taskId;
    final pending = _pending[id];
    if (pending == null) return;
    switch (update.status) {
      case TaskStatus.enqueued:
        pending.report(FileTaskStatus.enqueued);
      case TaskStatus.running:
        pending.paused = false;
        pending.report(FileTaskStatus.running);
      case TaskStatus.waitingToRetry:
        pending.report(FileTaskStatus.retrying);
      case TaskStatus.paused when pending.resumeWanted:
        pending.resumeWanted = false;
        pending.paused = true;
        unawaited(_resumePaused(pending));
      case TaskStatus.paused:
        pending.paused = true;
        pending.report(FileTaskStatus.paused);
      case TaskStatus.complete:
        _end(pending, FileDownloaded(attempt: pending.attempt));
      case TaskStatus.notFound:
        _end(
          pending,
          const FileDownloadFailed(
            'not found',
            statusCode: HttpStatus.notFound,
          ),
        );
      case TaskStatus.canceled:
        _end(pending, const FileDownloadCanceled());
      case TaskStatus.failed:
        final reason = update.exception?.description ?? 'unknown';
        _end(
          pending,
          reason.startsWith(_insufficientSpace)
              ? const FileDownloadNoSpace()
              : FileDownloadFailed(
                  reason,
                  statusCode: update.responseStatusCode,
                ),
        );
    }
  }

  void _onProgress(TaskProgressUpdate update) {
    final pending = _pending[update.task.taskId];
    if (pending == null || update.progress < 0) return;
    final total = update.hasExpectedFileSize ? update.expectedFileSize : null;
    pending.report(
      FileTaskStatus.running,
      total == null
          ? null
          : DownloadProgress(
              receivedBytes: (update.progress * total).round(),
              totalBytes: total,
            ),
    );
  }

  void _end(_Pending pending, FileDownloadOutcome outcome) {
    if (identical(_byFile[pending.key], pending)) _byFile.remove(pending.key);
    final task = pending.task;
    if (task != null && identical(_pending[task.taskId], pending)) {
      _pending.remove(task.taskId);
    }
    if (!pending.done.isCompleted) pending.done.complete(outcome);
  }
}

final class _Pending {
  _Pending(this.key, this.onUpdate);

  final String key;
  final void Function(FileTaskUpdate update) onUpdate;
  final Completer<FileDownloadOutcome> done = Completer();

  /// The plugin's task for the file, once one is chosen or made.
  DownloadTask? task;
  int attempt = 0;

  /// Whether the download was stopped before a task was chosen.
  bool canceled = false;

  /// Whether the plugin has reported the task paused since it last ran.
  bool paused = false;

  /// Whether a resume came before the plugin reported the pause.
  bool resumeWanted = false;

  void report(FileTaskStatus status, [DownloadProgress? progress]) =>
      onUpdate((status: status, progress: progress));
}

/// A task the plugin holds for a file: made at [attempt], and [paused] when
/// its record says so.
typedef _Found = ({DownloadTask task, int attempt, bool paused});

/// A URL the policy refuses. [from] is the URL that redirected to it; null
/// when it is the URL asked about.
final class UrlRefused implements Exception {
  const UrlRefused(this.url, {this.from});

  final Uri url;
  final Uri? from;

  @override
  String toString() => 'UrlRefused($url${from == null ? '' : ' from $from'})';
}

final class UrlUnreachable implements Exception {
  const UrlUnreachable(this.url, this.reason);

  final Uri url;
  final String reason;

  @override
  String toString() => 'UrlUnreachable($url): $reason';
}

/// Checks where a URL leads before the downloader, which follows redirects
/// by itself, is given it.
abstract interface class UrlCheck {
  /// The URL [url] finally leads to, or [UrlRefused] when it, or a redirect
  /// on the way, is one [policy] refuses or changes scheme, or [UrlUnreachable].
  Future<Result<Uri>> checkRedirects(Uri url, UrlPolicy policy);
}

/// [UrlCheck] by `HEAD` requests that do not follow redirects, over TLS 1.2
/// or later (NF-15). Release assets redirect to a storage host: each hop must
/// pass the policy and keep the scheme of the first URL. The final status is
/// not judged; the downloader reports it.
final class HttpUrlCheck implements UrlCheck {
  const HttpUrlCheck();

  static const _maxRedirects = 5;
  static const _timeout = Duration(seconds: 30);

  @override
  Future<Result<Uri>> checkRedirects(Uri url, UrlPolicy policy) async {
    if (!policy.allows(url)) return Failure(UrlRefused(url));
    final client = HttpClient(
      context: SecurityContext(withTrustedRoots: true)
        ..minimumTlsProtocolVersion = TlsProtocolVersion.tls1_2,
    )..connectionTimeout = _timeout;
    try {
      var current = url;
      for (var followed = 0; ; followed++) {
        final request = await client.headUrl(current)
          ..followRedirects = false;
        final response = await request.close().timeout(_timeout);
        await response.drain<void>();
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (!response.isRedirect || location == null) return Ok(current);
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
      }
    } on IOException catch (e) {
      return Failure(UrlUnreachable(url, '$e'));
    } on TimeoutException catch (e) {
      return Failure(UrlUnreachable(url, '$e'));
    } finally {
      client.close(force: true);
    }
  }
}
