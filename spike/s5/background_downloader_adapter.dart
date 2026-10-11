import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:crypto/crypto.dart';

import 'downloader.dart';

/// [SpikeDownloader] on background_downloader. Each file is one task that
/// can pause and resume (`allowPause`), with retries; a retry continues
/// from the bytes already received when the plugin kept resume data, which
/// it does only after more than 1 MiB of the file has arrived. The task id
/// is derived from the URL and the target, so after a restart a call for
/// the same file attaches to the plugin's task instead of starting another.
///
/// The native downloaders (Android, iOS) apply `requiresWiFi` and the free
/// space check; the desktop one, which `flutter test` runs, implements
/// neither.
final class BackgroundDownloaderAdapter implements SpikeDownloader {
  BackgroundDownloaderAdapter(
    this._downloader, {
    this.retries = 3,
    this.waitingGrace = const Duration(seconds: 2),
    this._log,
  }) {
    _downloader.registerCallbacks(
      group: group,
      taskStatusCallback: _onStatus,
      taskProgressCallback: _onProgress,
    );
  }

  static const group = 'spike-s5';

  /// How the plugin's failure message begins when its space check refuses
  /// a file.
  static const _insufficientSpace = 'Insufficient space';

  final FileDownloader _downloader;
  final int retries;

  /// How long a Wi-Fi-only task may stay enqueued before it is reported as
  /// waiting for the network. The plugin has no signal for that wait.
  final Duration waitingGrace;
  final void Function(String line)? _log;
  final Map<String, _Pending> _pending = {};

  /// Tracks tasks in the plugin's database, delivers what happened while the
  /// app was not running and, after five seconds, re-enqueues tasks the
  /// system killed.
  Future<void> start({bool rescheduleKilledTasks = true}) =>
      _downloader.start(doRescheduleKilledTasks: rescheduleKilledTasks);

  /// Sets the plugin's free-space check to [megabytes], or turns it off.
  /// Returns the plugin's answer: empty when applied, `not implemented` on
  /// desktop.
  Future<String> requireFreeSpace(int? megabytes) async {
    final answers = await _downloader.configure(
      globalConfig: (Config.checkAvailableSpace, megabytes ?? Config.never),
    );
    return answers.map((answer) => answer.$2).join(', ');
  }

  static String taskIdFor(Uri url, File target) => sha256
      .convert(utf8.encode('$url\n${target.absolute.path}'))
      .toString()
      .substring(0, 32);

  @override
  Future<DownloadOutcome> download(
    Uri url,
    File target, {
    required bool wifiOnly,
    DownloadListener? onProgress,
  }) async {
    final id = taskIdFor(url, target);
    if (_pending[id] case final pending?) return pending.done.future;
    final pending = _Pending(wifiOnly, onProgress);
    _pending[id] = pending;

    final existing = await _downloader.taskForId(id);
    if (existing is DownloadTask) {
      final record = await _downloader.database.recordForId(id);
      _log?.call('attached to task $id (${record?.status.name})');
      if (record?.status == TaskStatus.paused &&
          !await _downloader.resume(existing)) {
        _finish(id, const DownloadFailed('a paused task did not resume'));
      }
      return pending.done.future;
    }

    final task = DownloadTask(
      taskId: id,
      url: url.toString(),
      baseDirectory: BaseDirectory.root,
      directory: target.parent.absolute.path,
      filename: target.uri.pathSegments.last,
      group: group,
      updates: Updates.statusAndProgress,
      requiresWiFi: wifiOnly,
      retries: retries,
      allowPause: true,
    );
    if (!await _downloader.enqueue(task)) {
      _finish(id, const DownloadFailed('the plugin refused the task'));
    }
    return pending.done.future;
  }

  void _onStatus(TaskStatusUpdate update) {
    final id = update.task.taskId;
    final pending = _pending[id];
    _log?.call('task $id ${update.status.name}');
    if (pending == null) return;
    switch (update.status) {
      case TaskStatus.enqueued:
        pending.report(DownloadState.queued);
        if (pending.wifiOnly) {
          pending.waiting?.cancel();
          pending.waiting = Timer(
            waitingGrace,
            () => pending.report(DownloadState.waitingForNetwork),
          );
        }
      case TaskStatus.running:
        pending.waiting?.cancel();
        pending.report(DownloadState.running);
      case TaskStatus.waitingToRetry:
        pending.report(DownloadState.retrying);
      case TaskStatus.paused:
        pending.report(DownloadState.paused);
      case TaskStatus.complete:
        _finish(id, const DownloadCompleted());
      case TaskStatus.notFound:
        _finish(id, const DownloadNotFound());
      case TaskStatus.canceled:
        _finish(id, const DownloadFailed('canceled'));
      case TaskStatus.failed:
        final reason = update.exception?.description ?? 'unknown';
        _finish(
          id,
          reason.startsWith(_insufficientSpace)
              ? const DownloadInsufficientSpace()
              : DownloadFailed(reason, statusCode: update.responseStatusCode),
        );
    }
  }

  void _onProgress(TaskProgressUpdate update) {
    final pending = _pending[update.task.taskId];
    if (pending == null || update.progress < 0) return;
    final total = update.hasExpectedFileSize ? update.expectedFileSize : null;
    pending.report(
      DownloadState.running,
      received: total == null ? null : (update.progress * total).round(),
      total: total,
    );
  }

  void _finish(String id, DownloadOutcome outcome) {
    final pending = _pending.remove(id);
    if (pending == null) return;
    pending.waiting?.cancel();
    pending.done.complete(outcome);
  }
}

final class _Pending {
  _Pending(this.wifiOnly, this.listener);

  final bool wifiOnly;
  final DownloadListener? listener;
  final Completer<DownloadOutcome> done = Completer();
  Timer? waiting;

  void report(DownloadState state, {int? received, int? total}) =>
      listener?.call(DownloadProgress(state, received: received, total: total));
}
