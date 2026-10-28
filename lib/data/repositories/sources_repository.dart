import 'package:flutter/foundation.dart';

import '../../domain/models/installed_pack.dart';
import '../../domain/models/pack_manifest.dart';
import '../../domain/models/source_credit.dart';
import '../../utils/result.dart';
import '../services/licence_text_service.dart';
import '../services/link_service.dart';
import 'pack_install_repository.dart';

/// The sources of the packs the app has (PRD sections 7.1, 11.1), the licence
/// texts of its fonts, and the opening of a source's link. Listeners hear
/// when the installed packs change. The owner calls [dispose].
abstract interface class SourcesRepository implements Listenable {
  List<SourceCredit> get sources;

  /// The OFL text of each font family, unchanged; a [Failure] when they
  /// cannot be read.
  Future<Result<List<String>>> fontLicences();

  /// Opens the link of [source] in the browser; a [Failure] when its address
  /// is not one the system can open.
  Future<Result<void>> openLink(SourceCredit source);

  void dispose();
}

/// [SourcesRepository] over the manifests of the base pack, [_basePack], and
/// of the packs [_installs] holds; either may be absent. The base pack comes
/// first.
final class PackSourcesRepository extends ChangeNotifier
    implements SourcesRepository {
  PackSourcesRepository({
    required this._links,
    required this._licences,
    this._basePack,
    this._installs,
  }) {
    _installs?.addListener(notifyListeners);
  }

  final LinkService _links;
  final LicenceTextService _licences;
  final PackManifest? _basePack;
  final PackInstallRepository? _installs;

  @override
  List<SourceCredit> get sources => sourcesOf([
    ?_basePack,
    for (final pack in _installs?.installed ?? <InstalledPack>[]) pack.manifest,
  ]);

  @override
  Future<Result<List<String>>> fontLicences() => _licences.fontLicences();

  @override
  Future<Result<void>> openLink(SourceCredit source) {
    final url = Uri.tryParse(source.url);
    if (url == null) return Future.value(Failure(LinkNotOpened(source.url)));
    return _links.open(url);
  }

  @override
  void dispose() {
    _installs?.removeListener(notifyListeners);
    super.dispose();
  }
}
