import 'dart:async';

import 'package:holyquran/data/repositories/keep_awake_repository.dart';

/// One reader's two claims on the screen staying on (`RD-16`): while it is
/// shown, and while a recitation sounds under it. Each claim has its own flag
/// in the repository, and readers stacked over each other share it, so it is
/// on while any reader holds it and off when the last lets go, whichever
/// order a route change gives the two.
final class ReaderKeepAwake {
  ReaderKeepAwake(this._repository);

  static final Expando<int> _readers = Expando();
  static final Expando<int> _reciters = Expando();

  final KeepAwakeRepository? _repository;
  bool _shown = false;
  bool _reciting = false;

  /// This reader is shown ([shown]) or no longer is.
  void shown(bool shown) {
    if (shown == _shown) return;
    _shown = shown;
    _hold(
      _readers,
      shown,
      (repository, active) => repository.setReaderActive(active),
    );
  }

  /// A recitation sounds while this reader is shown ([reciting]) or no
  /// longer does.
  void reciting(bool reciting) {
    if (reciting == _reciting) return;
    _reciting = reciting;
    _hold(
      _reciters,
      reciting,
      (repository, active) => repository.setPlayerActive(active),
    );
  }

  void _hold(
    Expando<int> holders,
    bool hold,
    Future<Object?> Function(KeepAwakeRepository, bool) set,
  ) {
    final repository = _repository;
    if (repository == null) return;
    final count = (holders[repository] ?? 0) + (hold ? 1 : -1);
    holders[repository] = count;
    // A failed wakelock changes nothing the reader can do about it.
    unawaited(set(repository, count > 0));
  }
}
