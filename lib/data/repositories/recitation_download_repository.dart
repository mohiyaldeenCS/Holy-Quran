import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/download_progress.dart';
import '../../domain/models/recitation_download.dart';
import '../../domain/models/recitation_file.dart';
import '../../domain/models/recitation_target.dart';
import '../../utils/result.dart';
import '../services/connectivity_service.dart';
import '../services/download_service.dart';
import '../services/free_space_service.dart';
import '../services/recitation_file_store.dart';

/// Downloads a recitation's audio by surah, juz or whole, and removes it
/// (`AU-13`, `AU-14`). What a recitation offers comes from its installed
/// pack; every file is checked against the size and SHA-256 the pack states
/// before it is given its name, and a file already on the device is not
/// fetched again. Listeners hear of every change to [jobs] and [revision].
abstract interface class RecitationDownloadRepository implements Listenable {
  /// The queue in order, the running job first, then the jobs that failed.
  List<RecitationDownloadJob> get jobs;

  /// Changes each time a file is added to or removed from the device, so a
  /// reader of [present] knows when to read it again.
  int get revision;

  /// The files of the recitation's installed pack, at every quality.
  Future<Result<RecitationContents>> contents(String recitationId);

  /// The paths, in the pack, of the files at [qualityKbps] that are on the
  /// device whole.
  Future<Set<String>> present(RecitationContents contents, int qualityKbps);

  /// Whether any audio of the pack [packId] is on the device, at any quality.
  Future<bool> hasAudio(String packId);

  /// Queues [target] and completes when it is on the device or has failed.
  Future<Result<void>> download(
    RecitationTarget target, {
    required bool wifiOnly,
  });

  /// Changes the network every job in the queue may use, and that of the
  /// jobs queued later until they say otherwise. A job waiting for Wi-Fi
  /// starts when it is turned off; a file fetching over mobile data when it
  /// is turned on is stopped, and fetched again over Wi-Fi.
  void setWifiOnly(bool wifiOnly);

  /// Stops the job for [key], or dismisses its failure. What arrived whole
  /// stays.
  Future<void> cancel(String key);

  /// Removes the files of [target] from the device. The files every
  /// selection needs, the reciter's basmala and isti'adha, go only with the
  /// whole recitation.
  Future<Result<void>> delete(RecitationTarget target);

  /// The bytes of the pack's audio on the device, at every quality.
  Future<int> audioBytes(String packId);

  /// Removes all the audio of the pack, at every quality, and what is left
  /// of a download that was cut short.
  Future<Result<void>> deleteAudio(String packId);
}

