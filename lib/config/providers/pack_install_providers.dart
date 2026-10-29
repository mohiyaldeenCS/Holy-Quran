import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/signing_keys.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/services/connectivity_service.dart';
import 'package:holyquran/data/services/download_service.dart';
import 'package:holyquran/data/services/free_space_service.dart';
import 'package:holyquran/data/services/installed_packs_store.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';

/// Provides the installer and starts it: the installed packs are read, and
/// downloads cut short by the last session are picked up. Starting never
/// throws and does not delay the first frame; a start that failed is the
/// result of the installer's `started`.
Future<void> packInstallProviders(Dependencies dependencies) async =>
    provideInstaller(dependencies, packInstallRepository());

/// Provides [installer] as the [PackInstallRepository] and starts it.
void provideInstaller(
  Dependencies dependencies,
  LocalPackInstallRepository installer,
) {
  dependencies.provideListenable<PackInstallRepository>(installer);
  unawaited(installer.start());
}

/// The pack installer on the device's services: `https` only, and a pack
/// whose signature was not checked accepted outside release builds (D-108).
/// Nothing touches a plugin until [LocalPackInstallRepository.start].
LocalPackInstallRepository packInstallRepository() =>
    LocalPackInstallRepository(
      openStore: InstalledPacksStore.openInApplicationSupport,
      downloads: BackgroundDownloadService.applicationSupport(),
      urlCheck: const HttpUrlCheck(),
      connectivity: PlusConnectivityService(),
      freeSpace: const DiskFreeSpaceService(),
      files: const PackFileService(),
      verifier: LocalPackRepository(
        files: const PackFileService(),
        signatures: Ed25519ManifestVerifier(manifestPublicKeys),
      ),
      policy: UrlPolicy.httpsOnly,
      acceptUnchecked: !kReleaseMode,
    );
