import 'download_progress.dart';
import 'recitation_target.dart';

/// A download of a recitation's audio and how it stands (`AU-13`).
final class RecitationDownloadJob {
  const RecitationDownloadJob(this.target, this.state);

  final RecitationTarget target;
  final RecitationDownloadState state;

  String get key => target.key;
}

sealed class RecitationDownloadState {
  const RecitationDownloadState();
}

/// Waiting for the jobs before it.
final class RecitationQueued extends RecitationDownloadState {
  const RecitationQueued();
}

/// Waiting for a network; for Wi-Fi when [wifiOnly].
final class RecitationWaitingForNetwork extends RecitationDownloadState {
  const RecitationWaitingForNetwork({required this.wifiOnly});

  final bool wifiOnly;
}

/// [progress] counts the bytes still to fetch when the job began, so a file
/// already on the device is not part of it.
final class RecitationDownloading extends RecitationDownloadState {
  const RecitationDownloading(this.progress);

  final DownloadProgress progress;
}

/// The job ended without finishing; it stays listed until it is cancelled
/// or requested again. What arrived before is kept.
final class RecitationDownloadFailed extends RecitationDownloadState {
  const RecitationDownloadFailed(this.failure);

  final RecitationDownloadFailure failure;
}

/// Why a recitation download stopped, or was refused.
sealed class RecitationDownloadFailure implements Exception {
  const RecitationDownloadFailure(this.key);

  final String key;
}

/// A job for this download is in the queue.
final class RecitationAlreadyQueued extends RecitationDownloadFailure {
  const RecitationAlreadyQueued(super.key);

  @override
  String toString() => 'RecitationAlreadyQueued($key)';
}

/// The download was stopped by the user.
final class RecitationDownloadCancelled extends RecitationDownloadFailure {
  const RecitationDownloadCancelled(super.key);

  @override
  String toString() => 'RecitationDownloadCancelled($key)';
}

/// The URL is not one the download policy allows, or leads to one.
final class RecitationUrlRefused extends RecitationDownloadFailure {
  const RecitationUrlRefused(super.key, this.url);

  final Uri url;

  @override
  String toString() => 'RecitationUrlRefused($key): $url';
}

/// [path] did not arrive.
final class RecitationFileNotFetched extends RecitationDownloadFailure {
  const RecitationFileNotFetched(super.key, this.path, {this.statusCode});

  final String path;
  final int? statusCode;

  @override
  String toString() =>
      'RecitationFileNotFetched($key): $path'
      '${statusCode == null ? '' : ' (HTTP $statusCode)'}';
}

/// [path] differed from the size or SHA-256 its pack states, also when
/// fetched once more; it was not kept.
final class RecitationFileRejected extends RecitationDownloadFailure {
  const RecitationFileRejected(super.key, this.path);

  final String path;

  @override
  String toString() => 'RecitationFileRejected($key): $path';
}

/// The device lacks room for what is left to fetch. [freeBytes] is null
/// when the device did not say.
final class RecitationNoSpace extends RecitationDownloadFailure {
  const RecitationNoSpace(
    super.key, {
    required this.neededBytes,
    this.freeBytes,
  });

  final int neededBytes;
  final int? freeBytes;

  @override
  String toString() => 'RecitationNoSpace($key): $neededBytes, $freeBytes';
}

/// The audio on the device could not be read or changed.
final class RecitationStoreFailed extends RecitationDownloadFailure {
  const RecitationStoreFailed(super.key, this.reason);

  final String reason;

  @override
  String toString() => 'RecitationStoreFailed($key): $reason';
}
