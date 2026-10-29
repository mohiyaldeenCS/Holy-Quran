import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/ui/core/shell_chrome.dart';

void main() {
  test('shows the tab bar at first', () {
    final chrome = ShellChrome();
    addTearDown(chrome.dispose);

    expect(chrome.tabBarVisible, isTrue);
  });

  test('notifies when the tab bar is hidden and shown again', () {
    final chrome = ShellChrome();
    addTearDown(chrome.dispose);
    final seen = <bool>[];
    chrome.addListener(() => seen.add(chrome.tabBarVisible));

    chrome.tabBarVisible = false;
    chrome.tabBarVisible = true;

    expect(seen, [false, true]);
  });

  test('does not notify when nothing changes', () {
    final chrome = ShellChrome();
    addTearDown(chrome.dispose);
    var notified = 0;
    chrome.addListener(() => notified++);

    chrome.tabBarVisible = true;

    expect(notified, 0);
  });

  group('holders', () {
    test('the tab bar stays hidden until the last holder lets go', () {
      final chrome = ShellChrome();
      addTearDown(chrome.dispose);
      final seen = <bool>[];
      chrome.addListener(() => seen.add(chrome.tabBarVisible));
      final first = Object();
      final second = Object();

      chrome.holdTabBarHidden(first, true);
      chrome.holdTabBarHidden(second, true);
      chrome.holdTabBarHidden(first, false);
      expect(chrome.tabBarVisible, isFalse);
      chrome.holdTabBarHidden(second, false);

      expect(chrome.tabBarVisible, isTrue);
      expect(seen, [false, true]);
    });

    test('the mini player stays hidden until the last holder lets go', () {
      final chrome = ShellChrome();
      addTearDown(chrome.dispose);
      final first = Object();
      final second = Object();

      chrome.holdMiniPlayerHidden(first, true);
      chrome.holdMiniPlayerHidden(second, true);
      chrome.holdMiniPlayerHidden(second, false);
      expect(chrome.miniPlayerVisible, isFalse);
      chrome.holdMiniPlayerHidden(first, false);

      expect(chrome.miniPlayerVisible, isTrue);
    });

    test('a holder that lets go twice counts once', () {
      final chrome = ShellChrome();
      addTearDown(chrome.dispose);
      final holder = Object();

      chrome.holdMiniPlayerHidden(holder, true);
      chrome.holdMiniPlayerHidden(holder, true);
      chrome.holdMiniPlayerHidden(holder, false);

      expect(chrome.miniPlayerVisible, isTrue);
    });
  });
}
