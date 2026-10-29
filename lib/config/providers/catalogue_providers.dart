import 'package:flutter/foundation.dart';
import 'package:holyquran/config/catalogue_config.dart';
import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/signing_keys.dart';
import 'package:holyquran/data/repositories/catalogue_repository.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/recitation_repository.dart';
import 'package:holyquran/data/services/catalogue_service.dart';
import 'package:holyquran/data/services/download_service.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';

/// Provides the [CatalogueRepository] once the catalogue is configured;
/// until then there is nothing to fetch and the area provides nothing. The
/// recitations it lists follow.
Future<void> catalogueProviders(Dependencies dependencies) async {
  if (catalogueUrl case final url?) {
    dependencies.provideListenable<CatalogueRepository>(
      catalogueRepository(url),
    );
  }
  provideRecitations(dependencies);
}

/// Provides the [RecitationRepository] over the catalogue, the installer and
/// the integrity repository earlier areas provided. Recitations are played
/// from verified packs, so without the catalogue or the integrity repository,
/// which needs a base pack, none is provided.
void provideRecitations(Dependencies dependencies) {
  final catalogue = dependencies.tryRead<CatalogueRepository>();
  final integrity = dependencies.tryRead<PackIntegrityRepository>();
  if (catalogue == null || integrity == null) return;
  dependencies.provideListenable<RecitationRepository>(
    recitationRepository(
      catalogue: catalogue,
      installs: dependencies.read<PackInstallRepository>(),
      integrity: integrity,
    ),
  );
}

/// The catalogue at [address] on the device's services: `https` only, its
/// last accepted copy under application support, and a catalogue whose
/// signature was not checked accepted outside release builds (D-108).
/// Nothing touches a plugin until [RemoteCatalogueRepository.refresh].
RemoteCatalogueRepository catalogueRepository(Uri address) =>
    RemoteCatalogueRepository(
      address: address,
      service: const CatalogueService(),
      openStore: () async =>
          CatalogueStore('${await applicationSupportPath()}/catalogue'),
      verifier: Ed25519ManifestVerifier(manifestPublicKeys),
      policy: UrlPolicy.httpsOnly,
      acceptUnchecked: !kReleaseMode,
    );

/// The recitations [catalogue] lists, played from the recitation packs
/// [installs] holds, each verified once per session and reported to
/// [integrity]; downloaded audio under `recitations/` in application
/// support.
PackRecitationRepository recitationRepository({
  required CatalogueRepository catalogue,
  required PackInstallRepository installs,
  required PackIntegrityRepository integrity,
}) => PackRecitationRepository(
  catalogue: () => catalogue.catalogue,
  installed: () => installs.installed,
  changes: Listenable.merge([catalogue, installs]),
  verify: LocalPackRepository(
    files: const PackFileService(),
    signatures: Ed25519ManifestVerifier(manifestPublicKeys),
  ).verify,
  integrityOf: integrity.stateOf,
  report: (pack, state, version) =>
      integrity.report(pack, state, version: version),
  files: const PackFileService(),
  audioDirectory: () async => '${await applicationSupportPath()}/recitations',
);
