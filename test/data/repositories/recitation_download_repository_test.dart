import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/config/providers/recitation_download_providers.dart';
import 'package:holyquran/data/repositories/download_settings_repository.dart';
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

/// Time a job that is not held needs to count what is on the device.
const _longEnoughToRun = Duration(milliseconds: 200);

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
  _Downloads(this.root, this.bodies, this.network);

  final String root;
  final _Network network;

  /// What the server holds, by URL path.
  final Map<String, Uint8List> bodies;
  final List<FileOrder> orders = [];

  /// How many more downloads of a URL path arrive with one byte inverted.
  final Map<String, int> corrupt = {};

  /// A download of a URL path that waits for its gate.
  final Map<String, Completer<void>> gates = {};

  /// URL paths whose download finishes whole when it is told to stop, as one
  /// that was already done when the stop reached it.
  final Set<String> finishDespiteCancel = {};
  final StreamController<String> reached = StreamController.broadcast();

  /// A download of a URL path that waits for Wi-Fi, as an order that
  /// requires it does off Wi-Fi.
  final StreamController<String> pending = StreamController.broadcast();
  final Map<String, Completer<FileDownloadOutcome>> _ends = {};

  /// The next [start] throws this, once.
  Exception? startFails;

  /// The next [download] throws this, once.
  Error? downloadThrows;

  @override
  Future<void> start() async {
    if (startFails case final failure?) {
      startFails = null;
      throw failure;
    }
  }

  @override
  Future<FileDownloadOutcome> download(
    FileOrder order,
    void Function(FileTaskUpdate update) onUpdate,
  ) async {
    orders.add(order);
    if (downloadThrows case final error?) {
      downloadThrows = null;
      throw error;
    }
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
    while (order.wifiOnly && network.kind != NetworkKind.unmetered) {
      pending.add(path);
      final outcome = await Future.any([
        network.changes.first.then((_) => null),
        ended.future,
      ]);
      if (outcome != null) return outcome;
    }
    final body = bodies[path];
    if (body == null) return const FileDownloadFailed('gone', statusCode: 404);
    onUpdate((status: FileTaskStatus.running, progress: null));
    await _write(order);
    return const FileDownloaded();
  }

  Future<void> _write(FileOrder order) async {
    final path = order.url.path;
    final bytes = Uint8List.fromList(bodies[path]!);
    if ((corrupt[path] ?? 0) > 0) {
      corrupt[path] = corrupt[path]! - 1;
      bytes[bytes.length ~/ 2] ^= 0xFF;
    }
    final target = File('$root/${order.path}');
    await target.parent.create(recursive: true);
    await target.writeAsBytes(bytes);
  }

  @override
  Future<bool> pause(FileOrder order) async => false;

  @override
  Future<void> resume(FileOrder order) async {}

  @override
  Future<void> cancel(FileOrder order) async {
    final ended = _ends[order.url.path];
    if (ended == null || ended.isCompleted) return;
    if (finishDespiteCancel.contains(order.url.path)) {
      await _write(order);
      ended.complete(const FileDownloaded());
    } else {
      ended.complete(const FileDownloadCanceled());
    }
  }
}

/// A store whose deletion of a file waits for [gate], so that a test can
/// act while files are being removed.
final class _SlowStore extends RecitationFileStore {
  _SlowStore({required super.audioDirectory});

  Completer<void>? gate;
  final StreamController<void> started = StreamController.broadcast();

