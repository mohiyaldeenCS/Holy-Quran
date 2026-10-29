import 'dart:async';

import 'package:holyquran/data/repositories/keep_awake_repository.dart';

/// One reader's two claims on the screen staying on: while it is shown
/// (`RD-16`), and while it is in stand mode (`SY-05`). Each claim has its own
/// flag in the repository, and readers stacked over each other share it, so
/// it is on while any reader holds it and off when the last lets go,
/// whichever order a route change gives the two.
final class ReaderKeepAwake {
  ReaderKeepAwake(this._repository);

  static final Expando<int> _readers = Expando();
  static final Expando<int> _stands = Expando();

  final KeepAwakeRepository? _repository;
  bool _shown = false;
  bool _standing = false;

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

  /// This reader is in stand mode ([standing]) or no longer is.
  void standing(bool standing) {
    if (standing == _standing) return;
    _standing = standing;
    _hold(
      _stands,
      standing,
      (repository, active) => repository.setStandActive(active),
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
