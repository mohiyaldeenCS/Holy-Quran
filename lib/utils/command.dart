import 'package:flutter/foundation.dart';

import 'package:holyquran/utils/result.dart';

typedef CommandAction0<T> = Future<Result<T>> Function();
typedef CommandAction1<T, A> = Future<Result<T>> Function(A argument);

/// A user action of a view model, after
/// <https://docs.flutter.dev/app-architecture/design-patterns/command>: it
/// reports whether it is running and how its last run ended, and ignores a
/// new run while one is in progress.
sealed class Command<T> extends ChangeNotifier {
  Command();

  bool _running = false;
  Result<T>? _result;

  bool get running => _running;

  /// The outcome of the last finished run, or null before one or after
  /// [clearResult].
  Result<T>? get result => _result;

  bool get error => _result is Failure<T>;

  bool get completed => _result is Ok<T>;

  void clearResult() {
    _result = null;
    notifyListeners();
  }

  Future<void> _execute(CommandAction0<T> action) async {
    if (_running) return;
    _running = true;
    _result = null;
    notifyListeners();
    try {
      _result = await action();
    } finally {
      _running = false;
      notifyListeners();
    }
  }
}

final class Command0<T> extends Command<T> {
  Command0(this._action);

  final CommandAction0<T> _action;

  Future<void> execute() => _execute(_action);
}

final class Command1<T, A> extends Command<T> {
  Command1(this._action);

  final CommandAction1<T, A> _action;

  Future<void> execute(A argument) => _execute(() => _action(argument));
}