  @override
  Future<void> delete(String packId, RecitationFile file) async {
    started.add(null);
    await gate?.future;
    return super.delete(packId, file);
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
  /// Holds every check until it completes.
  Completer<void>? gate;

  /// Answers a check in place of the default, which lets the URL through.
  Result<Uri> Function(Uri url)? answer;
  final List<Uri> checked = [];
  final StreamController<Uri> asked = StreamController.broadcast();

  @override
  Future<Result<Uri>> checkRedirects(Uri url, UrlPolicy policy) async {
    checked.add(url);
    asked.add(url);
    await gate?.future;
    return answer?.call(url) ?? Ok(url);
  }
}

void main() {
  late Directory temp;
  late String audio;
  late RecitationContents contents;
  late _Downloads downloads;
  late _Network network;
  late _Space space;
  late _Urls urls;
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

  LocalRecitationDownloadRepository newRepository(RecitationFileStore from) =>
      LocalRecitationDownloadRepository(
        contents: (id) async => Ok(contents),
        downloads: downloads,
        urlCheck: urls,
        connectivity: network,
        freeSpace: space,
        store: from,
        policy: _policy,
        wifiOnly: false,
      );

  /// Waits, without a fixed pause, until the repository's state satisfies
  /// [condition]; the jobs do real disk work first.
  Future<void> until(bool Function() condition) async {
    if (condition()) return;
    final reached = Completer<void>();
    void check() {
      if (condition() && !reached.isCompleted) reached.complete();
    }

    repository.addListener(check);
    try {
      await reached.future.timeout(const Duration(seconds: 10));
    } finally {
      repository.removeListener(check);
    }
  }

  bool waiting() =>
      repository.jobs.any((job) => job.state is RecitationWaitingForNetwork);

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
    network = _Network();
    downloads = _Downloads(temp.path, {
      for (final (file, bytes) in made) '/synthetic/${file.path}': bytes,
    }, network);
    space = _Space();
    urls = _Urls();
    store = RecitationFileStore(audioDirectory: () async => audio);
    repository = newRepository(store);
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
      repository.setWifiOnly(true);
      final result = await repository.download(
        target(const RecitationSurah(1)),
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
      await repository.download(target(const RecitationSurah(1)));

      expect(seen, containsAllInOrder([0, 40, 80, 120]));
      expect(repository.jobs, isEmpty);
    });

