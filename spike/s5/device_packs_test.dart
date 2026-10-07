import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';
import 'package:holyquran/domain/models/verified_pack.dart';
import 'package:holyquran/utils/result.dart';

import '../../testing/packs/synthetic_pack.dart';
import 'device_packs.dart';

void main() {
  late Directory temp;
  late Directory repository;

  setUp(() async {
    repository = Directory.current;
    temp = await Directory.systemTemp.createTemp('s5_device_packs');
  });

  tearDown(() async {
    Directory.current = repository;
    await temp.delete(recursive: true);
  });

  test('builds two verifiable versions from a working directory without the '
      'font, then leaves them alone', () async {
    final font = await File(amiriQuranFontPath).readAsBytes();
    Directory.current = temp;
    expect(File(amiriQuranFontPath).existsSync(), isFalse);
    final served = Directory('${temp.path}/served');

    final lines = await buildDevicePacks(
      served: served,
      work: Directory('${temp.path}/work'),
      font: font,
      id: 'synthetic-device',
      bytes: 50000,
    );
    expect(lines, hasLength(2));
    expect(Directory.current.path, temp.path);

    const verifier = LocalPackRepository(
      files: PackFileService(),
      signatures: SignatureNotConfigured(),
    );
    final hashes = <String>{};
    for (final version in [1, 2]) {
      final result = await verifier.verify(
        '${served.path}/synthetic-device/$version',
      );
      expect(result, isA<Ok<VerifiedPack>>(), reason: 'version $version');
      hashes.add(
        (result as Ok<VerifiedPack>).value.manifest.files.single.sha256,
      );
    }
    expect(hashes, hasLength(2));

    expect(
      await buildDevicePacks(
        served: served,
        work: Directory('${temp.path}/work'),
        font: font,
        id: 'synthetic-device',
        bytes: 50000,
      ),
      isEmpty,
    );
  });
}
