import 'package:flutter/foundation.dart';

/// Whether the shell shows its tab bar and its mini player. A screen hides
/// the tab bar for the reader's distraction-free mode and the simple level,
/// and shows it again on leaving that state. The reader hides the mini
/// player while it draws its own player bar.
///
/// Each part is hidden while any holder asks, so screens stacked over each
/// other, as readers can be, do not give it back while one still hides it.
/// The setters are one holder of their own.
final class ShellChrome extends ChangeNotifier {
  final Set<Object> _tabBarHolders = {};
  final Set<Object> _miniPlayerHolders = {};

  bool get tabBarVisible => _tabBarHolders.isEmpty;

  set tabBarVisible(bool value) => holdTabBarHidden(this, !value);

  /// [holder] hides the tab bar, or no longer does.
  void holdTabBarHidden(Object holder, bool hidden) =>
      _hold(_tabBarHolders, holder, hidden);

  bool get miniPlayerVisible => _miniPlayerHolders.isEmpty;

  set miniPlayerVisible(bool value) => holdMiniPlayerHidden(this, !value);

  /// [holder] hides the mini player, or no longer does.
  void holdMiniPlayerHidden(Object holder, bool hidden) =>
      _hold(_miniPlayerHolders, holder, hidden);

  void _hold(Set<Object> holders, Object holder, bool hold) {
    final visible = holders.isEmpty;
    if (hold) {
      holders.add(holder);
    } else {
      holders.remove(holder);
    }
    if (visible != holders.isEmpty) notifyListeners();
  }
}
