import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/sources_repository.dart';
import 'package:holyquran/ui/features/sources/view_models/sources_view_model.dart';

import '../../../../../testing/fakes/fake_link_service.dart';
import '../../../../../testing/fakes/fake_pack_install_repository.dart';
import '../sources_fixtures.dart';

void main() {
  late Directory root;
  late FakePackInstallRepository installs;
  late FakeLinkService links;
  late SourcesViewModel viewModel;

  setUp(() {
    root = Directory.systemTemp.createTempSync('sources_view_model');
    installs = FakePackInstallRepository();
    links = FakeLinkService();
    viewModel = SourcesViewModel(
      repository: PackSourcesRepository(installs: installs, links: links),
    );
  });
  tearDown(() {
    viewModel.dispose();
    root.deleteSync(recursive: true);
  });

  test('has no sources while no pack is installed', () {
    expect(viewModel.sources, isEmpty);
  });

  test(
    'lists the sources of the installed packs and follows changes',
    () async {
      var heard = 0;
      viewModel.addListener(() => heard++);

      installs.installed = [await installedWithSource(root)];

      expect(heard, 1);
      expect(viewModel.sources.first.name, 'Synthetic source name');
    },
  );

  test('opens a source link through the link service', () async {
    installs.installed = [await installedWithSource(root)];

    await viewModel.open(viewModel.sources.first);

    expect(links.opened, [
      Uri.parse('https://example.invalid/synthetic/source'),
    ]);
    expect(viewModel.linkFailed, isFalse);
  });

  test('reports a link that could not be opened, then clears it', () async {
    installs.installed = [await installedWithSource(root)];
    links.fails = true;
    await viewModel.open(viewModel.sources.first);
    expect(viewModel.linkFailed, isTrue);

    links.fails = false;
    await viewModel.open(viewModel.sources.first);
    expect(viewModel.linkFailed, isFalse);
  });
}
