import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/services/link_service.dart';
import 'package:holyquran/domain/models/source_credit.dart';
import 'package:holyquran/utils/result.dart';

/// The sources and licences screen (PRD §7.1): the sources of the installed
/// packs, and opening a source's link.
final class SourcesViewModel extends ChangeNotifier {
  SourcesViewModel({required this._installs, required this._links}) {
    _installs.addListener(notifyListeners);
  }

  final PackInstallRepository _installs;
  final LinkService _links;
  bool _disposed = false;

  List<SourceCredit> get sources => sourcesOf(_installs.installed);

  /// True when the last link opened could not be; cleared by the next one.
  bool linkFailed = false;

  Future<void> open(SourceCredit source) async {
    final url = Uri.tryParse(source.url);
    final result = url == null
        ? Failure<void>(LinkNotOpened(Uri()))
        : await _links.open(url);
    linkFailed = result is Failure;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _installs.removeListener(notifyListeners);
    super.dispose();
  }
}
