import 'package:flutter/foundation.dart';

/// Whether the shell shows its tab bar. A screen hides it for the reader's
/// distraction-free mode and the simple level, and shows it again on leaving
/// that state.
final class ShellChrome extends ChangeNotifier {
  bool _tabBarVisible = true;

  bool get tabBarVisible => _tabBarVisible;

  set tabBarVisible(bool value) {
    if (value == _tabBarVisible) return;
    _tabBarVisible = value;
    notifyListeners();
  }
}
