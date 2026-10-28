import 'package:flutter/foundation.dart';

import '../../domain/models/source_credit.dart';
import '../../utils/result.dart';
import '../services/link_service.dart';
import 'pack_install_repository.dart';

/// The sources of the installed packs (PRD §7.1) and the opening of their
/// links. Listeners hear when the installed packs change.
abstract interface class SourcesRepository implements Listenable {
  List<SourceCredit> get sources;

  /// Opens the link of [source] in the browser; a [Failure] when its address
  /// is not one the system can open.
  Future<Result<void>> openLink(SourceCredit source);
}

/// [SourcesRepository] over the manifests of the packs [_installs] holds.
final class PackSourcesRepository extends ChangeNotifier
    implements SourcesRepository {
  PackSourcesRepository({required this._installs, required this._links}) {
    _installs.addListener(notifyListeners);
  }

  final PackInstallRepository _installs;
  final LinkService _links;

  @override
  List<SourceCredit> get sources => sourcesOf(_installs.installed);

  @override
  Future<Result<void>> openLink(SourceCredit source) {
    final url = Uri.tryParse(source.url);
    if (url == null) return Future.value(Failure(LinkNotOpened(Uri())));
    return _links.open(url);
  }

  @override
  void dispose() {
    _installs.removeListener(notifyListeners);
    super.dispose();
  }
}
