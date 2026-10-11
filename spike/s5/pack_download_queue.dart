import 'dart:async';
import 'dart:io';

import 'package:holyquran/data/models/pack_manifest_json.dart';
import 'package:holyquran/data/repositories/pack_repository.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/verified_pack.dart';
import 'package:holyquran/utils/result.dart';

import 'downloader.dart';
import 'pack_store.dart';

/// One pack to fetch. [base] is the URL of the pack's directory and ends
/// with `/`; each file is fetched at `base.resolve(name)`.
final class PackRequest {
  const PackRequest({
    required this.id,
    required this.version,
    required this.base,
    this.wifiOnly = true,
  });

  final String id;
  final int version;
  final Uri base;
  final bool wifiOnly;

  @override
  String toString() => '$id/$version';
}

enum NotActivatedReason {
  versionExists,
  download,
  insufficientSpace,
  verification,
  store,
}

sealed class PackOutcome {
  const PackOutcome();
}

final class PackActivated extends PackOutcome {
  const PackActivated(this.versions, {required this.signatureChecked});

  final PackVersions versions;

  /// False while no signing key exists. The spike activates such a pack;
  /// a release refuses it (D-065).
  final bool signatureChecked;

  @override
  String toString() =>
      'activated ${versions.active} (previous ${versions.previous}, '
      'signature ${signatureChecked ? 'valid' : 'NOT CHECKED'})';
}

/// The pack was not activated; the active version, if any, is unchanged
/// and the staging directory is gone.
final class PackNotActivated extends PackOutcome {
  const PackNotActivated(this.reason, this.detail);

  final NotActivatedReason reason;
  final String detail;

  @override
  String toString() => 'not activated (${reason.name}): $detail';
}

sealed class QueueEvent {
  const QueueEvent(this.request);

  final PackRequest request;
}

final class PackQueued extends QueueEvent {
  const PackQueued(super.request);

  @override
  String toString() => '$request queued';
}

final class PackStarted extends QueueEvent {
  const PackStarted(super.request);

  @override
  String toString() => '$request started';
}

final class FileProgressed extends QueueEvent {
  const FileProgressed(super.request, this.file, this.progress);

  final String file;
  final DownloadProgress progress;

  @override
  String toString() => '$request $file $progress';
}

final class FileFinished extends QueueEvent {
  const FileFinished(super.request, this.file, this.outcome);

  final String file;
  final DownloadOutcome outcome;

  @override
  String toString() => '$request $file $outcome';
}

/// Verification found [file] different from the manifest.
final class FileRejected extends QueueEvent {
  const FileRejected(super.request, this.file, {required this.willRetry});

  final String file;
  final bool willRetry;

  @override
  String toString() =>
      '$request $file rejected by verification'
      '${willRetry ? ', fetching it once more' : ''}';
}

final class PackFinished extends QueueEvent {
  const PackFinished(super.request, this.outcome);

  final PackOutcome outcome;

  @override
  String toString() => '$request $outcome';
}

/// Fetches packs one at a time: the manifest and its signature, when the
/// server has one, into staging; then the files the manifest lists; then
/// [PackRepository.verify]. A file that fails verification is fetched once
/// more; a second failure leaves the pack out. A verified pack is
/// activated in the [PackStore]; otherwise staging is deleted and the
/// active version stays.
final class PackDownloadQueue {
  PackDownloadQueue({
    required this._downloader,
    required this._store,
    required this._verifier,
  });

  static const _manifest = 'manifest.json';
  static const _signature = 'manifest.json.sig';

  final SpikeDownloader _downloader;
  final PackStore _store;
  final PackRepository _verifier;
  final StreamController<QueueEvent> _events = StreamController.broadcast(
    sync: true,
  );
  Future<void> _tail = Future.value();

  Stream<QueueEvent> get events => _events.stream;

  Future<PackOutcome> enqueue(PackRequest request) {
    _emit(PackQueued(request));
    final outcome = _tail.then((_) => _run(request));
    _tail = outcome.then<void>((_) {}, onError: (Object _) {});
    return outcome;
  }

