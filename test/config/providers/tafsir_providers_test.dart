import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/settings_providers.dart';
import 'package:holyquran/config/providers/tafsir_providers.dart';
import 'package:holyquran/data/models/pack_manifest_json.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/tafsir_repository.dart';
import 'package:holyquran/data/services/daos/settings_dao.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_structure.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_pack_install_repository.dart';
import '../../../testing/fakes/fake_pack_integrity_repository.dart';
import '../../../testing/fakes/fake_quran_index_repository.dart';
import '../../../testing/packs/synthetic_tafsir_pack.dart';

final class _FailingReadDao extends SettingsDao {
  _FailingReadDao(super.attachedDatabase);

  @override
  Future<Map<String, StoredSetting>> readAll() async =>
      throw const FormatException('synthetic failure');
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory root;
  late UserDatabase db;
  late FakePackInstallRepository installs;
  late FakePackIntegrityRepository integrity;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('tafsir_providers_test');
    db = UserDatabase(NativeDatabase.memory());
    installs = FakePackInstallRepository();
    integrity = FakePackIntegrityRepository();
  });

  tearDown(() async {
    integrity.dispose();
    installs.dispose();
    await db.close();
    await root.delete(recursive: true);
  });

  /// Sets up the areas the tafsir area reads, then [provideTafsir] over
  /// [settings]; returns the repository it provided, or null.
  Future<TafsirRepository?> setUpArea(SettingsDao settings) async {
    TafsirRepository? provided;
    await buildDependencies(
      areas: [
        (dependencies) async => dependencies
          ..provideListenable<PackInstallRepository>(installs)
          ..provideListenable<PackIntegrityRepository>(integrity)
          ..provide<QuranStructure>(FakeQuranIndexRepository.synthetic()),
        (dependencies) => provideTafsir(
          dependencies,
          settings: settings,
          signatures: const SignatureNotConfigured(),
        ),
        (dependencies) async {
          try {
            provided = dependencies.read<TafsirRepository>();
          } on StateError {
            provided = null;
          }
        },
      ],
    );
    if (provided case final LocalTafsirRepository repository) {
      addTearDown(repository.dispose);
    }
    return provided;
  }

  test('keeps its settings in memory when the user file could not be read '
      '(D-133)', () async {
    final file = File('${root.path}/${UserDatabase.fileName}')
      ..writeAsStringSync('synthetic text that is not a database file' * 100);
    final bytes = file.readAsBytesSync();
    final unreadable = UserDatabase(NativeDatabase(file));
    addTearDown(unreadable.close);
    TafsirRepository? provided;

    await buildDependencies(
      areas: [
        (dependencies) async => dependencies.provide(unreadable),
        settingsProviders,
        (dependencies) async => dependencies
          ..provideListenable<PackInstallRepository>(installs)
          ..provideListenable<PackIntegrityRepository>(integrity)
          ..provide<QuranStructure>(FakeQuranIndexRepository.synthetic()),
        tafsirProviders,
        (dependencies) async =>
            provided = dependencies.tryRead<TafsirRepository>(),
      ],
    );
    if (provided case final LocalTafsirRepository repository) {
      addTearDown(repository.dispose);
    }

    expect(provided, isA<LocalTafsirRepository>());
    expect(file.readAsBytesSync(), bytes);
  });

  group('the area', () {
    Future<TafsirRepository?> over({required bool withStructure}) async {
      TafsirRepository? provided;
      await buildDependencies(
        areas: [
          (dependencies) async => dependencies.provide(db),
          settingsProviders,
          (dependencies) async {
            dependencies
              ..provideListenable<PackInstallRepository>(installs)
              ..provideListenable<PackIntegrityRepository>(integrity);
            if (withStructure) {
              dependencies.provide<QuranStructure>(
                FakeQuranIndexRepository.synthetic(),
              );
            }
          },
          tafsirProviders,
          (dependencies) async =>
              provided = dependencies.tryRead<TafsirRepository>(),
        ],
      );
      if (provided case final LocalTafsirRepository repository) {
        addTearDown(repository.dispose);
      }
      return provided;
    }

    test('provides the repository once the Quran structure is there', () async {
      expect(await over(withStructure: true), isA<LocalTafsirRepository>());
    });

    test('provides nothing, and does not fail, without the Quran '
        'structure', () async {
      expect(await over(withStructure: false), isNull);
    });

    test('reads neither the installer nor the integrity while the structure '
        'is missing', () async {
      expect(
        await buildDependencies(
          areas: [
            (dependencies) async => dependencies.provide(db),
            settingsProviders,
            tafsirProviders,
          ],
        ),
        hasLength(3),
      );
    });
  });

  test('provides a repository that reads installed packs', () async {
    final pack = await buildSyntheticTafsirPack(root);
    installs.installed = [
      InstalledPack(
        manifest: switch (parsePackManifest(
          utf8.encode(jsonEncode(pack.manifest)),
          pack: pack.directory.path,
        )) {
          Ok(:final value) => value,
          Failure(:final error) => throw error,
        },
        directory: pack.directory.path,
        previousVersion: null,
      ),
    ];

    final tafsir = await setUpArea(SettingsDao(db));

    expect(tafsir, isNotNull);
    expect(
      await tafsir!.positionAt('synthetic-tafsir', QuranAddress('hafs', 1, 2)),
      isA<Ok<Object>>(),
    );
    expect(integrity.stateOf('synthetic-tafsir'), isA<IntegrityOk>());
  });

  test('provides nothing when the settings cannot be read', () async {
    expect(await setUpArea(_FailingReadDao(db)), isNull);
  });
}
