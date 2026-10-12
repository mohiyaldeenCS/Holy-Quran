import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/download_progress.dart';
import 'package:holyquran/domain/models/install_job.dart';
import 'package:holyquran/domain/models/pack_failure.dart';

final _manifest = RemoteFile(
  url: Uri.parse('https://example.invalid/synthetic/manifest.json'),
  sha256: '0' * 64,
  bytes: 10,
);

InstallRequest _request({Uri? signature, Map<String, Uri>? files}) =>
    InstallRequest(
      packId: 'synthetic-text',
      version: 1,
      manifest: _manifest,
      signature: signature,
      files: files ?? {'text.sqlite': Uri.parse('https://example.invalid/t')},
      wifiOnly: true,
    );

void main() {
  group('InstallRequest', () {
    test('keeps its own unmodifiable copy of the files', () {
      final files = {'text.sqlite': Uri.parse('https://example.invalid/t')};
      final request = _request(files: files);
      files['other'] = Uri.parse('https://example.invalid/o');
      expect(request.files.keys, ['text.sqlite']);
      expect(
        () => request.files['other'] = Uri.parse('https://example.invalid/o'),
        throwsUnsupportedError,
      );
    });

    test(
      'urls names the manifest, the signature when given, and the files',
      () {
        final signature = Uri.parse(
          'https://example.invalid/manifest.json.sig',
        );
        expect(_request().urls, [
          _manifest.url,
          Uri.parse('https://example.invalid/t'),
        ]);
        expect(_request(signature: signature).urls, [
          _manifest.url,
          signature,
          Uri.parse('https://example.invalid/t'),
        ]);
      },
    );
  });

  test('a job pairs a request with its state', () {
    final request = _request();
    const progress = DownloadProgress(receivedBytes: 1, totalBytes: 2);
    final job = InstallJob(request, const InstallPaused(progress));
    expect(job.request, same(request));
    expect((job.state as InstallPaused).progress, progress);
  });

  test('failures name the pack and what went wrong', () {
    const id = 'synthetic-text';
    final url = Uri.parse('http://example.invalid/x');
    final failures = <InstallFailure, String>{
      const InvalidPackId(id): 'InvalidPackId($id)',
      UrlNotAllowed(id, url): 'UrlNotAllowed($id): $url',
      RedirectRefused(id, from: _manifest.url, to: url):
          'RedirectRefused($id): ${_manifest.url} to $url',
      const AlreadyInstalled(id, 2): 'AlreadyInstalled($id): 2',
      const AlreadyQueued(id): 'AlreadyQueued($id)',
      const FileUrlMissing(id, 'f'): 'FileUrlMissing($id): f',
      const DownloadFailed(id, 'f'): 'DownloadFailed($id): f',
      const DownloadFailed(id, 'f', statusCode: 404):
          'DownloadFailed($id): f (HTTP 404)',
      const ManifestRejected(id): 'ManifestRejected($id)',
      const FileRejected(id, 'f'): 'FileRejected($id): f',
      const VerificationFailed(id, SignatureRejected('dir')):
          'VerificationFailed($id): SignatureRejected(dir)',
      const SignatureNotChecked(id): 'SignatureNotChecked($id)',
      const InstallCancelled(id): 'InstallCancelled($id)',
      const StoreFailed(id, 'synthetic'): 'StoreFailed($id): synthetic',
      const NoPreviousVersion(id): 'NoPreviousVersion($id)',
    };
    for (final MapEntry(key: failure, value: text) in failures.entries) {
      expect(failure.packId, id);
      expect('$failure', text);
    }
  });
}
