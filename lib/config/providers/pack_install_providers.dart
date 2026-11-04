import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:holyquran/config/base_pack.dart';
import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/signing_keys.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/services/connectivity_service.dart';
import 'package:holyquran/data/services/download_service.dart';
import 'package:holyquran/data/services/free_space_service.dart';
import 'package:holyquran/data/services/installed_packs_store.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';

/// Makes the installer of [packInstallProviders], given what it is told of
/// the packs and the service that downloads its files.
typedef InstallerFactory = LocalPackInstallRepository Function({
  required DownloadService downloads,
  void Function(String packId)? onPackChanged,
  Set<String> reservedPackIds,
});

/// Provides the device's [FreeSpaceService], which the resource manager
/// reads too, the [DownloadService] the installer and the recitation
/// downloads share (the plugin keeps one callback for its group), and the
/// installer, and starts it: the installed packs are
/// read, and downloads cut short by the last session are picked up. The
/// start does not delay the first frame. It fails as a result of the
/// installer's `started`, and throws only an [Error], which is a bug and is
/// reported as one. A pack installed again, rolled back or deleted is
/// forgotten by the integrity repository, when the Quran area provided one,
/// so that an old failure is not shown for the new files; the bundled base
/// pack's id is never installed over.
Future<void> packInstallProviders(Dependencies dependencies) =>
    providePackInstall(
      dependencies,
      create: packInstallRepository,
      basePack: basePackInUse,
    );

/// [packInstallProviders] over the installer [create] makes, which never
/// installs over the id of the [basePack] the app reads, the unapproved test
/// copy's in a test copy (D-163).
Future<void> providePackInstall(
  Dependencies dependencies, {
  required InstallerFactory create,
  ({String id, int version})? basePack,
  DownloadService? downloads,
}) async {
  final service = downloads ?? BackgroundDownloadService.applicationSupport();
  dependencies
    ..provide<FreeSpaceService>(const DiskFreeSpaceService())
    ..provide<DownloadService>(service);
  provideInstaller(
    dependencies,
    create(
      downloads: service,
      onPackChanged: dependencies.tryRead<PackIntegrityRepository>()?.forget,
      reservedPackIds: {?basePack?.id},
    ),
  );
}

/// Provides [installer] as the [PackInstallRepository] and starts it without
/// waiting.
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
LocalPackInstallRepository packInstallRepository({
  required DownloadService downloads,
  void Function(String packId)? onPackChanged,
  Set<String> reservedPackIds = const {},
}) => LocalPackInstallRepository(
  openStore: InstalledPacksStore.openInApplicationSupport,
  downloads: downloads,
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
  onPackChanged: onPackChanged,
  reservedPackIds: reservedPackIds,
);
