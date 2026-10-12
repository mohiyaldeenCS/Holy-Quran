import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/install_job.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/domain/models/resource_state.dart';
import 'package:holyquran/ui/features/resources/view_models/pack_row_state.dart';
import 'package:holyquran/ui/features/resources/view_models/resources_view_model.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../../testing/fakes/fake_catalogue_repository.dart';
import '../../../../../testing/fakes/fake_pack_install_repository.dart';
import '../../../../../testing/fakes/fake_pack_integrity_repository.dart';
import '../resources_fixtures.dart';

void main() {
  late FakeCatalogueRepository catalogue;
  late FakePackInstallRepository installs;
  late FakePackIntegrityRepository integrity;

  ResourcesViewModel viewModel({int? free = 3000}) {
    final model = ResourcesViewModel(
      catalogue: catalogue,
      installs: installs,
      integrity: integrity,
      freeBytes: () async => free,
    );
    addTearDown(model.dispose);
    return model;
  }

  PackRowState rowOf(ResourcesViewModel model, String id) => model.sections
      .expand((section) => section.rows)
      .singleWhere((row) => row.entry.id == id);

  void failCheck(String id) => integrity.report(
    id,
    IntegrityFailed(FileHashMismatch(id, 'tafsir.sqlite')),
  );

  setUp(() {
    catalogue = FakeCatalogueRepository(catalogueWith());
    installs = FakePackInstallRepository();
    integrity = FakePackIntegrityRepository();
  });

  test('lists tafsirs, then riwayat, and leaves recitations out', () {
    final model = viewModel();
    expect(
      [for (final s in model.sections) s.kind],
      [PackKind.tafsir, PackKind.text],
    );
    expect(
      [for (final row in model.sections.first.rows) row.entry.id],
      [firstUseId, ...extraTafsirs],
    );
    expect(catalogue.refreshCount, 1);
  });

  test('joins each pack with its install and its job', () {
    final cat = catalogue.catalogue!;
    installs
      ..installed = [
        installedTafsir(downloadedId),
        installedTafsir(updateId, version: 1),
        installedTafsir(failedId),
      ]
      ..jobs = [
        jobOf(cat, downloadingId, sixtyPercent),
        jobOf(cat, offlineId, downloadFailed(offlineId)),
      ];
    failCheck(failedId);
    final model = viewModel();

    expect(rowOf(model, firstUseId).state, isA<ResourceAvailable>());
    expect(rowOf(model, downloadingId).state, isA<ResourceDownloading>());
    expect(rowOf(model, downloadingId).progress, closeTo(0.6, 1e-9));
    expect(rowOf(model, downloadedId).state, isA<ResourceDownloaded>());
    expect(rowOf(model, updateId).state, isA<ResourceUpdateAvailable>());
    expect(rowOf(model, failedId).alert, PackRowAlert.integrity);
    expect(rowOf(model, offlineId).alert, PackRowAlert.connection);
    expect(rowOf(model, downloadedId).alert, isNull);
  });

  test('a job of unknown size is at the start of its track', () {
    installs.jobs = [
      jobOf(catalogue.catalogue!, downloadingId, const InstallQueued()),
    ];
    expect(rowOf(viewModel(), downloadingId).progress, 0);
  });

  test('a pack that failed its check at install shows the alert', () {
    installs.jobs = [
      jobOf(catalogue.catalogue!, failedId, verificationFailed(failedId)),
    ];
    final model = viewModel();
    expect(rowOf(model, failedId).state, isA<ResourceAvailable>());
    expect(rowOf(model, failedId).alert, PackRowAlert.integrity);
  });

  test('a failed check of a pack not installed shows no alert', () {
    failCheck(failedId);
    expect(rowOf(viewModel(), failedId).alert, isNull);
  });

  test('the space of each category and the free space add up', () async {
    installs.installed = [
      installedTafsir(downloadedId, bytes: 700),
      installedTafsir(updateId, version: 1, bytes: 300),
    ];
    final model = viewModel();
    await pumpEventQueue();

    final [tafsirs, riwayat] = model.sections;
    expect(tafsirs.usedBytes, 1000);
    expect(riwayat.usedBytes, 0);
    expect(model.storageBytes, 1000 + 3000);
  });

  test(
    'an unknown free space leaves the installed packs as the whole',
    () async {
      installs.installed = [installedTafsir(downloadedId, bytes: 700)];
      final model = viewModel(free: null);
      await pumpEventQueue();
      expect(model.storageBytes, 700);
    },
  );

  test('download, delete and download again call the installer', () async {
    installs.installed = [installedTafsir(failedId)];
    failCheck(failedId);
    final model = viewModel();

    model
      ..download(firstUseId)
      ..delete(downloadedId);
    await model.redownload(offlineId);
    await model.redownload(failedId);
    await pumpEventQueue();

    expect(installs.calls, [
      ('install', firstUseId),
      ('delete', downloadedId),
      ('install', offlineId),
      ('delete', failedId),
      ('install', failedId),
    ]);
  });

  test('a delete that fails is not followed by an install', () async {
    installs
      ..installed = [installedTafsir(failedId)]
      ..deletes = (id) => Failure(AlreadyQueued(id));
    failCheck(failedId);
    final model = viewModel();
    await model.redownload(failedId);
    expect(installs.calls, [('delete', failedId)]);
  });

  test('a failed update job never deletes the working copy', () async {
    installs
      ..installed = [installedTafsir(updateId, version: 1)]
      ..jobs = [
        jobOf(catalogue.catalogue!, updateId, verificationFailed(updateId)),
      ];
    final model = viewModel();
    expect(rowOf(model, updateId).alert, PackRowAlert.integrity);
    await model.redownload(updateId);
    expect(installs.calls, [('install', updateId)]);
  });

  test('the copy downloaded again is not blamed for the old failure', () async {
    installs.installed = [installedTafsir(failedId)];
    failCheck(failedId);
    final model = viewModel();
    await model.redownload(failedId);
    installs.installed = [installedTafsir(failedId)];
    expect(rowOf(model, failedId).alert, isNull);

    failCheck(failedId);
    expect(rowOf(model, failedId).alert, PackRowAlert.integrity);
  });

  test('a pack being verified is at the end of its track', () {
    installs.jobs = [
      jobOf(catalogue.catalogue!, downloadingId, const InstallVerifying()),
    ];
    expect(rowOf(viewModel(), downloadingId).progress, 1);
  });

  test(
    'reads the free space again only when the installed packs change',
    () async {
      var reads = 0;
      final model = ResourcesViewModel(
        catalogue: catalogue,
        installs: installs,
        integrity: integrity,
        freeBytes: () async => 3000 - 100 * reads++,
      );
      addTearDown(model.dispose);
      await pumpEventQueue();
      expect(reads, 1);

      installs.jobs = [
        jobOf(catalogue.catalogue!, downloadingId, sixtyPercent),
      ];
      await pumpEventQueue();
      expect(reads, 1);

      installs.installed = [installedTafsir(downloadedId, bytes: 500)];
      await pumpEventQueue();
      expect(reads, 2);
      expect(model.storageBytes, 500 + 2900);
    },
  );

  test('says the catalogue is unreachable when none is kept', () async {
    catalogue.catalogue = null;
    final model = viewModel();
    await pumpEventQueue();
    expect(model.unreachable, isTrue);
    expect(model.sections, isEmpty);
  });

  test('serves the kept catalogue when the fetch fails', () async {
    final model = viewModel();
    await pumpEventQueue();
    expect(model.unreachable, isFalse);
    expect(model.sections, isNotEmpty);
  });

  test('notifies when a repository changes', () async {
    final model = viewModel();
    await pumpEventQueue();
    final heard = <String>[];
    model.addListener(() => heard.add('change'));
    installs.installed = [installedTafsir(downloadedId)];
    expect(heard, hasLength(1));
    failCheck(downloadedId);
    expect(heard, hasLength(2));
    catalogue.catalogue = catalogueWith(const []);
    expect(heard, hasLength(3));
  });
}
