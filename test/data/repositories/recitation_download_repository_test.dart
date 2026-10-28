import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/recitation_download_repository.dart';
import 'package:holyquran/data/services/connectivity_service.dart';
import 'package:holyquran/data/services/download_service.dart';
import 'package:holyquran/data/services/free_space_service.dart';
import 'package:holyquran/data/services/recitation_file_store.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_range.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/domain/models/recitation_download.dart';
import 'package:holyquran/domain/models/recitation_file.dart';
import 'package:holyquran/domain/models/recitation_target.dart';
import 'package:holyquran/utils/result.dart';

// The repository runs against a fake downloader that writes synthetic bytes
// into the download root; no network is used and no byte is a recording.

const _pack = 'synthetic-recitation';
const _policy = UrlPolicy(scheme: 'https');

/// A synthetic audio file and the file row that describes it.
(RecitationFile, Uint8List) _file(
  int quality,
  int surah,
  int? ayah, {
  int size = 40,
}) {
  final bytes = Uint8List.fromList([
    for (var i = 0; i < size; i++)
      (quality + surah * 7 + (ayah ?? 0) * 3 + i) % 251,
  ]);
  return (
    RecitationFile(
      qualityKbps: quality,
      part: ayah == null ? RecitationFilePart.surah : RecitationFilePart.ayah,
      surah: surah,
      ayah: ayah,
      path: 'q$quality/${surah}_${ayah ?? 0}.mp3',
      bytes: bytes.length,
      sha256: sha256.convert(bytes).toString(),
      duration: null,
    ),
    bytes,
  );
}

final class _Downloads implements DownloadService {
  _Downloads(this.root, this.bodies);

  final String root;

  /// What the server holds, by URL path.
  final Map<String, Uint8List> bodies;
  final List<FileOrder> orders = [];

  /// How many more downloads of a URL path arrive with one byte inverted.
  final Map<String, int> corrupt = {};

  /// A download of a URL path that waits for its gate.
  final Map<String, Completer<void>> gates = {};
  final StreamController<String> reached = StreamController.broadcast();
  final Map<String, Completer<FileDownloadOutcome>> _ends = {};

  @override
  Future<void> start() async {}

  @override
  Future<FileDownloadOutcome> download(
    FileOrder order,
    void Function(FileTaskUpdate update) onUpdate,
  ) async {
    orders.add(order);
    final path = order.url.path;
    final ended = _ends[path] = Completer();
    if (gates[path] case final gate?) {
      reached.add(path);
      final outcome = await Future.any([
        gate.future.then((_) => null),
        ended.future,
      ]);
      if (outcome != null) return outcome;
    }
    final body = bodies[path];
    if (body == null) return const FileDownloadFailed('gone', statusCode: 404);
    final bytes = Uint8List.fromList(body);
    if ((corrupt[path] ?? 0) > 0) {
      corrupt[path] = corrupt[path]! - 1;
      bytes[bytes.length ~/ 2] ^= 0xFF;
    }
    onUpdate((status: FileTaskStatus.running, progress: null));
    final target = File('$root/${order.path}');
    await target.parent.create(recursive: true);
    await target.writeAsBytes(bytes);
    return const FileDownloaded();
  }

  @override
  Future<bool> pause(FileOrder order) async => false;

  @override
  Future<void> resume(FileOrder order) async {}

  @override
  Future<void> cancel(FileOrder order) async {
    _ends[order.url.path]?.complete(const FileDownloadCanceled());
  }
}

final class _Network implements ConnectivityService {
  NetworkKind kind = NetworkKind.unmetered;
  final StreamController<NetworkKind> _changes = StreamController.broadcast();

  void set(NetworkKind value) => _changes.add(kind = value);

  @override
  Future<NetworkKind> current() async => kind;

  @override
  Stream<NetworkKind> get changes => _changes.stream;
}

final class _Space implements FreeSpaceService {
  int? free;

  @override
  Future<int?> freeBytesAt(String directory) async => free;
}

final class _Urls implements UrlCheck {
  @override
  Future<Result<Uri>> checkRedirects(Uri url, UrlPolicy policy) async =>
      Ok(url);
}

