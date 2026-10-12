import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/catalogue.dart';
import 'package:holyquran/domain/models/catalogue_entry.dart';
import 'package:holyquran/domain/models/download_progress.dart';
import 'package:holyquran/domain/models/install_job.dart';
import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/domain/models/resource_state.dart';

final _hash = 'a' * 64;

RemoteFile _remote(String name) => RemoteFile(
  url: Uri.parse('https://example.invalid/$name'),
  sha256: _hash,
  bytes: 10,
);

CatalogueEntry _entry(String id, int version) => CatalogueEntry(
  id: id,
  kind: PackKind.tafsir,
  version: version,
  title: 'Synthetic title',
  manifest: _remote('manifest.json'),
  signature: null,
  files: {'tafsir.sqlite': _remote('tafsir.sqlite')},
  source: 'Synthetic source',
  changes: 'Synthetic changes',
  role: null,
);

InstalledPack _installed(String id, int version) => InstalledPack(
  manifest: PackManifest(
    formatVersion: 2,
    id: id,
    kind: PackKind.tafsir,
    version: version,
    changelog: const [],
    riwaya: 'hafs',
    sources: const [],
    files: const [],
    counts: const TafsirCounts(passages: 1),
    reviews: const [],
  ),
  directory: '/synthetic/$id/$version',
  previousVersion: null,
);

InstallJob _job(String id, InstallState state) =>
    InstallJob(_entry(id, 1).installRequest(wifiOnly: false), state);

void main() {
  final entry = _entry('synthetic-tafsir', 2);

  ResourceState stateOf({InstalledPack? installed, InstallJob? job}) =>
      resourceOf(entry, installed: installed, job: job).state;

  test('a pack that is not installed is available', () {
    expect(stateOf(), const ResourceAvailable());
  });

  test('the catalogue version installed is downloaded', () {
    expect(
      stateOf(installed: _installed(entry.id, 2)),
      const ResourceDownloaded(2),
    );
    expect(
      stateOf(installed: _installed(entry.id, 3)),
      const ResourceDownloaded(3),
    );
  });

  test('an older version installed has an update', () {
    expect(
      stateOf(installed: _installed(entry.id, 1)),
      const ResourceUpdateAvailable(installedVersion: 1, version: 2),
    );
  });

  test('a job in the queue is downloading, with a percent once known', () {
    const progress = DownloadProgress(receivedBytes: 1, totalBytes: 3);
    for (final (job, percent) in [
      (const InstallDownloading(progress), 33),
      (const InstallPaused(progress), 33),
      (
        const InstallDownloading(
          DownloadProgress(receivedBytes: 0, totalBytes: null),
        ),
        null,
      ),
      (const InstallQueued(), null),
      (const InstallVerifying(), null),
      (const InstallWaitingForNetwork(wifiOnly: true), null),
      (const InstallStoppedLowSpace(neededBytes: 9, freeBytes: 1), null),
    ]) {
      for (final installed in [null, _installed(entry.id, 1)]) {
        final state = stateOf(installed: installed, job: _job(entry.id, job));
        expect(state, isA<ResourceDownloading>());
        state as ResourceDownloading;
        expect(state.job, same(job));
        expect(state.percent, percent);
      }
    }
  });

  test('a failed job leaves the state and names its failure', () {
    final failure = DownloadFailed(entry.id, 'tafsir.sqlite');
    final job = _job(entry.id, InstallFailed(failure));
    final available = resourceOf(entry, installed: null, job: job);
    expect(available.state, const ResourceAvailable());
    expect(available.failure, same(failure));
    final older = resourceOf(
      entry,
      installed: _installed(entry.id, 1),
      job: job,
    );
    expect(
      older.state,
      const ResourceUpdateAvailable(installedVersion: 1, version: 2),
    );
    expect(older.failure, same(failure));
    expect(resourceOf(entry, installed: null, job: null).failure, isNull);
  });

  test('resourcesOf joins each pack with its own install and job', () {
    final other = _entry('synthetic-other', 1);
    final catalogue = Catalogue(
      date: '2026-10-12',
      packs: [entry, other],
      recitations: const [],
    );
    final resources = resourcesOf(
      catalogue,
      installed: [_installed(other.id, 1), _installed('synthetic-gone', 1)],
      jobs: [_job(entry.id, const InstallQueued())],
    );
    expect([for (final r in resources) r.entry], [entry, other]);
    expect(resources[0].state, isA<ResourceDownloading>());
    expect(resources[1].state, const ResourceDownloaded(1));
  });

  test('states compare by value and name themselves', () {
    expect(
      const ResourceAvailable().hashCode,
      const ResourceAvailable().hashCode,
    );
    expect(const ResourceDownloaded(1), isNot(const ResourceDownloaded(2)));
    expect(
      const ResourceUpdateAvailable(installedVersion: 1, version: 2).hashCode,
      const ResourceUpdateAvailable(installedVersion: 1, version: 2).hashCode,
    );
    expect('${const ResourceAvailable()}', 'available');
    expect('${const ResourceDownloaded(2)}', 'downloaded 2');
    expect(
      '${const ResourceUpdateAvailable(installedVersion: 1, version: 2)}',
      'newer 2 over 1',
    );
    expect('${const ResourceDownloading(InstallQueued())}', 'downloading null');
  });
}
