import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/install_job.dart';
import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_pack_install_repository.dart';

final _pack = InstalledPack(
  manifest: PackManifest(
    formatVersion: 1,
    id: 'synthetic-text',
    kind: PackKind.text,
    version: 1,
    changelog: const [],
    riwaya: 'synthetic',
    edition: 'synthetic',
    font: const PackFont(family: 'Synthetic', version: '1', sha256: ''),
    sources: const [],
    files: const [],
    surahSha256: const {},
    counts: PackCounts(
      surahs: 0,
      ayat: 0,
      words: 0,
      marks: 0,
      divisions: {for (final division in Division.values) division: 0},
      sajdas: 0,
    ),
    reviews: const [],
  ),
  directory: '/synthetic/packs/synthetic-text/1',
  previousVersion: null,
);

final _request = InstallRequest(
  packId: 'synthetic-text',
  version: 2,
  manifest: RemoteFile(
    url: Uri.parse('https://example.invalid/manifest.json'),
    sha256: '0' * 64,
    bytes: 1,
  ),
  signature: null,
  files: const {},
  wifiOnly: false,
);

void main() {
  test('setting installed or jobs notifies listeners', () {
    final fake = FakePackInstallRepository();
    var notified = 0;
    fake.addListener(() => notified++);
    fake.installed = [_pack];
    fake.jobs = [InstallJob(_request, const InstallQueued())];
    expect(notified, 2);
    expect(fake.installed, [_pack]);
    expect(fake.jobs.single.request, same(_request));
  });

  test('answers as scripted and logs every call', () async {
    final fake = FakePackInstallRepository(installed: [_pack]);
    expect(await fake.started, isA<Ok<void>>());
    expect(
      await fake.install(_request),
      isA<Failure<InstalledPack>>().having(
        (f) => f.error,
        'error',
        isA<AlreadyQueued>(),
      ),
    );
    expect(
      await fake.rollback('synthetic-text'),
      isA<Failure<InstalledPack>>().having(
        (f) => f.error,
        'error',
        isA<NoPreviousVersion>(),
      ),
    );
    expect(await fake.delete('synthetic-text'), isA<Ok<void>>());

    fake
      ..startedWith = const Failure(StoreFailed('synthetic-text', 'synthetic'))
      ..installs = ((_) => Ok(_pack))
      ..rollbacks = ((_) => Ok(_pack))
      ..deletes = ((id) => Failure(InvalidPackId(id)));
    expect(await fake.started, isA<Failure<void>>());
    expect(await fake.install(_request), isA<Ok<InstalledPack>>());
    expect(await fake.rollback('synthetic-text'), isA<Ok<InstalledPack>>());
    expect(await fake.delete('synthetic-text'), isA<Failure<void>>());
    await fake.pause('synthetic-text');
    await fake.resume('synthetic-text');
    await fake.cancel('synthetic-text');

    expect(fake.calls, [
      ('install', 'synthetic-text'),
      ('rollback', 'synthetic-text'),
      ('delete', 'synthetic-text'),
      ('install', 'synthetic-text'),
      ('rollback', 'synthetic-text'),
      ('delete', 'synthetic-text'),
      ('pause', 'synthetic-text'),
      ('resume', 'synthetic-text'),
      ('cancel', 'synthetic-text'),
    ]);
  });
}
