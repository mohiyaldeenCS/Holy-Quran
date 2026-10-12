import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/download_progress.dart';

void main() {
  test('fraction is the share received, within 0 and 1', () {
    expect(
      const DownloadProgress(receivedBytes: 25, totalBytes: 100).fraction,
      0.25,
    );
    expect(
      const DownloadProgress(receivedBytes: 120, totalBytes: 100).fraction,
      1,
    );
  });

  test('fraction is null while the size is unknown or zero', () {
    expect(
      const DownloadProgress(receivedBytes: 10, totalBytes: null).fraction,
      isNull,
    );
    expect(
      const DownloadProgress(receivedBytes: 0, totalBytes: 0).fraction,
      isNull,
    );
  });

  test('equal when both counts are equal', () {
    const a = DownloadProgress(receivedBytes: 1, totalBytes: 2);
    expect(a, const DownloadProgress(receivedBytes: 1, totalBytes: 2));
    expect(
      a.hashCode,
      const DownloadProgress(receivedBytes: 1, totalBytes: 2).hashCode,
    );
    expect(
      a,
      isNot(const DownloadProgress(receivedBytes: 1, totalBytes: null)),
    );
    expect(a, isNot(const DownloadProgress(receivedBytes: 2, totalBytes: 2)));
    expect('$a', 'DownloadProgress(1/2)');
  });
}
