import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/pack_install_providers.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/services/connectivity_service.dart';
import 'package:holyquran/data/services/download_service.dart';
import 'package:holyquran/data/services/free_space_service.dart';
import 'package:holyquran/data/services/installed_packs_store.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';
import 'package:holyquran/domain/models/install_job.dart';
import 'package:holyquran/utils/result.dart';

final class _Downloads implements DownloadService {
  int starts = 0;

  @override
  Future<void> start() async => starts++;

  @override
  Future<FileDownloadOutcome> download(
    FileOrder order,
    void Function(FileTaskUpdate update) onUpdate,
  ) => throw UnimplementedError();

  @override
  Future<bool> pause(FileOrder order) async => false;

  @override
  Future<void> resume(FileOrder order) async {}

  @override
  Future<void> cancel(FileOrder order) async {}
}

final class _Network implements ConnectivityService {
  @override
  Future<NetworkKind> current() async => NetworkKind.unmetered;

  @override
  Stream<NetworkKind> get changes => const Stream.empty();
}

final class _Space implements FreeSpaceService {
  @override
  Future<int?> freeBytesAt(String directory) async => null;
}

void main() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final messages = <String>[];

  setUp(() {
    messages.clear();
    messenger.allMessagesHandler = (channel, handler, message) {
      messages.add(channel);
      return null;
    };
  });

  tearDown(() => messenger.allMessagesHandler = null);

  test('the area provides the installer and starts it', () async {
    late Dependencies provided;
    await buildDependencies(
      areas: [
        packInstallProviders,
        (dependencies) async => provided = dependencies,
      ],
    );
    final installs = provided.read<PackInstallRepository>();
    addTearDown((installs as LocalPackInstallRepository).dispose);

    expect(await installs.started, isA<Failure<void>>());
    expect(messages, contains('plugins.flutter.io/path_provider'));
  });

  group('provideInstaller', () {
    late Directory support;
    late _Downloads downloads;

    setUp(() {
      support = Directory.systemTemp.createTempSync('install_providers');
      downloads = _Downloads();
    });
    tearDown(() => support.deleteSync(recursive: true));

    LocalPackInstallRepository installer() => LocalPackInstallRepository(
      openStore: () async => InstalledPacksStore(support),
      downloads: downloads,
      urlCheck: const HttpUrlCheck(),
      connectivity: _Network(),
      freeSpace: _Space(),
      files: const PackFileService(),
      verifier: const LocalPackRepository(
        files: PackFileService(),
        signatures: SignatureNotConfigured(),
      ),
      policy: UrlPolicy.httpsOnly,
      acceptUnchecked: true,
    );

    test(
      'provides the installer as the type the screens read, started',
      () async {
        late Dependencies provided;
        final repository = installer();
        addTearDown(repository.dispose);
        await buildDependencies(
          areas: [
            (dependencies) async => provideInstaller(dependencies, repository),
            (dependencies) async => provided = dependencies,
          ],
        );

        final installs = provided.read<PackInstallRepository>();

        expect(installs, same(repository));
        expect(await installs.started, isA<Ok<void>>());
        expect(downloads.starts, 1);
        expect(installs.installed, isEmpty);
        expect(installs.jobs, isEmpty);
      },
    );
  });

  test('the installer builds without touching a plugin', () async {
    final repository = packInstallRepository();
    addTearDown(repository.dispose);
    await pumpEventQueue();
    expect(messages, isEmpty);
    expect(repository.installed, isEmpty);
    expect(repository.jobs, isEmpty);
  });

  test('the installer accepts https URLs only', () async {
    final repository = packInstallRepository();
    addTearDown(repository.dispose);
    final url = Uri.parse('http://example.invalid/synthetic/manifest.json');
    final result = await repository.install(
      InstallRequest(
        packId: 'synthetic-text',
        version: 1,
        manifest: RemoteFile(url: url, sha256: '0' * 64, bytes: 1),
        signature: null,
        files: const {},
        wifiOnly: true,
      ),
    );
    expect(
      result,
      isA<Failure<Object>>().having(
        (f) => f.error,
        'error',
        isA<UrlNotAllowed>().having((e) => e.url, 'url', url),
      ),
    );
    expect(messages, isEmpty);
  });
}
