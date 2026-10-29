import 'download_progress.dart';
import 'pack_failure.dart';

/// A file at [url] whose size and SHA-256 are known before it is fetched.
final class RemoteFile {
  const RemoteFile({
    required this.url,
    required this.sha256,
    required this.bytes,
  });

  final Uri url;
  final String sha256;
  final int bytes;
}

/// One version of one pack to install, as the catalogue describes it. Each
/// file has its own URL, because release assets are not laid out as a
/// directory; [files] is keyed by the file names the manifest lists.
final class InstallRequest {
  InstallRequest({
    required this.packId,
    required this.version,
    required this.manifest,
    required this.signature,
    required Map<String, Uri> files,
    required this.wifiOnly,
  }) : files = Map.unmodifiable(files);

  final String packId;
  final int version;
  final RemoteFile manifest;

  /// The URL of `manifest.json.sig`; null when the catalogue names none.
  final Uri? signature;
  final Map<String, Uri> files;
  final bool wifiOnly;

  /// Every URL the request names.
  Iterable<Uri> get urls => [manifest.url, ?signature, ...files.values];
}

final class InstallJob {
  const InstallJob(this.request, this.state);

  final InstallRequest request;
  final InstallState state;
}

sealed class InstallState {
  const InstallState();
}

/// Waiting for the jobs before it.
final class InstallQueued extends InstallState {
  const InstallQueued();
}

/// Waiting for a network; for Wi-Fi when [wifiOnly].
final class InstallWaitingForNetwork extends InstallState {
  const InstallWaitingForNetwork({required this.wifiOnly});

  final bool wifiOnly;
}

final class InstallDownloading extends InstallState {
  const InstallDownloading(this.progress);

  final DownloadProgress progress;
}

/// Paused by the user; the queue waits behind it.
final class InstallPaused extends InstallState {
  const InstallPaused(this.progress);

  final DownloadProgress progress;
}

final class InstallVerifying extends InstallState {
  const InstallVerifying();
}

/// The device lacks space. The queue waits behind this job until it is
/// resumed, which checks the space again. [freeBytes] is null when the
/// device did not say.
final class InstallStoppedLowSpace extends InstallState {
  const InstallStoppedLowSpace({
    required this.neededBytes,
    required this.freeBytes,
  });

  final int neededBytes;
  final int? freeBytes;
}

/// The job ended without installing; it stays listed until it is cancelled
/// or requested again.
final class InstallFailed extends InstallState {
  const InstallFailed(this.failure);

  final InstallFailure failure;
}

/// Why a pack was not installed, rolled back or deleted.
sealed class InstallFailure implements Exception {
  const InstallFailure(this.packId);

  final String packId;
}

final class InvalidPackId extends InstallFailure {
  const InvalidPackId(super.packId);

  @override
  String toString() => 'InvalidPackId($packId)';
}

/// The id is the bundled base pack's, whose files live in the same folder
/// and which no catalogue entry may replace, roll back or delete.
final class ReservedPackId extends InstallFailure {
  const ReservedPackId(super.packId);

  @override
  String toString() => 'ReservedPackId($packId)';
}

/// The URL is not one the download policy allows.
final class UrlNotAllowed extends InstallFailure {
  const UrlNotAllowed(super.packId, this.url);

  final Uri url;

  @override
  String toString() => 'UrlNotAllowed($packId): $url';
}

/// [from] redirects to [to], which the policy refuses, or one hop too many.
final class RedirectRefused extends InstallFailure {
  const RedirectRefused(super.packId, {required this.from, required this.to});

  final Uri from;
  final Uri to;

  @override
  String toString() => 'RedirectRefused($packId): $from to $to';
}

/// This version is installed already, active or kept as the previous one.
final class AlreadyInstalled extends InstallFailure {
  const AlreadyInstalled(super.packId, this.version);

  final int version;

  @override
  String toString() => 'AlreadyInstalled($packId): $version';
}

/// A job for this pack is in the queue.
final class AlreadyQueued extends InstallFailure {
  const AlreadyQueued(super.packId);

  @override
  String toString() => 'AlreadyQueued($packId)';
}

/// The manifest lists [file] and the request gives no URL for it.
final class FileUrlMissing extends InstallFailure {
  const FileUrlMissing(super.packId, this.file);

  final String file;

  @override
  String toString() => 'FileUrlMissing($packId): $file';
}

/// [file] did not arrive. [statusCode] is the server's answer, when there
/// was one. What arrived before stays staged for the next attempt.
final class DownloadFailed extends InstallFailure {
  const DownloadFailed(super.packId, this.file, {this.statusCode});

  final String file;
  final int? statusCode;

  @override
  String toString() =>
      'DownloadFailed($packId): $file'
      '${statusCode == null ? '' : ' (HTTP $statusCode)'}';
}

/// The manifest differed from the size and SHA-256 the request names, twice.
final class ManifestRejected extends InstallFailure {
  const ManifestRejected(super.packId);

  @override
  String toString() => 'ManifestRejected($packId)';
}

/// [file] differed from its manifest entry, also when fetched once more.
final class FileRejected extends InstallFailure {
  const FileRejected(super.packId, this.file);

  final String file;

  @override
  String toString() => 'FileRejected($packId): $file';
}

final class VerificationFailed extends InstallFailure {
  const VerificationFailed(super.packId, this.failure);

  final PackFailure failure;

  @override
  String toString() => 'VerificationFailed($packId): $failure';
}

/// The signature could not be checked, and this build accepts only a valid
/// one (D-108).
final class SignatureNotChecked extends InstallFailure {
  const SignatureNotChecked(super.packId);

  @override
  String toString() => 'SignatureNotChecked($packId)';
}

final class InstallCancelled extends InstallFailure {
  const InstallCancelled(super.packId);

  @override
  String toString() => 'InstallCancelled($packId)';
}

/// The packs on the device could not be read or changed.
final class StoreFailed extends InstallFailure {
  const StoreFailed(super.packId, this.reason);

  final String reason;

  @override
  String toString() => 'StoreFailed($packId): $reason';
}

final class NoPreviousVersion extends InstallFailure {
  const NoPreviousVersion(super.packId);

  @override
  String toString() => 'NoPreviousVersion($packId)';
}
