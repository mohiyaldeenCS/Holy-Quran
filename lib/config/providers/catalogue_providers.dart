import 'package:flutter/foundation.dart';
import 'package:holyquran/config/catalogue_config.dart';
import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/signing_keys.dart';
import 'package:holyquran/data/repositories/catalogue_repository.dart';
import 'package:holyquran/data/services/catalogue_service.dart';
import 'package:holyquran/data/services/download_service.dart';
import 'package:holyquran/data/services/manifest_signature.dart';

/// Provides the [CatalogueRepository] once the catalogue is configured;
/// until then there is nothing to fetch and the area provides nothing.
Future<void> catalogueProviders(Dependencies dependencies) async {
  if (catalogueUrl case final url?) {
    dependencies.provideListenable<CatalogueRepository>(
      catalogueRepository(url),
    );
  }
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
