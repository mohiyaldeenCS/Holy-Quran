import 'dart:async';

import 'package:holyquran/data/repositories/keep_awake_repository.dart';

/// One reader's claim on the screen staying on while it is shown (`RD-16`).
/// Readers stacked over each other share the repository's single reader
/// flag, so it is on while any reader holds it and off when the last lets
/// go, whichever order a route change gives the two.
final class ReaderKeepAwake {
  ReaderKeepAwake(this._repository);

  static final Expando<int> _holders = Expando();

  final KeepAwakeRepository? _repository;
  bool _holding = false;

  /// This reader is shown ([shown]) or no longer is.
  void shown(bool shown) {
    final repository = _repository;
    if (repository == null || shown == _holding) return;
    _holding = shown;
    final holders = (_holders[repository] ?? 0) + (shown ? 1 : -1);
    _holders[repository] = holders;
    // A failed wakelock changes nothing the reader can do about it.
    unawaited(repository.setReaderActive(holders > 0));
  }
}
