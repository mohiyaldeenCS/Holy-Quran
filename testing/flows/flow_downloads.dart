import 'dart:io';
import 'dart:typed_data';

import 'package:holyquran/data/services/connectivity_service.dart';
import 'package:holyquran/data/services/download_service.dart';
import 'package:holyquran/data/services/free_space_service.dart';

/// The downloader plugin, replaced by one that fetches over HTTP with
/// `dart:io` into the folder [_root] finds, the folder the app downloads under. Nothing
/// resumes within a file; the installer's own resuming across files is the
/// real one.
final class LoopbackDownloads implements DownloadService {
  const LoopbackDownloads(this._root);

  final Future<String> Function() _root;

  @override
  Future<void> start() async {}

  @override
  Future<FileDownloadOutcome> download(
    FileOrder order,
    void Function(FileTaskUpdate update) onUpdate,
  ) async {
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(order.url)).close();
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return FileDownloadFailed(
          'status ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response) {
        bytes.add(chunk);
        onUpdate((status: FileTaskStatus.running, progress: null));
      }
      final target = File('${await _root()}/${order.path}');
      await target.parent.create(recursive: true);
      final partial = File('${target.path}.part');
      await partial.writeAsBytes(bytes.takeBytes(), flush: true);
      await partial.rename(target.path);
      return const FileDownloaded();
    } on IOException catch (error) {
      return FileDownloadFailed('$error');
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<bool> pause(FileOrder order) async => false;

  @override
  Future<void> resume(FileOrder order) async {}

  @override
  Future<void> cancel(FileOrder order) async {}
}

/// A device on an unmetered network.
final class UnmeteredNetwork implements ConnectivityService {
  const UnmeteredNetwork();

  @override
  Future<NetworkKind> current() async => NetworkKind.unmetered;

  @override
  Stream<NetworkKind> get changes => const Stream.empty();
}

/// A device with a gibibyte free.
final class RoomyDisk implements FreeSpaceService {
  const RoomyDisk();

  @override
  Future<int?> freeBytesAt(String directory) async => 1 << 30;
}
