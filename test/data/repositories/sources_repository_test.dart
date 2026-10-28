import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/sources_repository.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_link_service.dart';
import '../../../testing/fakes/fake_pack_install_repository.dart';
import '../../ui/features/sources/sources_fixtures.dart';

void main() {
  late Directory root;
  late FakePackInstallRepository installs;
  late FakeLinkService links;
  late PackSourcesRepository repository;

  setUp(() {
    root = Directory.systemTemp.createTempSync('sources_repository');
    installs = FakePackInstallRepository();
    links = FakeLinkService();
    repository = PackSourcesRepository(installs: installs, links: links);
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

  test('opens the address of a source through the link service', () async {
    installs.installed = [await installedWithSource(root)];

    final result = await repository.openLink(repository.sources.first);

    expect(result, isA<Ok<void>>());
    expect(links.opened, [
      Uri.parse('https://example.invalid/synthetic/source'),
    ]);
  });

  test('fails for an address that is not a URI, opening nothing', () async {
    installs.installed = [
      await installedWithSource(root, url: 'https://exa mple:bad'),
    ];

    final result = await repository.openLink(repository.sources.first);

    expect(result, isA<Failure<void>>());
    expect(links.opened, isEmpty);
  });
}
