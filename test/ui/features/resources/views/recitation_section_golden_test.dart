@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/download_settings_repository.dart';
import 'package:holyquran/domain/models/recitation_download.dart';
import 'package:holyquran/domain/models/recitation_target.dart';
import 'package:holyquran/ui/features/resources/view_models/recitation_section_view_model.dart';
import 'package:holyquran/ui/features/resources/view_models/resources_view_model.dart';
import 'package:holyquran/ui/features/resources/views/resources_screen.dart';

import '../../../../../testing/fakes/fake_catalogue_repository.dart';
import '../../../../../testing/fakes/fake_pack_install_repository.dart';
import '../../../../../testing/fakes/fake_pack_integrity_repository.dart';
import '../../../../../testing/fakes/fake_quran_index_repository.dart';
import '../../../../../testing/fakes/fake_recitation_repository.dart';
import '../../../../../testing/golden.dart';
import '../recitation_downloads_fixtures.dart';

RecitationTarget _target(int quality, RecitationSelection selection) =>
    RecitationTarget(syntheticContents(), quality, selection);

void main() {
  testWidgets('the recitations section with a scope in each state', (
    tester,
  ) async {
    final catalogue = FakeCatalogueRepository(syntheticCatalogue());
    final installs = FakePackInstallRepository(
      installed: [installedRecitationPack()],
    );
    final integrity = FakePackIntegrityRepository();
    addTearDown(integrity.dispose);
    // Surah 1 downloads; surah 2 is whole on the device; surah 3 stopped for
    // want of room, with half of the whole on the device already.
    final downloads = FakeRecitationDownloadRepository()
      ..onDevice = {
        for (var a = 1; a <= 3; a++) ayahPath(64, 2, a),
        ayahPath(64, 1, 1),
      };
    downloads.jobs = [
      jobFor(
        _target(64, const RecitationSurah(1)),
        downloadingBytes(1000000, 2000000),
      ),
      jobFor(
        _target(64, const RecitationSurah(3)),
        const RecitationDownloadFailed(
          RecitationNoSpace('k', neededBytes: 1, freeBytes: 0),
        ),
      ),
    ];
    final resources = ResourcesViewModel(
      catalogue: catalogue,
      installs: installs,
      integrity: integrity,
      freeBytes: () async => 6000,
    );
    final recitations = RecitationSectionViewModel(
      recitations: FakeRecitationRepository(catalogue.catalogue!.recitations),
      catalogue: catalogue,
      installs: installs,
      integrity: integrity,
      downloads: downloads,
      settings: InMemoryDownloadSettingsRepository(
        qualities: {recitationId: 64},
      ),
      index: FakeQuranIndexRepository.synthetic(),
    );
    addTearDown(resources.dispose);
    addTearDown(recitations.dispose);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    expect(recitations.blocks.single.ready, isTrue);

    await expectGoldensInThemes(
      tester,
      'recitation_section',
      (context) =>
          ResourcesScreen(viewModel: resources, recitations: recitations),
      surfaceSize: const Size(390, 1500),
    );
  });
}
