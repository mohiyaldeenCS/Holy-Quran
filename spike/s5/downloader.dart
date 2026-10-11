import 'dart:io';

/// Downloads one URL to one file. A call completes only with a final
/// outcome; a wait for the required network is a [DownloadState], because
/// the native downloader waits by itself and carries on when the network
/// returns.
abstract interface class SpikeDownloader {
  Future<DownloadOutcome> download(
    Uri url,
    File target, {
    required bool wifiOnly,
    DownloadListener? onProgress,
  });
}

typedef DownloadListener = void Function(DownloadProgress progress);

enum DownloadState { queued, waitingForNetwork, running, retrying, paused }

final class DownloadProgress {
  const DownloadProgress(this.state, {this.received, this.total});

  final DownloadState state;

  /// Bytes in the target so far, when the downloader reports them.
  final int? received;
  final int? total;

  @override
  String toString() => switch ((received, total)) {
    (final r?, final t?) => '${state.name} $r/$t',
    _ => state.name,
  };
}

sealed class DownloadOutcome {
  const DownloadOutcome();
}

final class DownloadCompleted extends DownloadOutcome {
  const DownloadCompleted();

  @override
  String toString() => 'completed';
}

/// The server answered 404. A pack's `manifest.json.sig` may be absent.
final class DownloadNotFound extends DownloadOutcome {
  const DownloadNotFound();

  @override
  String toString() => 'not found';
}

/// The device lacks the space the space check asks for; nothing was written
/// to the target.
final class DownloadInsufficientSpace extends DownloadOutcome {
  const DownloadInsufficientSpace();

  @override
  String toString() => 'insufficient space';
}

final class DownloadFailed extends DownloadOutcome {
  const DownloadFailed(this.reason, {this.statusCode});

  final String reason;
  final int? statusCode;

  @override
  String toString() =>
      'failed: $reason${statusCode == null ? '' : ' (HTTP $statusCode)'}';
}
