import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/download_progress.dart';
import '../../domain/models/install_job.dart';
import '../../domain/models/installed_pack.dart';
import '../../domain/models/pack_failure.dart';
import '../../domain/models/pack_manifest.dart';
import '../../domain/models/verified_pack.dart';
import '../../utils/result.dart';
import '../models/pack_manifest_json.dart';
import '../services/connectivity_service.dart';
import '../services/download_service.dart';
import '../services/free_space_service.dart';
import '../services/installed_packs_store.dart';
import '../services/pack_file_service.dart';
import 'pack_repository.dart';

/// Installs, rolls back and deletes packs (`OF-04` to `OF-07`). Listeners
/// hear of every change to [installed] and [jobs].
abstract interface class PackInstallRepository implements Listenable {
  /// Completes once the installed packs have been read: a [Failure] when the
  /// store could not open, or when an installed manifest could not be read;
  /// in that case the other packs are listed and installs still run.
  Future<Result<void>> get started;

  List<InstalledPack> get installed;

  /// The queue in order, the running job first, then the jobs that failed.
  List<InstallJob> get jobs;

  /// Queues [request] and completes when it is installed or has failed.
  Future<Result<InstalledPack>> install(InstallRequest request);

  Future<void> pause(String packId);

  /// Resumes a paused job, or one stopped for low space after checking the
  /// space again.
  Future<void> resume(String packId);

  /// Cancels the job for [packId], or dismisses its failure.
  Future<void> cancel(String packId);

  Future<Result<InstalledPack>> rollback(String packId);

  Future<Result<void>> delete(String packId);
}

