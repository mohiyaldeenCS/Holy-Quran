import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/address_providers.dart';
import 'package:holyquran/config/providers/audio_providers.dart';
import 'package:holyquran/config/providers/catalogue_providers.dart';
import 'package:holyquran/config/providers/links_providers.dart';
import 'package:holyquran/config/providers/pack_install_providers.dart';
import 'package:holyquran/config/providers/quran_providers.dart';
import 'package:holyquran/config/providers/reading_providers.dart';
import 'package:holyquran/config/providers/search_providers.dart';
import 'package:holyquran/config/providers/settings_providers.dart';
import 'package:holyquran/config/providers/share_providers.dart';
import 'package:holyquran/config/providers/tafsir_providers.dart';
import 'package:holyquran/config/providers/user_data_providers.dart';
import 'package:holyquran/config/providers/user_database_providers.dart';
import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/bookmark_repository.dart';
import 'package:holyquran/data/repositories/category_repository.dart';
import 'package:holyquran/data/repositories/integrity_log_repository.dart';
import 'package:holyquran/data/repositories/keep_awake_repository.dart';
import 'package:holyquran/data/repositories/listening_position_repository.dart';
import 'package:holyquran/data/repositories/note_repository.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/data/repositories/search_history_repository.dart';
import 'package:holyquran/data/repositories/tag_repository.dart';
import 'package:holyquran/data/services/clipboard_service.dart';
import 'package:holyquran/data/services/free_space_service.dart';
import 'package:holyquran/data/services/link_service.dart';
import 'package:holyquran/data/services/share_service.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:provider/provider.dart';

import '../../testing/application_support.dart';
import '../../testing/fakes/memory_task_storage.dart';

final class _Database {
  const _Database(this.name);

  final String name;
}

final class _Settings extends ChangeNotifier {
  _Settings(this.database);

  final _Database database;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The areas start the pack installer, which creates the downloader plugin;
  // its own storage runs an isolate that outlives the test.
  setUpAll(() => FileDownloader(persistentStorage: MemoryTaskStorage()));

  test('the areas are set up in the order of D-103', () {
    expect(appAreas, [
      userDatabaseProviders,
      settingsProviders,
      readingProviders,
      quranProviders,
      packInstallProviders,
      catalogueProviders,
      userDataProviders,
      audioProviders,
      tafsirProviders,
      searchProviders,
      shareProviders,
      addressProviders,
      linksProviders,
    ]);
  });

  test('builds without a base pack or a catalogue, providing the user '
      'database, the settings, the user data and the services that need '
      'none of them', () async {
    final support = useTemporaryApplicationSupport();
    late Dependencies provided;
    final providers = await buildDependencies(
      areas: [...appAreas, (dependencies) async => provided = dependencies],
    );
    final installs = provided.read<PackInstallRepository>();
    // The start runs on the support folder, which the test deletes.
    await installs.started;
    addTearDown(provided.read<UserDatabase>().close);
    addTearDown(provided.read<IntegrityLogRepository>().dispose);
    addTearDown((installs as LocalPackInstallRepository).dispose);

    expect(providers.map((provider) => provider.runtimeType), [
      Provider<UserDatabase>,
      ListenableProvider<AppSettingsRepository>,
      ListenableProvider<ReadingPositionRepository>,
      Provider<FreeSpaceService>,
      ListenableProvider<PackInstallRepository>,
      ListenableProvider<BookmarkRepository>,
      ListenableProvider<NoteRepository>,
      ListenableProvider<TagRepository>,
      Provider<CategoryRepository>,
      ListenableProvider<ListeningPositionRepository>,
      ListenableProvider<SearchHistoryRepository>,
      ListenableProvider<IntegrityLogRepository>,
      ListenableProvider<KeepAwakeRepository>,
      Provider<ClipboardService>,
      Provider<ShareService>,
      Provider<LinkService>,
    ]);
    expect(
      provided.read<AppSettingsRepository>(),
      isA<LocalAppSettingsRepository>(),
    );
    expect(
      File('${support.path}/${UserDatabase.fileName}').existsSync(),
      isTrue,
    );
  });

