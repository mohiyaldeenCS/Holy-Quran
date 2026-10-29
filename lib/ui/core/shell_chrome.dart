import 'package:flutter/foundation.dart';

/// Whether the shell shows its tab bar and its mini player. A screen hides
/// the tab bar for the reader's distraction-free mode and the simple level,
/// and shows it again on leaving that state. The reader hides the mini
/// player while it draws its own player bar.
final class ShellChrome extends ChangeNotifier {
  bool _tabBarVisible = true;
  bool _miniPlayerVisible = true;

  bool get tabBarVisible => _tabBarVisible;

  set tabBarVisible(bool value) {
    if (value == _tabBarVisible) return;
    _tabBarVisible = value;
    notifyListeners();
  }

  bool get miniPlayerVisible => _miniPlayerVisible;

  set miniPlayerVisible(bool value) {
    if (value == _miniPlayerVisible) return;
    _miniPlayerVisible = value;
    notifyListeners();
  }
}
