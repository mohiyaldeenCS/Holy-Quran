import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';

PackManifest _manifest({required String id, required int version}) =>
    PackManifest(
      formatVersion: 1,
      id: id,
      kind: PackKind.text,
      version: version,
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
    );

void main() {
  test('id and version are the manifest\'s', () {
    final pack = InstalledPack(
      manifest: _manifest(id: 'synthetic-text', version: 3),
      directory: '/synthetic/packs/synthetic-text/3',
      previousVersion: 2,
    );
    expect(pack.id, 'synthetic-text');
    expect(pack.version, 3);
    expect(pack.previousVersion, 2);
    expect(pack.directory, '/synthetic/packs/synthetic-text/3');
  });
}
