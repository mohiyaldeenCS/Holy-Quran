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
}
