import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/sources_repository.dart';
import 'package:holyquran/domain/models/source_credit.dart';
import 'package:holyquran/utils/result.dart';

/// The sources and licences screen (PRD §7.1): the sources of the installed
/// packs, and opening a source's link.
final class SourcesViewModel extends ChangeNotifier {
  SourcesViewModel({required this._repository}) {
    _repository.addListener(notifyListeners);
  }

  final SourcesRepository _repository;
  bool _disposed = false;

  List<SourceCredit> get sources => _repository.sources;

  /// True when the last link opened could not be; cleared by the next one.
  bool linkFailed = false;

  Future<void> open(SourceCredit source) async {
    linkFailed = await _repository.openLink(source) is Failure;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _repository.removeListener(notifyListeners);
    super.dispose();
  }
}
