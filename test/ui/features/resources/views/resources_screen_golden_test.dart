@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/ui/features/resources/view_models/resources_view_model.dart';
import 'package:holyquran/ui/features/resources/views/resources_screen.dart';

import '../../../../../testing/fakes/fake_catalogue_repository.dart';
import '../../../../../testing/fakes/fake_pack_install_repository.dart';
import '../../../../../testing/fakes/fake_pack_integrity_repository.dart';
import '../../../../../testing/golden.dart';
import '../resources_fixtures.dart';

void main() {
  testWidgets('the manager with a pack in each state', (tester) async {
    final catalogue = FakeCatalogueRepository(catalogueWith());
    final cat = catalogue.catalogue!;
    final installs = FakePackInstallRepository(
      installed: [
        installedTafsir(downloadedId),
        installedTafsir(updateId, version: 1),
        installedTafsir(failedId, bytes: 2000),
      ],
      jobs: [
        jobOf(cat, downloadingId, sixtyPercent),
        jobOf(cat, offlineId, downloadFailed(offlineId)),
      ],
    );
    final integrity = FakePackIntegrityRepository({
      failedId: const IntegrityFailed(
        FileHashMismatch(failedId, 'tafsir.sqlite'),
      ),
    });
    final viewModel = ResourcesViewModel(
      catalogue: catalogue,
      installs: installs,
      integrity: integrity,
      freeBytes: () async => 6000,
    );
    addTearDown(viewModel.dispose);
    await expectGoldensInThemes(
      tester,
      'resources_screen',
      (context) => ResourcesScreen(viewModel: viewModel),
      surfaceSize: const Size(390, 1500),
    );
  });
}