/// [PackInstallRepository] on the device. Jobs run one at a time, in order;
/// a paused job, or one stopped for low space, holds the queue, and a failed
/// one leaves it. Each job fetches the manifest and checks it against the
/// request, then the files it lists into staging, reusing files an earlier
/// attempt left there whole; verifies the pack, fetching a file that fails
/// its hash once more; applies the signature policy (D-108); and activates
/// it. Staging is kept after a network failure, so the next attempt resumes,
/// and discarded after a rejection or a cancel.
final class LocalPackInstallRepository extends ChangeNotifier
    implements PackInstallRepository {
  LocalPackInstallRepository({
    required this._openStore,
    required this._downloads,
    required this._urlCheck,
    required this._connectivity,
    required this._freeSpace,
    required this._files,
    required this._verifier,
    required this._policy,
    required this._acceptUnchecked,
    this._onPackChanged,
  });

  static const _manifest = 'manifest.json';
  static const _signature = 'manifest.json.sig';

  final Future<InstalledPacksStore> Function() _openStore;
  final DownloadService _downloads;
  final UrlCheck _urlCheck;
  final ConnectivityService _connectivity;
  final FreeSpaceService _freeSpace;
  final PackFileService _files;
  final PackRepository _verifier;
  final UrlPolicy _policy;

  /// Whether a pack whose signature was not checked may be activated: only
  /// outside release builds (D-108).
  final bool _acceptUnchecked;

  /// Called with the id of a pack whose files were replaced, rolled back or
  /// deleted, so that what was said of the old files is not kept for the
  /// new ones.
  final void Function(String packId)? _onPackChanged;

  final _started = Completer<Result<void>>();
  final _queue = <_Job>[];
  final _failed = <String, InstallJob>{};
  InstalledPacksStore? _store;
  StreamSubscription<NetworkKind>? _networkChanges;
  NetworkKind _network = NetworkKind.none;

  /// Packs being rolled back or deleted; no job for them may start meanwhile.
  final _changing = <String>{};
  List<InstalledPack> _installed = const [];
  _Job? _current;
  bool _starting = false;
  bool _disposed = false;

  @override
  Future<Result<void>> get started => _started.future;

  @override
  List<InstalledPack> get installed => _installed;

  @override
  List<InstallJob> get jobs => List.unmodifiable([
    for (final job in _queue) InstallJob(job.request, job.state),
    ..._failed.values,
  ]);

  /// Opens the store, recovers it from a cut-short change, starts the
  /// downloader and reads the installed packs. Throws nothing but an
  /// [Error], which is a bug: [started] still completes, as a failure, so
  /// that no install waits for it for ever.
  Future<Result<void>> start() async {
    if (_starting) return started;
    _starting = true;
    Result<void> result = const Failure(StoreFailed('', 'the start stopped'));
    try {
      final store = await _openStore();
      await store.recover();
      await _downloads.start();
      // A failed connectivity event changes nothing: each job asks for the
      // network again before each file.
      _networkChanges = _connectivity.changes.listen(
        _onNetwork,
        onError: (Object _) {},
      );
      _store = store;
      result = await _reload();
    } on Exception catch (e) {
      result = Failure(e);
    } finally {
      _started.complete(result);
      _notify();
      unawaited(_drain());
    }
    return result;
  }

  @override
  Future<Result<InstalledPack>> install(InstallRequest request) async {
    final id = request.packId;
    if (!InstalledPacksStore.isValidId(id)) return Failure(InvalidPackId(id));
    for (final url in request.urls) {
      if (!_policy.allows(url)) return Failure(UrlNotAllowed(id, url));
    }
    if (await _unavailable() case final failure?) return Failure(failure);
    if (_installed.any(
      (pack) =>
          pack.id == id &&
          (pack.version == request.version ||
              pack.previousVersion == request.version),
    )) {
      return Failure(AlreadyInstalled(id, request.version));
    }
    if (_jobOf(id) != null || _changing.contains(id)) {
      return Failure(AlreadyQueued(id));
    }
    _failed.remove(id);
    final job = _Job(request);
    _queue.add(job);
    _notify();
    unawaited(_drain());
    return job.result.future;
  }

  @override
  Future<void> pause(String packId) async {
    final job = _jobOf(packId);
    if (job == null || job.paused || job.state is InstallVerifying) return;
    job.paused = true;
    _set(job, InstallPaused(job.progress));
    if (job.order case final order?) {
      // A task the plugin cannot pause is ended; it starts again on resume.
      if (!await _downloads.pause(order) && job.paused && job.order == order) {
        await _downloads.cancel(order);
      }
    }
  }

  @override
  Future<void> resume(String packId) async {
    final job = _jobOf(packId);
    if (job == null || !job.held) return;
    job
      ..paused = false
      ..lowSpace = false;
    final order = job.order;
    _set(
      job,
      order == null ? const InstallQueued() : InstallDownloading(job.progress),
    );
    job.wake();
    if (order != null) await _downloads.resume(order);
  }

  @override
  Future<void> cancel(String packId) async {
    if (_failed.remove(packId) != null) _notify();
    final job = _jobOf(packId);
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
    await _discardStaging(job.request);
    job.result.complete(Failure(InstallCancelled(packId)));
  }

  @override
  Future<Result<InstalledPack>> rollback(String packId) async {
    if (await _unavailable() case final failure?) return Failure(failure);
    if (_jobOf(packId) != null || !_changing.add(packId)) {
      return Failure(AlreadyQueued(packId));
    }
    try {
      switch (await _store!.rollback(packId)) {
        case Failure(:final error):
          return Failure(error);
        case Ok(:final value):
          await _reloadAfterChange(packId);
          return switch (_installed
              .where((pack) => pack.id == packId)
              .firstOrNull) {
            final pack? => Ok(pack),
            null => Failure(
              StoreFailed(
                packId,
                'manifest of version ${value.active} not readable',
              ),
            ),
          };
      }
    } on Exception catch (e) {
      return Failure(StoreFailed(packId, '$e'));
    } finally {
      _changing.remove(packId);
    }
  }

  @override
  Future<Result<void>> delete(String packId) async {
    if (await _unavailable() case final failure?) return Failure(failure);
    if (_jobOf(packId) != null || !_changing.add(packId)) {
      return Failure(AlreadyQueued(packId));
    }
    try {
      final result = await _store!.delete(packId);
      if (result is Ok) {
        await _reloadAfterChange(packId);
      } else {
        await _reload();
      }
      return result;
    } on Exception catch (e) {
      return Failure(StoreFailed(packId, '$e'));
    } finally {
      _changing.remove(packId);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_networkChanges?.cancel());
    super.dispose();
  }

  /// Why nothing can be changed: the store did not open.
  Future<Exception?> _unavailable() async => switch (await started) {
    Failure(:final error) when _store == null => error,
    _ => null,
  };

  _Job? _jobOf(String packId) =>
      _queue.where((job) => job.request.packId == packId).firstOrNull;

  Future<void> _drain() async {
    if (_current != null || !_started.isCompleted) return;
    while (_queue.isNotEmpty) {
      final job = _current = _queue.first;
      final result = await _run(job);
      _queue.remove(job);
      _current = null;
      if (result case Failure(
        error: final InstallFailure failure,
      ) when failure is! InstallCancelled) {
        _failed[job.request.packId] = InstallJob(
          job.request,
          InstallFailed(failure),
        );
      }
      job.result.complete(result);
      _notify();
    }
  }

  Future<Result<InstalledPack>> _run(_Job job) async {
    final request = job.request;
    Result<InstalledPack> result;
    try {
      result = await _install(job);
    } on Exception catch (e) {
      result = Failure(StoreFailed(request.packId, '$e'));
    }
    if (result case Failure(
      error: ManifestRejected() ||
          FileRejected() ||
          VerificationFailed() ||
          SignatureNotChecked() ||
          InstallCancelled(),
    )) {
      await _discardStaging(request);
    }
    return result;
  }

  Future<Result<InstalledPack>> _install(_Job job) async {
    final request = job.request;
    final id = request.packId;
    final staging = job.staging = await _store!.prepareStaging(
      id,
      request.version,
    );

    if (await _fetchManifest(job) case final failure?) return Failure(failure);
    if (request.signature case final url?
        when await _files.sizeOf('$staging/$_signature') == null) {
      if (await _fetch(job, _signature, url) case final failure?) {
        return Failure(failure);
      }
    }

    final PackManifest manifest;
    switch (await _readManifest(staging)) {
      case Ok(:final value):
        manifest = value;
      case Failure(error: final PackFailure failure):
        return Failure(VerificationFailed(id, failure));
      case Failure(:final error):
        return Failure(StoreFailed(id, '$error'));
    }
    for (final file in manifest.files) {
      if (!request.files.containsKey(file.name)) {
        return Failure(FileUrlMissing(id, file.name));
      }
    }

    final missing = [
      for (final file in manifest.files)
        if (!await _matches('$staging/${file.name}', file.bytes, file.sha256))
          file,
    ];
    job.total = missing.fold<int>(0, (sum, file) => sum + file.bytes);
    if (await _waitForSpace(job) case final failure?) return Failure(failure);
    for (final file in missing) {
      if (await _refetch(job, file) case final failure?) {
        return Failure(failure);
      }
    }
    return _verifyAndActivate(job, manifest);
  }

  /// The manifest in staging, matching the request; fetched once more when
  /// it does not.
  Future<InstallFailure?> _fetchManifest(_Job job) async {
    final request = job.request;
    final expected = request.manifest;
    final path = '${job.staging}/$_manifest';
    for (var attempt = 0; attempt < 2; attempt++) {
      if (await _matches(path, expected.bytes, expected.sha256)) return null;
      await _store!.discardStagedFile(
        request.packId,
        request.version,
        _manifest,
      );
      if (await _fetch(job, _manifest, expected.url) case final failure?) {
        return failure;
      }
    }
    return await _matches(path, expected.bytes, expected.sha256)
        ? null
        : ManifestRejected(request.packId);
  }

  Future<Result<PackManifest>> _readManifest(String directory) async {
    final bytes = await _files.readIfExists('$directory/$_manifest');
    if (bytes == null) {
      return Failure(ManifestUnreadable(directory, '$_manifest is missing'));
    }
    return parsePackManifest(bytes, pack: directory);
  }

  Future<Result<InstalledPack>> _verifyAndActivate(
    _Job job,
    PackManifest manifest,
  ) async {
    final request = job.request;
    final id = request.packId;
    final fetchedAgain = <String>{};
    while (true) {
      if (!await _ready(job, network: false)) {
        return Failure(InstallCancelled(id));
      }
      _set(job, const InstallVerifying());
      final VerifiedPack pack;
      switch (await _verifier.verify(job.staging!)) {
        case Ok(:final value):
          pack = value;
        case Failure(error: FileHashMismatch(:final file)):
          if (!fetchedAgain.add(file)) return Failure(FileRejected(id, file));
          final entry = manifest.files.firstWhere((f) => f.name == file);
          job.total = (job.total ?? 0) + entry.bytes;
          if (await _refetch(job, entry) case final failure?) {
            return Failure(failure);
          }
          continue;
        case Failure(error: final PackFailure failure):
          return Failure(VerificationFailed(id, failure));
        case Failure(:final error):
          return Failure(StoreFailed(id, '$error'));
      }
      if (job.cancelled) return Failure(InstallCancelled(id));
      if (!pack.signatureChecked && !_acceptUnchecked) {
        return Failure(SignatureNotChecked(id));
      }
      switch (await _store!.activate(id, request.version)) {
        case Ok(:final value):
          await _reloadAfterChange(id);
          return Ok(
            InstalledPack(
              manifest: pack.manifest,
              directory: value.directory,
              previousVersion: value.previous,
            ),
          );
        case Failure(:final error):
          return Failure(
            error is InstallFailure ? error : StoreFailed(id, '$error'),
          );
      }
    }
  }

  /// Fetches [file] afresh: what staging holds of it is removed first.
  Future<InstallFailure?> _refetch(_Job job, PackFile file) async {
    final request = job.request;
    await _store!.discardStagedFile(request.packId, request.version, file.name);
    final failure = await _fetch(job, file.name, request.files[file.name]!);
    if (failure == null) job.done += file.bytes;
    return failure;
  }

  /// Fetches [url] to [name] in staging; null once it has arrived.
  Future<InstallFailure?> _fetch(_Job job, String name, Uri url) async {
    final request = job.request;
    final id = request.packId;
    while (true) {
      if (!await _ready(job)) return InstallCancelled(id);
      switch (await _urlCheck.checkRedirects(url, _policy)) {
        case Ok():
          break;
        case Failure(error: UrlRefused(url: final to, from: final from?)):
          return RedirectRefused(id, from: from, to: to);
        case Failure(error: UrlRefused(:final url)):
          return UrlNotAllowed(id, url);
        case Failure():
          return DownloadFailed(id, name);
      }
      if (job.cancelled) return InstallCancelled(id);
      if (job.held) continue;

      final order = job.order = FileOrder(
        url: url,
        path:
            '${InstalledPacksStore.stagingRelativePath(id, request.version)}'
            '/$name',
        wifiOnly: request.wifiOnly,
      );
      job.fileReceived = 0;
      _set(job, InstallDownloading(job.progress));
      final outcome = await _downloads.download(
        order,
        (update) => _onUpdate(job, update),
      );
      job
        ..order = null
        ..fileReceived = 0;
      if (job.cancelled) return InstallCancelled(id);
      switch (outcome) {
        case FileDownloaded():
          return null;
        case _ when job.paused:
          continue;
        case FileDownloadNoSpace():
          job.lowSpace = true;
          _set(
            job,
            InstallStoppedLowSpace(
              neededBytes: job.remaining + packSpaceReserveBytes,
              freeBytes: await _freeSpace.freeBytesAt(job.staging!),
            ),
          );
          if (await _waitForSpace(job) case final failure?) return failure;
        case FileDownloadFailed(statusCode: null)
            when !await _networkAllows(request.wifiOnly):
          // The network went for longer than the downloader retries: wait
          // for it, then ask for the file again.
          continue;
        case FileDownloadCanceled():
          return DownloadFailed(id, name);
        case FileDownloadFailed(:final statusCode):
          return DownloadFailed(id, name, statusCode: statusCode);
      }
    }
  }

  /// Waits until the job is not held and, when [network], its network is
  /// up; false when it was cancelled.
  Future<bool> _ready(_Job job, {bool network = true}) async {
    while (!job.cancelled) {
      if (job.held) {
        await job.sleep();
        continue;
      }
      if (!network || await _networkAllows(job.request.wifiOnly)) return true;
      _set(job, InstallWaitingForNetwork(wifiOnly: job.request.wifiOnly));
      await job.sleep();
    }
    return false;
  }

  /// Waits until the device has room for what is left to fetch and the
  /// reserve. An unknown free space never stops the job.
  Future<InstallFailure?> _waitForSpace(_Job job) async {
    while (true) {
      if (!await _ready(job)) return InstallCancelled(job.request.packId);
      final needed = job.remaining + packSpaceReserveBytes;
      final free = await _freeSpace.freeBytesAt(job.staging!);
      if (free == null || free >= needed) return null;
      job.lowSpace = true;
      _set(job, InstallStoppedLowSpace(neededBytes: needed, freeBytes: free));
    }
  }

  /// A task the downloader holds while the job's network is down is shown
  /// as waiting for it; the downloader does not say why it waits (S5).
  void _onUpdate(_Job job, FileTaskUpdate update) {
    if (job.held || job.cancelled) return;
    if (update.progress case final progress?) {
      job.fileReceived = progress.receivedBytes;
    }
    final waiting =
        update.status != FileTaskStatus.running &&
        !_allows(_network, job.request.wifiOnly);
    _set(
      job,
      waiting
          ? InstallWaitingForNetwork(wifiOnly: job.request.wifiOnly)
          : InstallDownloading(job.progress),
    );
  }

  void _onNetwork(NetworkKind kind) {
    _network = kind;
    for (final job in _queue) {
      job.wake();
    }
    final job = _current;
    if (job != null &&
        job.order != null &&
        !job.held &&
        !_allows(kind, job.request.wifiOnly)) {
      _set(job, InstallWaitingForNetwork(wifiOnly: job.request.wifiOnly));
    }
  }

  Future<bool> _networkAllows(bool wifiOnly) async =>
      _allows(_network = await _connectivity.current(), wifiOnly);

  static bool _allows(NetworkKind kind, bool wifiOnly) =>
      wifiOnly ? kind == NetworkKind.unmetered : kind != NetworkKind.none;

  Future<bool> _matches(String path, int bytes, String sha256) async =>
      await _files.sizeOf(path) == bytes &&
      await _files.sha256Of(path) == sha256;

  Future<void> _discardStaging(InstallRequest request) async {
    try {
      await _store?.discardStaging(request.packId, request.version);
    } on Exception {
      // The next attempt checks every staged file against its hash again.
    }
  }

  /// Reads the installed packs; a [Failure] names the first manifest that
  /// could not be read, and that pack is left out.
  /// Reads the packs again after the files of [packId] changed, and tells of
  /// the change whether or not the read worked: what was said of the old
  /// files must not outlive them.
  Future<void> _reloadAfterChange(String packId) async {
    try {
      await _reload();
    } finally {
      _onPackChanged?.call(packId);
    }
  }

  Future<Result<void>> _reload() async {
    final packs = <InstalledPack>[];
    Exception? problem;
    for (final stored in await _store!.readAll()) {
      switch (await _readManifest(stored.directory)) {
        case Ok(:final value):
          packs.add(
            InstalledPack(
              manifest: value,
              directory: stored.directory,
              previousVersion: stored.previous,
            ),
          );
        case Failure(:final error):
          problem ??= error;
      }
    }
    _installed = List.unmodifiable(packs);
    _notify();
    return problem == null ? const Ok(null) : Failure(problem);
  }

  void _set(_Job job, InstallState state) {
    job.state = state;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}

final class _Job {
  _Job(this.request);

  final InstallRequest request;
  final result = Completer<Result<InstalledPack>>();
  InstallState state = const InstallQueued();
  bool paused = false;
  bool lowSpace = false;
  bool cancelled = false;
  String? staging;
  FileOrder? order;

  /// Bytes this attempt fetches, once the manifest is read.
  int? total;
  int done = 0;
  int fileReceived = 0;
  Completer<void>? _sleeper;
  bool _woken = false;

  bool get held => paused || lowSpace;

  int get remaining => (total ?? 0) - done;

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