  Future<void> close() => _events.close();

  Future<PackOutcome> _run(PackRequest request) async {
    _emit(PackStarted(request));
    final PackOutcome outcome;
    try {
      outcome = await _fetch(request);
    } on Exception catch (e) {
      return _finish(request, PackNotActivated(NotActivatedReason.store, '$e'));
    }
    return _finish(request, outcome);
  }

  Future<PackOutcome> _finish(PackRequest request, PackOutcome outcome) async {
    if (outcome is PackNotActivated) {
      try {
        await _store.discardStaging(request.id, request.version);
      } on FileSystemException {
        // recover() deletes it at the next start.
      }
    }
    _emit(PackFinished(request, outcome));
    return outcome;
  }

  Future<PackOutcome> _fetch(PackRequest request) async {
    if (await _store.hasVersion(request.id, request.version)) {
      return const PackNotActivated(
        NotActivatedReason.versionExists,
        'this version is installed already',
      );
    }
    final staging = await _store.stagingFor(request.id, request.version);

    if (_refusal(_manifest, await _download(request, staging, _manifest))
        case final refused?) {
      return refused;
    }
    switch (await _download(request, staging, _signature)) {
      case DownloadCompleted() || DownloadNotFound():
        break;
      case final outcome:
        return _refusal(_signature, outcome)!;
    }

    final manifestBytes = await File(
      '${staging.path}/$_manifest',
    ).readAsBytes();
    final List<String> files;
    switch (parsePackManifest(manifestBytes, pack: staging.path)) {
      case Ok(:final value):
        files = [for (final file in value.files) file.name];
      case Failure(:final error):
        return PackNotActivated(NotActivatedReason.verification, '$error');
    }
    for (final file in files) {
      if (_refusal(file, await _download(request, staging, file))
          case final refused?) {
        return refused;
      }
    }

    var verified = await _verifier.verify(staging.path);
    if (verified case Failure(error: FileHashMismatch(:final file))) {
      _emit(FileRejected(request, file, willRetry: true));
      final rejected = File('${staging.path}/$file');
      if (await rejected.exists()) await rejected.delete();
      if (_refusal(file, await _download(request, staging, file))
          case final refused?) {
        return refused;
      }
      verified = await _verifier.verify(staging.path);
      if (verified case Failure(error: FileHashMismatch(:final file))) {
        _emit(FileRejected(request, file, willRetry: false));
      }
    }
    final VerifiedPack pack;
    switch (verified) {
      case Ok(:final value):
        pack = value;
      case Failure(:final error):
        return PackNotActivated(NotActivatedReason.verification, '$error');
    }

    return switch (await _store.activate(request.id, request.version)) {
      Ok(:final value) => PackActivated(
        value,
        signatureChecked: pack.signatureChecked,
      ),
      Failure(:final error) => PackNotActivated(
        error is VersionExists
            ? NotActivatedReason.versionExists
            : NotActivatedReason.store,
        '$error',
      ),
    };
  }

  Future<DownloadOutcome> _download(
    PackRequest request,
    Directory staging,
    String name,
  ) async {
    final outcome = await _downloader.download(
      request.base.resolve(name),
      File('${staging.path}/$name'),
      wifiOnly: request.wifiOnly,
      onProgress: (progress) => _emit(FileProgressed(request, name, progress)),
    );
    _emit(FileFinished(request, name, outcome));
    return outcome;
  }

  /// Why the pack stops when [name] ended with [outcome]; null when it
  /// arrived.
  static PackNotActivated? _refusal(String name, DownloadOutcome outcome) =>
      switch (outcome) {
        DownloadCompleted() => null,
        DownloadInsufficientSpace() => PackNotActivated(
          NotActivatedReason.insufficientSpace,
          '$name: $outcome',
        ),
        DownloadNotFound() || DownloadFailed() => PackNotActivated(
          NotActivatedReason.download,
          '$name: $outcome',
        ),
      };

  void _emit(QueueEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}
