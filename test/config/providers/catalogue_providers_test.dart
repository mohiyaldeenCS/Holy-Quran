import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/config/catalogue_config.dart';
import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/catalogue_providers.dart';
import 'package:holyquran/data/repositories/catalogue_repository.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/recitation_repository.dart';
import 'package:holyquran/domain/models/catalogue.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_catalogue_repository.dart';
import '../../../testing/fakes/fake_pack_install_repository.dart';
import '../../../testing/fakes/fake_pack_integrity_repository.dart';

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

  test('the area provides the catalogue only once it is configured', () async {
    final providers = await buildDependencies(areas: [catalogueProviders]);
    expect(providers, catalogueUrl == null ? isEmpty : hasLength(1));
  });

  test('the catalogue builds without touching a plugin', () async {
    final repository = catalogueRepository(
      Uri.parse('https://example.invalid/catalogue.json'),
    );
    addTearDown(repository.dispose);
    await pumpEventQueue();
    expect(messages, isEmpty);
    expect(repository.catalogue, isNull);
  });

  test('the catalogue is fetched over https only', () async {
    final repository = catalogueRepository(
      Uri.parse('http://example.invalid/catalogue.json'),
    );
    addTearDown(repository.dispose);
    expect(
      await repository.refresh(),
      isA<Failure<Catalogue>>().having(
        (f) => f.error,
        'error',
        isA<CatalogueRejected>(),
      ),
    );
  });

  test('the recitations follow the catalogue and the installer', () async {
    final catalogue = FakeCatalogueRepository(syntheticCatalogue());
    final installs = FakePackInstallRepository();
    final integrity = FakePackIntegrityRepository();
    addTearDown(catalogue.dispose);
    addTearDown(installs.dispose);
    addTearDown(integrity.dispose);
    final recitations = recitationRepository(
      catalogue: catalogue,
      installs: installs,
      integrity: integrity,
    );
    var notified = 0;
    recitations.addListener(() => notified++);
    expect(
      [for (final r in recitations.recitations) r.id],
      ['synthetic-listed'],
    );

    installs.installed = [];
    catalogue.catalogue = null;
    expect(notified, 2);
    expect(recitations.recitations, isEmpty);
    await pumpEventQueue();
    expect(messages, isEmpty);
  });

  group('provideRecitations', () {
    Future<Dependencies> over({
      bool catalogue = true,
      bool installs = true,
      bool integrity = true,
    }) async {
      late Dependencies provided;
      await buildDependencies(
        areas: [
          (dependencies) async {
            if (catalogue) {
              final fake = FakeCatalogueRepository(syntheticCatalogue());
              addTearDown(fake.dispose);
              dependencies.provideListenable<CatalogueRepository>(fake);
            }
            if (installs) {
              final fake = FakePackInstallRepository();
              addTearDown(fake.dispose);
              dependencies.provideListenable<PackInstallRepository>(fake);
            }
            if (integrity) {
              final fake = FakePackIntegrityRepository();
              addTearDown(fake.dispose);
              dependencies.provideListenable<PackIntegrityRepository>(fake);
            }
          },
          (dependencies) async => provideRecitations(dependencies),
          (dependencies) async => provided = dependencies,
        ],
      );
      return provided;
    }

    test('provides the recitations the catalogue lists', () async {
      final recitations = (await over()).read<RecitationRepository>();

      expect(
        [for (final r in recitations.recitations) r.id],
        ['synthetic-listed'],
      );
      expect(messages, isEmpty);
    });

    test(
      'provides nothing while the catalogue or the integrity is missing',
      () async {
        for (final dependencies in [
          await over(catalogue: false),
          await over(integrity: false),
        ]) {
          expect(dependencies.tryRead<RecitationRepository>(), isNull);
        }
      },
    );

    test('fails the start when the installer is missing', () async {
      await expectLater(over(installs: false), throwsStateError);
    });
  });
}
