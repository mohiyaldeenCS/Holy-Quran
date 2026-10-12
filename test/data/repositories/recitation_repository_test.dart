import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/models/catalogue_json.dart';
import 'package:holyquran/data/models/pack_manifest_json.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/repositories/recitation_repository.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';
import 'package:holyquran/domain/models/catalogue.dart';
import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/recitation_file.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_catalogue_repository.dart';
import '../../../testing/fakes/fake_pack_integrity_repository.dart';
import '../../../testing/packs/synthetic_recitation_pack.dart';
import '../../../testing/packs/synthetic_tafsir_pack.dart';

const _listed = 'synthetic-listed';
const _pending = 'synthetic-rights-pending';
const _pack = 'synthetic-recitation';

void main() {
  late Directory root;
  late String audio;
  late FakePackIntegrityRepository integrity;
  late List<String> verified;
  late ValueNotifier<int> changes;
  late Catalogue? catalogue;
  late List<InstalledPack> installed;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('recitation_repository');
    audio = '${root.path}/audio';
    integrity = FakePackIntegrityRepository();
    verified = [];
    changes = ValueNotifier(0);
    catalogue = syntheticCatalogue();
    installed = [];
  });

  tearDown(() async {
    integrity.dispose();
    changes.dispose();
    await root.delete(recursive: true);
  });

  PackRecitationRepository repository() => PackRecitationRepository(
    catalogue: () => catalogue,
    installed: () => installed,
    changes: changes,
    verify: (directory) {
      verified.add(directory);
      return const LocalPackRepository(
        files: PackFileService(),
        signatures: SignatureNotConfigured(),
      ).verify(directory);
    },
    integrity: integrity,
    files: const PackFileService(),
    audioDirectory: () async => audio,
  );

  /// Builds a recitation pack under the root and installs it.
  Future<SyntheticRecitationPack> install({
    String id = _pack,
    int version = 1,
    String unit = 'ayah',
    SyntheticRecitationFault? fault,
  }) async {
    final pack = await buildSyntheticRecitationPack(
      Directory('${root.path}/packs'),
      id: id,
      version: version,
      unit: unit,
      fault: fault,
    );
    final manifest = await File(
      '${pack.directory.path}/manifest.json',
    ).readAsBytes();
    installed = [
      ...installed.where((p) => p.id != id),
      InstalledPack(
        manifest:
            (parsePackManifest(manifest, pack: id) as Ok<PackManifest>).value,
        directory: pack.directory.path,
        previousVersion: null,
      ),
    ];
    return pack;
  }

  SyntheticRecitationFile fileOf(
    SyntheticRecitationPack pack,
    int quality,
    int surah,
    int? ayah,
  ) => pack.files.firstWhere(
    (f) =>
        f.qualityKbps == quality &&
        f.surah == surah &&
        f.ayah == ayah &&
        (f.part == 'ayah' || f.part == 'surah'),
  );

  Catalogue catalogueWith(void Function(Map<String, Object?> recitation) edit) {
    final json = syntheticCatalogueJson();
    edit(
      (json['recitations']! as List<Object?>).first! as Map<String, Object?>,
    );
    return (parseCatalogue(catalogueBytes(json)) as Ok<Catalogue>).value;
  }

  RecitationAudio audioOf(Result<RecitationAudio> result) => switch (result) {
    Ok(:final value) => value,
    Failure(:final error) => fail('$error'),
  };

  Matcher failsWith<T>() =>
      isA<Failure<RecitationAudio>>().having((f) => f.error, 'error', isA<T>());

  final first = QuranAddress('hafs', 1, 1);

  group('the listing', () {
    test('holds only recitations whose rights record is complete', () {
      expect([for (final r in repository().recitations) r.id], [_listed]);
    });

    test('is empty without a catalogue', () {
      catalogue = null;
      expect(repository().recitations, isEmpty);
    });

    test('a recitation without complete rights is never played', () async {
      await install(id: 'synthetic-unlisted');
      final recitations = repository();
      expect(
        await recitations.ayahFile(_pending, first, qualityKbps: 64),
        failsWith<RecitationNotListed>(),
      );
      expect(
        await recitations.surahFile('synthetic-none', 1, qualityKbps: 64),
        failsWith<RecitationNotListed>(),
      );
      expect(verified, isEmpty);
    });

    test('listeners hear the changes they are given', () {
      final recitations = repository();
      var notified = 0;
      void listener() => notified++;
      recitations.addListener(listener);
      changes.value++;
      recitations.removeListener(listener);
      changes.value++;
      expect(notified, 1);
    });
  });

  group('a file', () {
    test('is streamed from the pack base URL when not downloaded', () async {
      final pack = await install();
      final result = audioOf(
        await repository().ayahFile(_listed, first, qualityKbps: 64),
      );
      final expected = fileOf(pack, 64, 1, 1);
      expect(result.local, isFalse);
      expect(result.uri, Uri.parse(pack.baseUrl).resolve(expected.path));
      expect(result.file.path, expected.path);
      expect(result.file.bytes, expected.bytes);
      expect(result.file.sha256, expected.sha256);
      expect(result.file.part, RecitationFilePart.ayah);
    });

    test('is taken from the device when downloaded whole', () async {
      final pack = await install();
      final expected = fileOf(pack, 128, 1, 1);
      final local = File('$audio/$_pack/${expected.path}');
      await local.create(recursive: true);
      await local.writeAsBytes(expected.audio);

      final recitations = repository();
      final result = audioOf(
        await recitations.ayahFile(_listed, first, qualityKbps: 128),
      );
      expect(result.local, isTrue);
      expect(result.uri, Uri.file(local.path));

      final other = audioOf(
        await recitations.ayahFile(_listed, first, qualityKbps: 64),
      );
      expect(other.local, isFalse);

      await local.writeAsBytes(expected.audio.sublist(1));
      final partial = audioOf(
        await recitations.ayahFile(_listed, first, qualityKbps: 128),
      );
      expect(partial.local, isFalse);
      expect(partial.uri.scheme, 'https');
    });

    test('of a recitation by surah is its surah file', () async {
      catalogue = catalogueWith((r) => r['unit'] = 'surah');
      final pack = await install(unit: 'surah');
      final recitations = repository();
      final result = audioOf(
        await recitations.surahFile(_listed, 1, qualityKbps: 128),
      );
      expect(result.file.path, fileOf(pack, 128, 1, null).path);
      expect(result.file.part, RecitationFilePart.surah);
      expect(
        await recitations.ayahFile(_listed, first, qualityKbps: 128),
        failsWith<RecitationFileNotInPack>(),
      );
    });

    test('not in the pack is not found', () async {
      await install();
      final recitations = repository();
      final missing = await recitations.surahFile(_listed, 1, qualityKbps: 64);
      expect(missing, failsWith<RecitationFileNotInPack>());
      expect(
        '${(missing as Failure).error}',
        'RecitationFileNotInPack($_listed): 64 kbps, surah 1',
      );
      expect(
        await recitations.ayahFile(_listed, first, qualityKbps: 96),
        failsWith<RecitationFileNotInPack>(),
      );
      expect(
        await recitations.ayahFile(
          _listed,
          QuranAddress('hafs', 999, 1),
          qualityKbps: 64,
        ),
        failsWith<RecitationFileNotInPack>(),
      );
    });

    test('of an address of another riwaya is not in the pack', () async {
      await install();
      expect(
        await repository().ayahFile(
          _listed,
          QuranAddress('warsh', 1, 1),
          qualityKbps: 64,
        ),
        failsWith<AddressNotInPack>(),
      );
    });

    test('needs its recitation pack installed', () async {
      final result = await repository().ayahFile(
        _listed,
        first,
        qualityKbps: 64,
      );
      expect(result, failsWith<RecitationPackNotInstalled>());
      expect(
        '${(result as Failure).error}',
        'RecitationPackNotInstalled($_listed): $_pack',
      );
    });
  });

  group('the recitation pack', () {
    test('is verified once per session and reported ok', () async {
      final pack = await install();
      final recitations = repository();
      await Future.wait([
        recitations.ayahFile(_listed, first, qualityKbps: 64),
        recitations.ayahFile(_listed, first, qualityKbps: 128),
      ]);
      await recitations.ayahFile(_listed, first, qualityKbps: 64);
      expect(verified, [pack.directory.path]);
      expect(integrity.stateOf(_pack), isA<IntegrityOk>());
      expect(integrity.reports.single.version, 1);
    });

    test('is verified again when another version is installed', () async {
      await install();
      final recitations = repository();
      await recitations.ayahFile(_listed, first, qualityKbps: 64);
      final newer = await install(version: 2);
      final result = await recitations.ayahFile(
        _listed,
        first,
        qualityKbps: 64,
      );
      expect(result, isA<Ok<RecitationAudio>>());
      expect(verified.last, newer.directory.path);
      expect(verified, hasLength(2));
    });

    test('that fails its check serves nothing for the session', () async {
      final pack = await install(
        fault: SyntheticRecitationFault.wrongFileCount,
      );
      final recitations = repository();
      final result = await recitations.ayahFile(
        _listed,
        first,
        qualityKbps: 64,
      );
      expect(result, failsWith<PackInconsistent>());
      expect(
        integrity.stateOf(_pack),
        isA<IntegrityFailed>().having(
          (s) => s.reason,
          'reason',
          isA<PackInconsistent>(),
        ),
      );
      expect(
        await recitations.surahFile(_listed, 1, qualityKbps: 64),
        failsWith<PackInconsistent>(),
      );
      expect(verified, [pack.directory.path]);
    });

    test('whose file differs from its manifest serves nothing', () async {
      final pack = await install();
      await pack.file.writeAsBytes([0], mode: FileMode.append);
      expect(
        await repository().ayahFile(_listed, first, qualityKbps: 64),
        failsWith<FileHashMismatch>(),
      );
      expect(integrity.stateOf(_pack), isA<IntegrityFailed>());
    });

    test('that another reader reports failed serves nothing', () async {
      await install();
      final recitations = repository();
      await recitations.ayahFile(_listed, first, qualityKbps: 64);
      integrity.report(
        _pack,
        const IntegrityFailed(PackInconsistent(_pack, 'synthetic')),
      );
      expect(
        await recitations.ayahFile(_listed, first, qualityKbps: 64),
        failsWith<PackDisabled>(),
      );
    });

    test('must match the catalogue', () async {
      final cases = <String, (Catalogue, String, SyntheticRecitationFault?)>{
        'unit': (catalogueWith((r) => r['unit'] = 'surah'), 'ayah', null),
        'qualities': (
          catalogueWith((r) => r['qualities'] = [64]),
          'ayah',
          null,
        ),
        'riwaya': (catalogueWith((r) => r['riwaya'] = 'warsh'), 'ayah', null),
        'rows': (
          syntheticCatalogue(),
          'ayah',
          SyntheticRecitationFault.partOfOtherUnit,
        ),
      };
      for (final MapEntry(key: name, value: (edited, unit, fault))
          in cases.entries) {
        catalogue = edited;
        integrity = FakePackIntegrityRepository();
        await install(unit: unit, fault: fault);
        final recitations = repository();
        final address = QuranAddress(
          edited.recitations.first.recitation.riwaya,
          1,
          1,
        );
        final result = edited.recitations.first.recitation.unit.name == 'ayah'
            ? await recitations.ayahFile(_listed, address, qualityKbps: 64)
            : await recitations.surahFile(_listed, 1, qualityKbps: 64);
        expect(result, failsWith<PackInconsistent>(), reason: name);
        expect(integrity.stateOf(_pack), isA<IntegrityFailed>(), reason: name);
        integrity.dispose();
        await Directory('${root.path}/packs').delete(recursive: true);
      }
      integrity = FakePackIntegrityRepository();
    });

    test('of another kind is not a recitation pack', () async {
      final tafsir = await buildSyntheticTafsirPack(
        Directory('${root.path}/packs'),
        id: _pack,
      );
      final manifest = await File(
        '${tafsir.directory.path}/manifest.json',
      ).readAsBytes();
      installed = [
        InstalledPack(
          manifest:
              (parsePackManifest(manifest, pack: _pack) as Ok<PackManifest>)
                  .value,
          directory: tafsir.directory.path,
          previousVersion: null,
        ),
      ];
      expect(
        await repository().ayahFile(_listed, first, qualityKbps: 64),
        failsWith<PackInconsistent>(),
      );
    });
  });
}