void main() {
  late Directory temp;
  late String audio;
  late RecitationContents contents;
  late _Downloads downloads;
  late _Network network;
  late _Space space;
  late LocalRecitationDownloadRepository repository;
  late RecitationFileStore store;
  var runs = 0;

  RecitationTarget target(RecitationSelection selection, {int quality = 64}) =>
      RecitationTarget(contents, quality, selection);

  RecitationFile fileOf(int quality, int surah, int ayah) =>
      contents.files.singleWhere(
        (f) => f.qualityKbps == quality && f.surah == surah && f.ayah == ayah,
      );

  String finalPath(RecitationFile file) => '$audio/$_pack/${file.sha256}.mp3';

  setUp(() async {
    temp = await Directory.systemTemp.createTemp(
      'recitation_download_${runs++}_',
    );
    audio = '${temp.path}/${RecitationFileStore.directoryName}';
    final made = [
      for (final quality in [64, 128])
        for (final (surah, ayat) in [(1, 3), (2, 2)])
          for (var ayah = 1; ayah <= ayat; ayah++) _file(quality, surah, ayah),
    ];
    contents = RecitationContents(
      recitationId: 'synthetic-listed',
      packId: _pack,
      baseUrl: Uri.parse('https://example.invalid/synthetic/'),
      unit: RecitationUnit.ayah,
      files: [for (final (file, _) in made) file],
    );
    downloads = _Downloads(temp.path, {
      for (final (file, bytes) in made) '/synthetic/${file.path}': bytes,
    });
    network = _Network();
    space = _Space();
    store = RecitationFileStore(audioDirectory: () async => audio);
    repository = LocalRecitationDownloadRepository(
      contents: (id) async => Ok(contents),
      downloads: downloads,
      urlCheck: _Urls(),
      connectivity: network,
      freeSpace: space,
      store: store,
      policy: _policy,
    );
  });

  tearDown(() async {
    repository.dispose();
    await temp.delete(recursive: true);
  });

  group('selections', () {
    test('a surah holds the files of that surah and nothing else', () {
      final files = target(const RecitationSurah(2)).files;

      expect(files.map((f) => f.surah).toSet(), {2});
      expect(files, hasLength(2));
    });

    test('a juz span holds the ayat of its range at the quality asked', () {
      final range = QuranRange(
        QuranAddress('hafs', 1, 3),
        QuranAddress('hafs', 2, 1),
      );
      final files = target(RecitationSpan(range), quality: 128).files;

      expect(files.map((f) => (f.surah, f.ayah)), [(1, 3), (2, 1)]);
      expect(files.every((f) => f.qualityKbps == 128), isTrue);
    });

    test('a surah recitation takes the whole surah a span touches', () {
      final (file, _) = _file(64, 2, null);
      final span = RecitationSpan(
        QuranRange(QuranAddress('hafs', 1, 5), QuranAddress('hafs', 2, 1)),
      );

      expect(span.includes(file), isTrue);
    });

    test('the whole recitation holds every file of the quality', () {
      expect(target(const WholeRecitation()).files, hasLength(5));
    });

    test('the size of a target is the sum of its files', () {
      expect(target(const WholeRecitation()).bytes, 5 * 40);
    });
  });

  group('download', () {
    test('fetches the files and names each by its hash', () async {
      final result = await repository.download(
        target(const RecitationSurah(1)),
        wifiOnly: true,
      );

      expect(result, isA<Ok<void>>());
      for (final ayah in [1, 2, 3]) {
        final file = fileOf(64, 1, ayah);
        expect(await File(finalPath(file)).length(), file.bytes);
      }
      expect(await Directory('$audio/$_pack/staging').list().toList(), isEmpty);
      expect(downloads.orders.every((o) => o.wifiOnly), isTrue);
    });

    test('reports progress over the bytes still to fetch', () async {
      final seen = <int>[];
      repository.addListener(() {
        for (final job in repository.jobs) {
          if (job.state case RecitationDownloading(:final progress)) {
            seen.add(progress.receivedBytes);
          }
        }
      });
      await repository.download(
        target(const RecitationSurah(1)),
        wifiOnly: false,
      );

      expect(seen, containsAllInOrder([0, 40, 80, 120]));
      expect(repository.jobs, isEmpty);
    });

    test('does not fetch what is on the device again', () async {
      await repository.download(
        target(const RecitationSurah(1)),
        wifiOnly: false,
      );
      downloads.orders.clear();

      await repository.download(
        target(const WholeRecitation()),
        wifiOnly: false,
      );

      expect(downloads.orders.map((o) => o.url.path), [
        '/synthetic/q64/2_1.mp3',
        '/synthetic/q64/2_2.mp3',
      ]);
    });

    test(
      'keeps the files that arrived when the network fails midway',
      () async {
        downloads.bodies.remove('/synthetic/q64/1_3.mp3');
        final failed = await repository.download(
          target(const RecitationSurah(1)),
          wifiOnly: false,
        );

        expect(
          failed,
          isA<Failure<void>>().having(
            (f) => f.error,
            'error',
            isA<RecitationFileNotFetched>().having(
              (e) => e.statusCode,
              'status',
              404,
            ),
          ),
        );
        expect(repository.jobs.single.state, isA<RecitationDownloadFailed>());
        expect(await File(finalPath(fileOf(64, 1, 2))).exists(), isTrue);
      },
    );

    test(
      'resumes after an interruption without fetching what is whole',
      () async {
        final (_, body) = _file(64, 1, 1);
        final first = fileOf(64, 1, 1);
        // A file the downloader finished before the app was closed, still in
        // staging.
        final staged = File('$audio/$_pack/staging/${first.sha256}.mp3');
        await staged.parent.create(recursive: true);
        await staged.writeAsBytes(body);
        // A second one already activated.
        final done = fileOf(64, 1, 2);
        final activated = File(finalPath(done));
        await activated.parent.create(recursive: true);
        await activated.writeAsBytes(
          downloads.bodies['/synthetic/${done.path}']!,
        );

        await repository.download(
          target(const RecitationSurah(1)),
          wifiOnly: false,
        );

        expect(downloads.orders.map((o) => o.url.path), [
          '/synthetic/q64/1_3.mp3',
        ]);
        expect(await File(finalPath(first)).exists(), isTrue);
      },
    );

    test(
      'refuses a staged file whose hash differs and fetches it again',
      () async {
        final first = fileOf(64, 1, 1);
        final staged = File('$audio/$_pack/staging/${first.sha256}.mp3');
        await staged.parent.create(recursive: true);
        await staged.writeAsBytes(Uint8List(first.bytes));

        await repository.download(
          target(const RecitationSurah(1)),
          wifiOnly: false,
        );

        expect(
          downloads.orders.map((o) => o.url.path),
          contains('/synthetic/q64/1_1.mp3'),
        );
        expect(
          await File(finalPath(first)).readAsBytes(),
          downloads.bodies['/synthetic/${first.path}'],
        );
      },
    );

    test('fetches a file again once when its hash differs', () async {
      downloads.corrupt['/synthetic/q64/1_1.mp3'] = 1;

      final result = await repository.download(
        target(const RecitationSurah(1)),
        wifiOnly: false,
      );

      expect(result, isA<Ok<void>>());
      expect(
        downloads.orders.where((o) => o.url.path.endsWith('1_1.mp3')),
        hasLength(2),
      );
    });

    test('rejects a file that differs twice and keeps nothing of it', () async {
      downloads.corrupt['/synthetic/q64/1_1.mp3'] = 2;
      final first = fileOf(64, 1, 1);

      final result = await repository.download(
        target(const RecitationSurah(1)),
        wifiOnly: false,
      );

      expect(
        result,
        isA<Failure<void>>().having(
          (f) => f.error,
          'error',
          isA<RecitationFileRejected>(),
        ),
      );
      expect(await File(finalPath(first)).exists(), isFalse);
      expect(
        await File('$audio/$_pack/staging/${first.sha256}.mp3').exists(),
        isFalse,
      );
    });

    test('waits for Wi-Fi when only Wi-Fi is allowed', () async {
      network.kind = NetworkKind.other;
      final done = repository.download(
        target(const RecitationSurah(2)),
        wifiOnly: true,
      );
      await pumpEventQueue();

      expect(
        repository.jobs.single.state,
        isA<RecitationWaitingForNetwork>().having(
          (s) => s.wifiOnly,
          'wifiOnly',
          isTrue,
        ),
      );
      expect(downloads.orders, isEmpty);

      network.set(NetworkKind.unmetered);

      expect(await done, isA<Ok<void>>());
      expect(downloads.orders, hasLength(2));
    });

    test('goes on a mobile network when Wi-Fi only is off', () async {
      network.kind = NetworkKind.other;

      final result = await repository.download(
        target(const RecitationSurah(2)),
        wifiOnly: false,
      );

      expect(result, isA<Ok<void>>());
    });

    test('fails before fetching when the device lacks the space', () async {
      space.free = 10;

      final result = await repository.download(
        target(const RecitationSurah(2)),
        wifiOnly: false,
      );

      expect(
        result,
        isA<Failure<void>>().having(
          (f) => f.error,
          'error',
          isA<RecitationNoSpace>(),
        ),
      );
      expect(downloads.orders, isEmpty);
    });

    test('stops on cancel and keeps what arrived whole', () async {
      downloads.gates['/synthetic/q64/1_2.mp3'] = Completer();
      final done = repository.download(
        target(const RecitationSurah(1)),
        wifiOnly: false,
      );
      await downloads.reached.stream.first;

      await repository.cancel(target(const RecitationSurah(1)).key);

      expect(
        await done,
        isA<Failure<void>>().having(
          (f) => f.error,
          'error',
          isA<RecitationDownloadCancelled>(),
        ),
      );
      expect(repository.jobs, isEmpty);
      expect(await File(finalPath(fileOf(64, 1, 1))).exists(), isTrue);
      expect(await File(finalPath(fileOf(64, 1, 2))).exists(), isFalse);
    });

    test('runs one job after another', () async {
      final first = repository.download(
        target(const RecitationSurah(1)),
        wifiOnly: false,
      );
      final second = repository.download(
        target(const RecitationSurah(2)),
        wifiOnly: false,
      );

      expect(repository.jobs, hasLength(2));
      await Future.wait([first, second]);

      expect(downloads.orders.map((o) => o.url.path), [
        '/synthetic/q64/1_1.mp3',
        '/synthetic/q64/1_2.mp3',
        '/synthetic/q64/1_3.mp3',
        '/synthetic/q64/2_1.mp3',
        '/synthetic/q64/2_2.mp3',
      ]);
    });

    test('refuses a download already queued', () async {
      downloads.gates['/synthetic/q64/1_1.mp3'] = Completer();
      unawaited(
        repository.download(target(const RecitationSurah(1)), wifiOnly: false),
      );

      final again = await repository.download(
        target(const RecitationSurah(1)),
        wifiOnly: false,
      );

      expect(
        again,
        isA<Failure<void>>().having(
          (f) => f.error,
          'error',
          isA<RecitationAlreadyQueued>(),
        ),
      );
      downloads.gates['/synthetic/q64/1_1.mp3']!.complete();
    });

    test('refuses a URL the policy does not allow', () async {
      contents = RecitationContents(
        recitationId: contents.recitationId,
        packId: _pack,
        baseUrl: Uri.parse('http://example.invalid/synthetic/'),
        unit: contents.unit,
        files: contents.files,
      );

      final result = await repository.download(
        target(const RecitationSurah(1)),
        wifiOnly: false,
      );

      expect(
        result,
        isA<Failure<void>>().having(
          (f) => f.error,
          'error',
          isA<RecitationUrlRefused>(),
        ),
      );
      expect(downloads.orders, isEmpty);
    });
  });

  group('on the device', () {
    test('present lists the files of the quality that are whole', () async {
      await repository.download(
        target(const RecitationSurah(1)),
        wifiOnly: false,
      );
      // A file cut short does not count.
      await File(finalPath(fileOf(64, 1, 3))).writeAsBytes([1, 2, 3]);

      final present = await repository.present(contents, 64);

      expect(present, {fileOf(64, 1, 1).path, fileOf(64, 1, 2).path});
      expect(await repository.present(contents, 128), isEmpty);
    });

    test(
      'delete removes the files of a selection and tells the readers',
      () async {
        await repository.download(
          target(const WholeRecitation()),
          wifiOnly: false,
        );
        final before = repository.revision;

        final result = await repository.delete(
          target(const RecitationSurah(2)),
        );

        expect(result, isA<Ok<void>>());
        expect(repository.revision, greaterThan(before));
        expect(await repository.present(contents, 64), {
          for (final ayah in [1, 2, 3]) fileOf(64, 1, ayah).path,
        });
      },
    );

    test('delete leaves the other quality alone', () async {
      await repository.download(
        target(const RecitationSurah(1)),
        wifiOnly: false,
      );
      await repository.download(
        target(const RecitationSurah(1), quality: 128),
        wifiOnly: false,
      );

      await repository.delete(target(const RecitationSurah(1)));

      expect(await repository.present(contents, 64), isEmpty);
      expect(await repository.present(contents, 128), hasLength(3));
    });
  });
}
