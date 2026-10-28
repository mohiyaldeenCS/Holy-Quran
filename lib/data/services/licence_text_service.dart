import 'package:flutter/services.dart';

import '../../utils/result.dart';

/// Reads the licence texts the app ships.
abstract interface class LicenceTextService {
  /// The texts under `assets/licenses/`, unchanged, in the order of their
  /// file names.
  Future<Result<List<String>>> fontLicences();
}

/// Reads them from the asset bundle.
final class AssetLicenceTextService implements LicenceTextService {
  AssetLicenceTextService({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  static const _folder = 'assets/licenses/';

  final AssetBundle _bundle;

  @override
  Future<Result<List<String>>> fontLicences() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
      final paths =
          manifest
              .listAssets()
              .where((path) => path.startsWith(_folder))
              .toList()
            ..sort();
      return Ok([for (final path in paths) await _bundle.loadString(path)]);
    } on Exception catch (error) {
      return Failure(error);
    }
  }
}
