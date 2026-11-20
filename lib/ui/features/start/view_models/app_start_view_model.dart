import 'package:flutter/foundation.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/start_failure.dart';
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
/// the splash for ever, in the user's [theme] when the settings were read
/// before that step and in the default theme when they were not.
final class StartFailed extends StartState {
  const StartFailed({this.theme = const ThemePreference()});

  final ThemePreference theme;
}

/// Follows the building of the app's dependencies from the splash to the app
/// or to the failed start. The failure is reported once, as a Flutter error:
/// a [StartFailure]'s cause, not the failure itself.
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
    final failure = error is StartFailure ? error : null;
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: failure?.cause ?? error,
        stack: stack,
        library: 'start',
      ),
    );
    final theme = failure?.theme;
    _settle(theme == null ? const StartFailed() : StartFailed(theme: theme));
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
