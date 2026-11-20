import 'package:flutter/foundation.dart';

import 'package:provider/single_child_widget.dart';

/// Where the start of the app stands.
sealed class StartState {
  const StartState();
}

/// The dependencies are still being built: the splash shows.
final class StartPending extends StartState {
  const StartPending();
}

/// The dependencies are built: the app runs over [providers].
final class StartReady extends StartState {
  const StartReady(this.providers);

  final List<SingleChildWidget> providers;
}

/// A start step threw: the app cannot run, and says so instead of keeping
/// the splash for ever.
final class StartFailed extends StartState {
  const StartFailed();
}

/// Follows the building of the app's dependencies from the splash to the app
/// or to the failed start. The failure is reported once, as a Flutter error.
final class AppStartViewModel extends ChangeNotifier {
  AppStartViewModel(Future<List<SingleChildWidget>> dependencies) {
    dependencies.then(_ready, onError: _failed);
  }

  StartState _state = const StartPending();
  bool _disposed = false;

  StartState get state => _state;

  void _ready(List<SingleChildWidget> providers) =>
      _settle(StartReady(providers));

  void _failed(Object error, StackTrace stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack, library: 'start'),
    );
    _settle(const StartFailed());
  }

  void _settle(StartState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
