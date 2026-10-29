import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/sources_repository.dart';
import 'package:holyquran/data/services/link_service.dart';
import 'package:holyquran/domain/models/source_credit.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_licence_text_service.dart';
import '../../../testing/fakes/fake_link_service.dart';
import '../../../testing/fakes/fake_pack_install_repository.dart';
import '../../ui/features/sources/sources_fixtures.dart';

void main() {
  late Directory root;
  late FakePackInstallRepository installs;
  late FakeLinkService links;
  late FakeLicenceTextService licences;
  late PackSourcesRepository repository;

  setUp(() {
    root = Directory.systemTemp.createTempSync('sources_repository');
    installs = FakePackInstallRepository();
    links = FakeLinkService();
    licences = FakeLicenceTextService(['Synthetic OFL text']);
    repository = PackSourcesRepository(
      links: links,
      licences: licences,
      installs: installs,
    );
  });
  tearDown(() {
    repository.dispose();
    root.deleteSync(recursive: true);
  });

  test(
    'serves the sources of the installed packs and tells of changes',
    () async {
      var heard = 0;
      repository.addListener(() => heard++);
      expect(repository.sources, isEmpty);

      installs.installed = [await installedWithSource(root)];

      expect(heard, 1);
      expect(repository.sources.first.name, 'Synthetic source name');
    },
  );

  test('lists the base pack first, and works without an installer', () async {
    final base = await installedWithSource(
      root,
      id: 'synthetic-base',
      name: 'Synthetic base source',
    );
    installs.installed = [
      await installedWithSource(root, id: 'synthetic-other'),
    ];
    final both = PackSourcesRepository(
      links: links,
      licences: licences,
      basePack: base.manifest,
      installs: installs,
    );
    final baseOnly = PackSourcesRepository(
      links: links,
      licences: licences,
      basePack: base.manifest,
    );
    addTearDown(both.dispose);
    addTearDown(baseOnly.dispose);

    expect(both.sources.first.name, 'Synthetic base source');
    expect(both.sources.map((s) => s.name), contains('Synthetic source name'));
    expect(baseOnly.sources, sourcesOf([base.manifest]));
  });

  test('stops listening to the installer once disposed', () {
    final counting = FakePackInstallRepository();
    PackSourcesRepository(
      links: links,
      licences: licences,
      installs: counting,
    ).dispose();

    expect(counting.listenerCount, 0);
  });

  test('serves the font licence texts', () async {
    expect((await repository.fontLicences() as Ok<List<String>>).value, [
      'Synthetic OFL text',
    ]);
  });

  test('opens the address of a source through the link service', () async {
    installs.installed = [await installedWithSource(root)];

    final result = await repository.openLink(repository.sources.first);

    expect(result, isA<Ok<void>>());
    expect(links.opened, [
      Uri.parse('https://example.invalid/synthetic/source'),
    ]);
  });

  test('fails for an address that is not a URI, keeping it', () async {
    const address = 'https://exa mple:bad';
    installs.installed = [await installedWithSource(root, url: address)];

    final result = await repository.openLink(repository.sources.first);

    expect(
      result,
      isA<Failure<void>>().having(
        (failure) => (failure.error as LinkNotOpened).address,
        'address',
        address,
      ),
    );
    expect(links.opened, isEmpty);
  });
}
