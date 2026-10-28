import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/sources_repository.dart';
import 'package:holyquran/domain/models/source_credit.dart';
import 'package:holyquran/utils/result.dart';

/// The sources and licences screen (PRD §7.1): the sources of the packs, the
/// licence texts of the fonts, and opening a source's link. It owns
/// [_repository] and disposes it.
final class SourcesViewModel extends ChangeNotifier {
  SourcesViewModel({required this._repository}) {
    _repository.addListener(notifyListeners);
    _readFontLicences();
  }

  final SourcesRepository _repository;
  List<String> _fontLicences = const [];
  bool _linkFailed = false;
  bool _disposed = false;

  List<SourceCredit> get sources => _repository.sources;

  /// The OFL text of each font family; empty until read, or if unreadable.
  List<String> get fontLicences => _fontLicences;

  /// True when the last link opened could not be; cleared by the next one.
  bool get linkFailed => _linkFailed;

  Future<void> _readFontLicences() async {
    final result = await _repository.fontLicences();
    if (_disposed || result is! Ok<List<String>>) return;
    _fontLicences = result.value;
    notifyListeners();
  }

  Future<void> open(SourceCredit source) async {
    _linkFailed = await _repository.openLink(source) is Failure;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _repository.removeListener(notifyListeners);
    _repository.dispose();
    super.dispose();
  }
}
