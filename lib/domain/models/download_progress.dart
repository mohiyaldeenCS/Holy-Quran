/// How much of a download has arrived. [totalBytes] is null while the size is
/// not known.
final class DownloadProgress {
  const DownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
  });

  final int receivedBytes;
  final int? totalBytes;

  /// Between 0 and 1, or null while the size is not known.
  double? get fraction => switch (totalBytes) {
    final total? when total > 0 => (receivedBytes / total).clamp(0, 1),
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      other is DownloadProgress &&
      other.receivedBytes == receivedBytes &&
      other.totalBytes == totalBytes;

  @override
  int get hashCode => Object.hash(receivedBytes, totalBytes);

  @override
  String toString() => 'DownloadProgress($receivedBytes/$totalBytes)';
}
