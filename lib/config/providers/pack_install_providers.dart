import 'package:flutter/foundation.dart';
import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/services/connectivity_service.dart';
import 'package:holyquran/data/services/download_service.dart';
import 'package:holyquran/data/services/free_space_service.dart';
import 'package:holyquran/data/services/installed_packs_store.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';

Future<void> packInstallProviders(Dependencies dependencies) async {}

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
      verifier: const LocalPackRepository(
        files: PackFileService(),
        signatures: SignatureNotConfigured(),
      ),
      policy: UrlPolicy.httpsOnly,
      acceptUnchecked: !kReleaseMode,
    );