/// [RecitationDownloadRepository] on the device. Jobs run one at a time, in
/// order, a file after another. Space for what is left is checked before the
/// first file, and a job that cannot get it fails without fetching.
final class LocalRecitationDownloadRepository extends ChangeNotifier
    implements RecitationDownloadRepository {
  LocalRecitationDownloadRepository({
    required this._contents,
    required this._downloads,
    required this._urlCheck,
    required this._connectivity,
    required this._freeSpace,
    required this._store,
    required this._policy,
  });

  final Future<Result<RecitationContents>> Function(String recitationId)
  _contents;
  final DownloadService _downloads;
  final UrlCheck _urlCheck;
  final ConnectivityService _connectivity;
  final FreeSpaceService _freeSpace;
  final RecitationFileStore _store;
  final UrlPolicy _policy;

  final _queue = <_Job>[];
  final _failed = <String, RecitationDownloadJob>{};
  Future<void>? _started;
  StreamSubscription<NetworkKind>? _networkChanges;
  NetworkKind _network = NetworkKind.none;
  _Job? _current;
  int _revision = 0;
  bool _disposed = false;

  @override
  int get revision => _revision;

  @override
  List<RecitationDownloadJob> get jobs => List.unmodifiable([
    for (final job in _queue) RecitationDownloadJob(job.target, job.state),
    ..._failed.values,
  ]);

  @override
  Future<Result<RecitationContents>> contents(String recitationId) =>
      _contents(recitationId);

  @override
  Future<Set<String>> present(
    RecitationContents contents,
    int qualityKbps,
  ) async {
    final files = [
      for (final file in contents.files)
        if (file.qualityKbps == qualityKbps) file,
    ];
    final here = await Future.wait([
      for (final file in files) _store.isPresent(contents.packId, file),
    ]);
    return {
      for (final (index, file) in files.indexed)
        if (here[index]) file.path,
    };
  }

  @override
  Future<bool> hasAudio(String packId) => _store.hasAudio(packId);

  @override
  Future<Result<void>> download(
    RecitationTarget target, {
    required bool wifiOnly,
  }) async {
    final key = target.key;
    for (final file in target.files) {
      final url = target.contents.urlOf(file);
      if (!_policy.allows(url)) return Failure(RecitationUrlRefused(key, url));
    }
    if (_jobOf(key) != null) return Failure(RecitationAlreadyQueued(key));
    _failed.remove(key);
    final job = _Job(target, wifiOnly: wifiOnly);
    _queue.add(job);
    _notify();
    unawaited(_drain());
    return job.result.future;
  }

  @override
  void setWifiOnly(bool wifiOnly) {
    for (final job in _queue) {
      if (job.wifiOnly == wifiOnly) continue;
      job.wifiOnly = wifiOnly;
      job.wake();
      final onMobileData = _network != NetworkKind.unmetered;
      if (job.order case final order? when wifiOnly && onMobileData) {
        job.restart = true;
        unawaited(_downloads.cancel(order));
      }
    }
  }

  @override
  Future<void> cancel(String key) async {
    if (_failed.remove(key) != null) _notify();
    final job = _jobOf(key);
    if (job == null) return;
    job
      ..cancelled = true
      ..wake();
    if (job == _current) {
      if (job.order case final order?) await _downloads.cancel(order);
      return;
    }
    _queue.remove(job);
    _notify();
    job.result.complete(Failure(RecitationDownloadCancelled(key)));
  }

  @override
  Future<Result<void>> delete(RecitationTarget target) async {
    final key = target.key;
    final packId = target.contents.packId;
    if (_queue.any((job) => job.target.contents.packId == packId)) {
      return Failure(RecitationAlreadyQueued(key));
    }
    try {
      for (final file in target.deletable) {
        await _store.delete(packId, file);
      }
      _revision++;
      _notify();
      return const Ok(null);
    } on Exception catch (e) {
      return Failure(RecitationStoreFailed(key, '$e'));
    }
  }

  @override
  Future<int> audioBytes(String packId) async {
    try {
      return await _store.bytesOnDevice(packId);
    } on Exception {
      return 0;
    }
  }

  @override
  Future<Result<void>> deleteAudio(String packId) async {
    if (_queue.any((job) => job.target.contents.packId == packId)) {
      return Failure(RecitationAlreadyQueued(packId));
    }
    try {
      await _store.deleteAll(packId);
      _revision++;
      _notify();
      return const Ok(null);
    } on Exception catch (e) {
      return Failure(RecitationStoreFailed(packId, '$e'));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final job in _queue) {
      job
        ..cancelled = true
        ..wake();
      final order = job.order;
      if (order != null) unawaited(_downloads.cancel(order));
      if (job != _current && !job.result.isCompleted) {
        job.result.complete(
          Failure(RecitationDownloadCancelled(job.target.key)),
        );
      }
    }
    unawaited(_networkChanges?.cancel());
    super.dispose();
  }

  /// Starts the downloader once; a start that failed is tried again.
  Future<void> _start() async {
    try {
      await (_started ??= () async {
        await _downloads.start();
        _networkChanges = _connectivity.changes.listen(
          _onNetwork,
          onError: (Object _) {},
        );
      }());
    } on Exception {
      _started = null;
      rethrow;
    }
  }

  /// The job for [key] that has not been stopped: one that was stopped is
  /// on its way out and a new job for the key may follow it.
  _Job? _jobOf(String key) => _queue
      .where((job) => job.target.key == key && !job.cancelled)
      .firstOrNull;

  Future<void> _drain() async {
    if (_current != null) return;
    while (_queue.isNotEmpty) {
      final job = _current = _queue.first;
      final Result<void> result;
      try {
        result = await _run(job);
      } on Object catch (e) {
        // Nothing may leave the queue stuck behind a job that threw.
        _queue.remove(job);
        _current = null;
        if (!job.result.isCompleted) {
          job.result.complete(
            Failure(RecitationStoreFailed(job.target.key, '$e')),
          );
        }
        _notify();
        continue;
      }
      _queue.remove(job);
      _current = null;
      if (result case Failure(
        error: final RecitationDownloadFailure failure,
      ) when failure is! RecitationDownloadCancelled) {
        _failed[job.target.key] = RecitationDownloadJob(
          job.target,
          RecitationDownloadFailed(failure),
        );
      }
      if (!job.result.isCompleted) job.result.complete(result);
      _notify();
    }
  }

  Future<Result<void>> _run(_Job job) async {
    try {
      await _start();
      final failure = await _fetchAll(job);
      return failure == null ? const Ok(null) : Failure(failure);
    } on Exception catch (e) {
      return Failure(RecitationStoreFailed(job.target.key, '$e'));
    }
  }

  Future<RecitationDownloadFailure?> _fetchAll(_Job job) async {
    final target = job.target;
    final packId = target.contents.packId;
    final missing = <RecitationFile>[];
    for (final file in target.files) {
      if (!await _store.isPresent(packId, file)) missing.add(file);
    }
    job.total = missing.fold(0, (sum, file) => sum + file.bytes);
    if (await _lackOfSpace(job) case final failure?) return failure;
    for (final file in missing) {
      if (job.cancelled) return RecitationDownloadCancelled(target.key);
      if (!await _store.stagedIsWhole(packId, file)) {
        if (await _fetch(job, file) case final failure?) return failure;
      }
      await _store.activate(packId, file);
      job.done += file.bytes;
      _revision++;
      _set(job, RecitationDownloading(job.progress));
    }
    return null;
  }

  Future<RecitationDownloadFailure?> _lackOfSpace(_Job job) async {
    final needed = job.total + packSpaceReserveBytes;
    final free = await _freeSpace.freeBytesAt(await _store.directory());
    if (free == null || free >= needed) return null;
    return RecitationNoSpace(
      job.target.key,
      neededBytes: needed,
      freeBytes: free,
    );
  }

  /// Fetches [file] to staging and checks it; null once it is whole there.
  Future<RecitationDownloadFailure?> _fetch(
    _Job job,
    RecitationFile file,
  ) async {
    final target = job.target;
    final key = target.key;
    final packId = target.contents.packId;
    final url = target.contents.urlOf(file);
    var rejected = false;
    while (true) {
      if (!await _ready(job)) return RecitationDownloadCancelled(key);
      // Where a host leads is asked once for the job; the network is
      // checked first, so no request goes out on mobile data when only
      // Wi-Fi is allowed.
      if (job.checkedHosts.add(url.host)) {
        switch (await _urlCheck.checkRedirects(url, _policy)) {
          case Ok():
            break;
          case Failure(error: UrlRefused(url: final refused)):
            return RecitationUrlRefused(key, refused);
          case Failure():
            job.checkedHosts.remove(url.host);
            // The network went while asking: wait for it, then ask again.
            if (!await _networkAllows(job.wifiOnly)) continue;
            return RecitationFileNotFetched(key, file.path);
        }
      }
      if (job.cancelled) return RecitationDownloadCancelled(key);
      final order = job.order = FileOrder(
        url: url,
        path: RecitationFileStore.stagingRelativePath(packId, file),
        wifiOnly: job.wifiOnly,
      );
      job.fileReceived = 0;
      _set(job, RecitationDownloading(job.progress));
      final outcome = await _downloads.download(
        order,
        (update) => _onUpdate(job, update),
      );
      job
        ..order = null
        ..fileReceived = 0;
      if (job.cancelled) return RecitationDownloadCancelled(key);
      if (job.restart) {
        // Turned to Wi-Fi only while on mobile data: wait for Wi-Fi.
        job.restart = false;
        continue;
      }
      switch (outcome) {
        case FileDownloaded():
          if (await _store.stagedIsWhole(packId, file)) return null;
          await _store.discardStaged(packId, file);
          if (rejected) return RecitationFileRejected(key, file.path);
          rejected = true;
        case FileDownloadNoSpace():
          return RecitationNoSpace(
            key,
            neededBytes: job.remaining + packSpaceReserveBytes,
            freeBytes: await _freeSpace.freeBytesAt(await _store.directory()),
          );
        case FileDownloadFailed(statusCode: null)
            when !await _networkAllows(job.wifiOnly):
          // The network went for longer than the downloader retries: wait
          // for it, then ask for the file again.
          continue;
        case FileDownloadCanceled():
          return RecitationFileNotFetched(key, file.path);
        case FileDownloadFailed(:final statusCode):
          return RecitationFileNotFetched(
            key,
            file.path,
            statusCode: statusCode,
          );
      }
    }
  }

  /// Waits until the job's network is up; false when it was cancelled.
  Future<bool> _ready(_Job job) async {
    while (!job.cancelled) {
      if (await _networkAllows(job.wifiOnly)) return true;
      _set(job, RecitationWaitingForNetwork(wifiOnly: job.wifiOnly));
      await job.sleep();
    }
    return false;
  }

  /// A task the downloader holds while the job's network is down is shown as
  /// waiting for it; the downloader does not say why it waits (S5).
  void _onUpdate(_Job job, FileTaskUpdate update) {
    if (job.cancelled) return;
    if (update.progress case final progress?) {
      job.fileReceived = progress.receivedBytes;
    }
    final waiting =
        update.status != FileTaskStatus.running &&
        !_allows(_network, job.wifiOnly);
    _set(
      job,
      waiting
          ? RecitationWaitingForNetwork(wifiOnly: job.wifiOnly)
          : RecitationDownloading(job.progress),
    );
  }

  void _onNetwork(NetworkKind kind) {
    _network = kind;
    for (final job in _queue) {
      job.wake();
    }
    final job = _current;
    if (job != null && job.order != null && !_allows(kind, job.wifiOnly)) {
      _set(job, RecitationWaitingForNetwork(wifiOnly: job.wifiOnly));
    }
  }

  Future<bool> _networkAllows(bool wifiOnly) async =>
      _allows(_network = await _connectivity.current(), wifiOnly);

  static bool _allows(NetworkKind kind, bool wifiOnly) =>
      wifiOnly ? kind == NetworkKind.unmetered : kind != NetworkKind.none;

  void _set(_Job job, RecitationDownloadState state) {
    job.state = state;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}

final class _Job {
  _Job(this.target, {required this.wifiOnly});

  final RecitationTarget target;
  bool wifiOnly;
  bool restart = false;
  final checkedHosts = <String>{};
  final result = Completer<Result<void>>();
  RecitationDownloadState state = const RecitationQueued();
  bool cancelled = false;
  FileOrder? order;

  /// Bytes this attempt fetches, once the files on the device are counted.
  int total = 0;
  int done = 0;
  int fileReceived = 0;
  Completer<void>? _sleeper;
  bool _woken = false;

  int get remaining => total - done;

  DownloadProgress get progress =>
      DownloadProgress(receivedBytes: done + fileReceived, totalBytes: total);

  /// Completes at the next [wake], or at once if one came since the last
  /// sleep, so that no wake is lost.
  Future<void> sleep() {
    if (_woken) {
      _woken = false;
      return Future.value();
    }
    return (_sleeper = Completer()).future;
  }

  void wake() {
    final sleeper = _sleeper;
    _sleeper = null;
    if (sleeper == null) {
      _woken = true;
    } else {
      sleeper.complete();
    }
  }
}
