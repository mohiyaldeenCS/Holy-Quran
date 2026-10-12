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
import 'package:provider/provider.dart';

final class _Database {
  const _Database(this.name);

  final String name;
}

final class _Settings extends ChangeNotifier {
  _Settings(this.database);

  final _Database database;
}

void main() {
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

  test('builds with every area empty', () async {
    expect(await buildDependencies(), isEmpty);
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
