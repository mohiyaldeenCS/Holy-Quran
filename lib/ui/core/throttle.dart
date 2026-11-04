import 'dart:async';

/// Runs [_action] when a screen's data changes, without running it at every
/// tick of a download: a change that only adds to what is shown waits for
/// the next run, which is at most [_every] later; a change of what is listed
/// runs it at once.
final class Throttle {
  Throttle(this._every, this._action);

  final Duration _every;
  final void Function() _action;
  Timer? _timer;

  /// Runs the action now and drops a run that was waiting.
  void now() {
    cancel();
    _action();
  }

  /// Runs the action once in [_every], unless a run is already waiting.
  void soon() {
    _timer ??= Timer(_every, () {
      _timer = null;
      _action();
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