    test('does not fetch what is on the device again', () async {
      await repository.download(target(const RecitationSurah(1)));
      downloads.orders.clear();

      await repository.download(target(const WholeRecitation()));

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

        await repository.download(target(const RecitationSurah(1)));

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

        await repository.download(target(const RecitationSurah(1)));

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
      repository.setWifiOnly(true);
      final done = repository.download(target(const RecitationSurah(2)));
      await until(waiting);

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
      );

      expect(result, isA<Ok<void>>());
    });

    test('fails before fetching when the device lacks the space', () async {
      space.free = 10;

      final result = await repository.download(
        target(const RecitationSurah(2)),
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
      final done = repository.download(target(const RecitationSurah(1)));
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
      final first = repository.download(target(const RecitationSurah(1)));
      final second = repository.download(target(const RecitationSurah(2)));

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

    test('starts again after a stop at once, without being refused', () async {
      downloads.gates['/synthetic/q64/1_1.mp3'] = Completer();
      final first = repository.download(target(const RecitationSurah(1)));
      await downloads.reached.stream.first;
      final stopping = repository.cancel(target(const RecitationSurah(1)).key);
      downloads.gates.remove('/synthetic/q64/1_1.mp3');

      final again = repository.download(target(const RecitationSurah(1)));
      await stopping;

      expect(await first, isA<Failure<void>>());
      expect(await again, isA<Ok<void>>());
    });

    test('goes on with the next job after one threw', () async {
      downloads.downloadThrows = StateError('synthetic');
      final first = repository.download(target(const RecitationSurah(1)));
      final second = repository.download(target(const RecitationSurah(2)));

      expect(
        await first,
        isA<Failure<void>>().having(
          (f) => f.error,
          'error',
          isA<RecitationStoreFailed>(),
        ),
      );
      expect(await second, isA<Ok<void>>());
    });

    test('tries the downloader again after it failed to start', () async {
      downloads.startFails = Exception('synthetic');
      final first = await repository.download(target(const RecitationSurah(2)));
      final second = await repository.download(
        target(const RecitationSurah(2)),
      );

      expect(first, isA<Failure<void>>());
      expect(second, isA<Ok<void>>());
    });

    test(
      'starts a job waiting for Wi-Fi when Wi-Fi only is turned off',
      () async {
        network.kind = NetworkKind.other;
        repository.setWifiOnly(true);
        final done = repository.download(target(const RecitationSurah(2)));
        await until(waiting);
        expect(downloads.orders, isEmpty);

        repository.setWifiOnly(false);

        expect(await done, isA<Ok<void>>());
        expect(downloads.orders.every((o) => !o.wifiOnly), isTrue);
      },
    );

    test('a change in the download settings reaches a queued job', () async {
      final settings = InMemoryDownloadSettingsRepository();
      repository.setWifiOnly(settings.wifiOnly);
      followWifiOnly(repository, settings);
      network.kind = NetworkKind.other;
      final done = repository.download(target(const RecitationSurah(2)));
      await until(waiting);

      await settings.setWifiOnly(false);

      expect(await done, isA<Ok<void>>());
      expect(downloads.orders.every((o) => !o.wifiOnly), isTrue);
    });

    test(
      'stops a file fetching over mobile data when Wi-Fi only is turned on',
      () async {
        network.kind = NetworkKind.other;
        downloads.gates['/synthetic/q64/2_1.mp3'] = Completer();
        final done = repository.download(target(const RecitationSurah(2)));
        await downloads.reached.stream.first;

        repository.setWifiOnly(true);
        downloads.gates.remove('/synthetic/q64/2_1.mp3');
        await until(waiting);

        expect(
          repository.jobs.single.state,
          isA<RecitationWaitingForNetwork>(),
        );
        network.set(NetworkKind.unmetered);

        expect(await done, isA<Ok<void>>());
        expect(
          downloads.orders.where((o) => o.url.path.endsWith('2_1.mp3')),
          hasLength(2),
        );
        expect(downloads.orders.last.wifiOnly, isTrue);
      },
    );

    test(
      'frees an order held for Wi-Fi on mobile data when Wi-Fi only is off',
      () async {
        repository.setWifiOnly(true);
        downloads.gates['/synthetic/q64/2_1.mp3'] = Completer();
        final pending = downloads.pending.stream.first;
        repository.setWifiOnly(true);
        final done = repository.download(target(const RecitationSurah(2)));
        await downloads.reached.stream.first;
        network.set(NetworkKind.other);
        downloads.gates['/synthetic/q64/2_1.mp3']!.complete();
        await pending;

        repository.setWifiOnly(false);

        expect(
          await done.timeout(const Duration(seconds: 10)),
          isA<Ok<void>>(),
        );
        expect(downloads.orders.last.wifiOnly, isFalse);
      },
    );

    test('stops a file fetching over mobile data when the device leaves Wi-Fi '
        'after Wi-Fi only was turned on', () async {
      downloads.gates['/synthetic/q64/2_1.mp3'] = Completer();
      final done = repository.download(target(const RecitationSurah(2)));
      await downloads.reached.stream.first;
      repository.setWifiOnly(true);
      downloads.gates.remove('/synthetic/q64/2_1.mp3');

      network.set(NetworkKind.other);
      await until(waiting);

      expect(
        downloads.orders.where((o) => o.url.path.endsWith('2_1.mp3')),
        hasLength(1),
      );
      network.set(NetworkKind.unmetered);
      expect(await done, isA<Ok<void>>());
      expect(downloads.orders.last.wifiOnly, isTrue);
    });

    test(
      'frees an order held for Wi-Fi when Wi-Fi only was turned off on Wi-Fi '
      'and the device then leaves it',
      () async {
        repository.setWifiOnly(true);
        downloads.gates['/synthetic/q64/2_1.mp3'] = Completer();
        final done = repository.download(target(const RecitationSurah(2)));
        await downloads.reached.stream.first;
        repository.setWifiOnly(false);

        network.set(NetworkKind.other);
        downloads.gates['/synthetic/q64/2_1.mp3']!.complete();

        expect(
          await done.timeout(const Duration(seconds: 10)),
          isA<Ok<void>>(),
        );
        expect(downloads.orders.last.wifiOnly, isFalse);
      },
    );

    test('keeps a file that finished before it was stopped', () async {
      network.kind = NetworkKind.other;
      downloads.gates['/synthetic/q64/2_1.mp3'] = Completer();
      downloads.finishDespiteCancel.add('/synthetic/q64/2_1.mp3');
      final done = repository.download(target(const RecitationSurah(2)));
      await downloads.reached.stream.first;

      repository.setWifiOnly(true);
      await until(waiting);
      network.set(NetworkKind.unmetered);

      expect(await done, isA<Ok<void>>());
      expect(
        downloads.orders.where((o) => o.url.path.endsWith('2_1.mp3')),
        hasLength(1),
      );
      expect(await File(finalPath(fileOf(64, 2, 1))).exists(), isTrue);
    });

    test('does not fetch a finished file again when Wi-Fi only is toggled '
        'on mobile data', () async {
      network.kind = NetworkKind.other;
      downloads.gates['/synthetic/q64/2_1.mp3'] = Completer();
      downloads.finishDespiteCancel.add('/synthetic/q64/2_1.mp3');
      final done = repository.download(target(const RecitationSurah(2)));
      await downloads.reached.stream.first;

      repository
        ..setWifiOnly(true)
        ..setWifiOnly(false);

      expect(await done, isA<Ok<void>>());
      expect(
        downloads.orders.where((o) => o.url.path.endsWith('2_1.mp3')),
        hasLength(1),
      );
    });

    test(
      'leaves a file fetching over Wi-Fi alone when Wi-Fi only is turned on',
      () async {
        downloads.gates['/synthetic/q64/2_1.mp3'] = Completer();
        final done = repository.download(target(const RecitationSurah(2)));
        await downloads.reached.stream.first;

        repository.setWifiOnly(true);
        downloads.gates['/synthetic/q64/2_1.mp3']!.complete();

        expect(await done, isA<Ok<void>>());
        expect(
          downloads.orders.where((o) => o.url.path.endsWith('2_1.mp3')),
          hasLength(1),
        );
      },
    );

    test('stops the new job, not the one already stopped', () async {
      urls.gate = Completer();
      final asked = urls.asked.stream.first;
      final stopped = repository.download(target(const RecitationSurah(1)));
      await asked;
      await repository.cancel(target(const RecitationSurah(1)).key);

      final again = repository.download(target(const RecitationSurah(1)));
      await repository.cancel(target(const RecitationSurah(1)).key);

      expect(
        await again,
        isA<Failure<void>>().having(
          (f) => f.error,
          'error',
          isA<RecitationDownloadCancelled>(),
        ),
      );
      urls.gate!.complete();
      expect(await stopped, isA<Failure<void>>());
      expect(downloads.orders, isEmpty);
    });

    test('waits for the network when it goes while a URL is checked', () async {
      var dropped = false;
      urls.answer = (url) {
        if (!dropped) {
          dropped = true;
          network.kind = NetworkKind.none;
          return Failure(UrlUnreachable(url, 'synthetic'));
        }
        return Ok(url);
      };
      repository.setWifiOnly(true);
      final done = repository.download(target(const RecitationSurah(2)));
      await until(waiting);

      expect(repository.jobs.single.state, isA<RecitationWaitingForNetwork>());
      network.set(NetworkKind.unmetered);

      expect(await done, isA<Ok<void>>());
      expect(urls.checked, hasLength(2));
    });

    test(
      'sends no request on mobile data when only Wi-Fi is allowed',
      () async {
        network.kind = NetworkKind.other;
        repository.setWifiOnly(true);
        final done = repository.download(target(const RecitationSurah(2)));
        await until(waiting);

        expect(urls.checked, isEmpty);
        network.set(NetworkKind.unmetered);
        await done;
      },
    );

    test('asks where a host leads once for the job', () async {
      await repository.download(target(const WholeRecitation()));

      expect(urls.checked, hasLength(1));
      expect(downloads.orders, hasLength(5));
    });

    test('refuses a redirect the policy does not allow', () async {
      urls.answer = (url) =>
          Failure(UrlRefused(Uri.parse('http://example.invalid/'), from: url));

      final result = await repository.download(
        target(const RecitationSurah(2)),
      );

      expect(
        result,
        isA<Failure<void>>().having(
          (f) => f.error,
          'error',
          isA<RecitationUrlRefused>(),
        ),
      );
    });

    test('refuses a download already queued', () async {
      downloads.gates['/synthetic/q64/1_1.mp3'] = Completer();
      unawaited(repository.download(target(const RecitationSurah(1))));

      final again = await repository.download(target(const RecitationSurah(1)));

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
      await repository.download(target(const RecitationSurah(1)));
      // A file cut short does not count.
      await File(finalPath(fileOf(64, 1, 3))).writeAsBytes([1, 2, 3]);

      final present = await repository.present(contents, 64);

      expect(present, {fileOf(64, 1, 1).path, fileOf(64, 1, 2).path});
      expect(await repository.present(contents, 128), isEmpty);
    });

    test('hasAudio tells final files from staged ones', () async {
      expect(await repository.hasAudio(_pack), isFalse);
      final first = fileOf(64, 1, 1);
      final staged = File('$audio/$_pack/staging/${first.sha256}.mp3');
      await staged.parent.create(recursive: true);
      await staged.writeAsBytes([1]);
      expect(await repository.hasAudio(_pack), isFalse);

      await repository.download(target(const RecitationSurah(1)));

      expect(await repository.hasAudio(_pack), isTrue);
    });

    test(
      'delete removes the files of a selection and tells the readers',
      () async {
        await repository.download(target(const WholeRecitation()));
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

    test('stopping the queue completes what waits in it', () async {
      urls.gate = Completer();
      final asked = urls.asked.stream.first;
      final first = repository.download(target(const RecitationSurah(1)));
      final second = repository.download(target(const RecitationSurah(2)));
      await asked;

      repository.dispose();
      urls.gate!.complete();

      expect(await second, isA<Failure<void>>());
      expect(await first, isA<Failure<void>>());
      repository = newRepository(store);
    });

    test('the reciter\'s own files stay when a surah goes', () async {
      final basmala = RecitationFile(
        qualityKbps: 64,
        part: RecitationFilePart.basmala,
        surah: null,
        ayah: null,
        path: 'q64/basmala.mp3',
        bytes: 40,
        sha256: sha256.convert(List.filled(40, 7)).toString(),
        duration: null,
      );
      downloads.bodies['/synthetic/q64/basmala.mp3'] = Uint8List.fromList(
        List.filled(40, 7),
      );
      contents = RecitationContents(
        recitationId: contents.recitationId,
        packId: _pack,
        baseUrl: contents.baseUrl,
        unit: contents.unit,
        files: [...contents.files, basmala],
      );
      await repository.download(target(const WholeRecitation()));
      expect(await File(finalPath(basmala)).exists(), isTrue);

      await repository.delete(target(const RecitationSurah(1)));
      expect(await File(finalPath(basmala)).exists(), isTrue);
      expect(await File(finalPath(fileOf(64, 1, 1))).exists(), isFalse);
      expect(await File(finalPath(fileOf(64, 2, 1))).exists(), isTrue);

      await repository.delete(target(const WholeRecitation()));
      expect(await File(finalPath(basmala)).exists(), isFalse);
    });

    test('counts the audio at every quality and removes all of it', () async {
      await repository.download(target(const RecitationSurah(1)));
      await repository.download(target(const RecitationSurah(2), quality: 128));
      final staged = File('$audio/$_pack/staging/leftover.mp3');
      await staged.parent.create(recursive: true);
      await staged.writeAsBytes([1, 2, 3]);

      expect(await repository.audioBytes(_pack), 5 * 40);

      expect(await repository.deleteAudio(_pack), isA<Ok<void>>());

      expect(await repository.audioBytes(_pack), 0);
      expect(await Directory('$audio/$_pack').exists(), isFalse);
    });

    test('will not remove the audio of a pack with a job', () async {
      urls.gate = Completer();
      final asked = urls.asked.stream.first;
      final running = repository.download(target(const RecitationSurah(1)));
      await asked;

      expect(await repository.deleteAudio(_pack), isA<Failure<void>>());
      expect(
        await repository.delete(target(const RecitationSurah(2))),
        isA<Failure<void>>(),
      );
      urls.gate!.complete();
      await running;
    });

    test('a job queued while files are removed counts them after', () async {
      final slow = _SlowStore(audioDirectory: () async => audio);
      await repository.download(target(const RecitationSurah(1)));
      repository.dispose();
      repository = newRepository(slow);
      slow.gate = Completer();
      final started = slow.started.stream.first;
      final deleting = repository.delete(target(const RecitationSurah(1)));
      await started;
      downloads.orders.clear();

      final again = repository.download(target(const RecitationSurah(1)));
      await Future.any([again, Future<void>.delayed(_longEnoughToRun)]);
      expect(repository.jobs, hasLength(1));
      slow.gate!.complete();

      expect(await deleting, isA<Ok<void>>());
      expect(await again, isA<Ok<void>>());
      expect(await repository.present(contents, 64), hasLength(3));
      expect(downloads.orders, hasLength(3));
    });

    test('delete leaves the other quality alone', () async {
      await repository.download(target(const RecitationSurah(1)));
      await repository.download(target(const RecitationSurah(1), quality: 128));

      await repository.delete(target(const RecitationSurah(1)));

      expect(await repository.present(contents, 64), isEmpty);
      expect(await repository.present(contents, 128), hasLength(3));
    });
  });
}