  test(
    'sets up one area after another, each after the last finished',
    () async {
      final log = <String>[];
      Future<void> slow(Dependencies dependencies) async {
        log.add('slow starts');
        await Future<void>.delayed(const Duration(milliseconds: 1));
        log.add('slow ends');
      }

      Future<void> quick(Dependencies dependencies) async => log.add('quick');

      await buildDependencies(areas: [slow, quick]);

      expect(log, ['slow starts', 'slow ends', 'quick']);
    },
  );

  test('a later area reads what an earlier one provided', () async {
    late _Settings settings;
    await buildDependencies(
      areas: [
        (dependencies) async =>
            dependencies.provide(const _Database('synthetic')),
        (dependencies) async => dependencies.provideListenable(
          settings = _Settings(dependencies.read<_Database>()),
        ),
      ],
    );

    expect(settings.database.name, 'synthetic');
  });

  test('reading what no earlier area provided throws', () async {
    await expectLater(
      buildDependencies(
        areas: [(dependencies) async => dependencies.read<_Database>()],
      ),
      throwsStateError,
    );
  });

  test('tryRead gives what an earlier area provided and null for the '
      'rest', () async {
    final found = <Object?>[];
    await buildDependencies(
      areas: [
        (dependencies) async =>
            dependencies.provide(const _Database('synthetic')),
        (dependencies) async => found
          ..add(dependencies.tryRead<_Database>())
          ..add(dependencies.tryRead<_Settings>()),
      ],
    );

    expect(found, [isA<_Database>(), isNull]);
  });

  testWidgets('replace gives later areas and the tree the new value, in '
      'the same place', (tester) async {
    final seen = <String>[];
    final settings = _Settings(const _Database('settings'));
    addTearDown(settings.dispose);
    final providers = await tester.runAsync(
      () => buildDependencies(
        areas: [
          (dependencies) async =>
              dependencies.provide(const _Database('suspect')),
          (dependencies) async => dependencies.provideListenable(settings),
          (dependencies) async =>
              dependencies.replace(const _Database('replacement')),
          (dependencies) async => seen.add(dependencies.read<_Database>().name),
        ],
      ),
    );
    late String inTree;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers!,
        child: Builder(
          builder: (context) {
            inTree = context.read<_Database>().name;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(seen, ['replacement']);
    expect(inTree, 'replacement');
    expect(providers.map((provider) => provider.runtimeType), [
      Provider<_Database>,
      ListenableProvider<_Settings>,
    ]);
  });

  test('replace needs a value an earlier area provided', () async {
    await expectLater(
      buildDependencies(
        areas: [
          (dependencies) async =>
              dependencies.replace(const _Database('replacement')),
        ],
      ),
      throwsStateError,
    );
  });

  test('providing a type twice throws', () async {
    await expectLater(
      buildDependencies(
        areas: [
          (dependencies) async => dependencies.provide(const _Database('a')),
          (dependencies) async => dependencies.provide(const _Database('b')),
        ],
      ),
      throwsStateError,
    );
  });

  testWidgets('the providers keep the area order and reach the tree', (
    tester,
  ) async {
    final settings = _Settings(const _Database('synthetic'));
    addTearDown(settings.dispose);
    final providers = await tester.runAsync(
      () => buildDependencies(
        areas: [
          (dependencies) async =>
              dependencies.provide(const _Database('synthetic')),
          (dependencies) async => dependencies.provideListenable(settings),
        ],
      ),
    );

    expect(providers!.map((provider) => provider.runtimeType), [
      Provider<_Database>,
      ListenableProvider<_Settings>,
    ]);

    var builds = 0;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (context) {
            builds++;
            context.watch<_Settings>();
            expect(context.read<_Database>().name, 'synthetic');
            return const SizedBox();
          },
        ),
      ),
    );
    settings.notifyListeners();
    await tester.pump();

    expect(builds, 2);
  });
}
