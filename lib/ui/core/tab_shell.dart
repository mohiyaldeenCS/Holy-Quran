import 'package:flutter/material.dart' hide TabBar;
import 'package:go_router/go_router.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/mini_player_source.dart';
import 'package:holyquran/ui/core/shell_chrome.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/tab_bar.dart';
import 'package:provider/provider.dart';

/// Hosts the five tab branches under the identity's [TabBar], which the
/// [ShellChrome] above it may hide. Tapping the current tab returns its
/// branch to the branch's first screen. Above the tab bar, the mini player
/// of [miniPlayer] shows while a recitation plays or is paused, except on
/// the listen tab, whose screen is the full player, and while the
/// [ShellChrome] hides it for a reader that draws its own player bar.
class TabShell extends StatefulWidget {
  const TabShell({required this.navigationShell, this.miniPlayer, super.key});

  final StatefulNavigationShell navigationShell;
  final MiniPlayerSourceFactory? miniPlayer;

  @override
  State<TabShell> createState() => _TabShellState();
}

class _TabShellState extends State<TabShell> {
  MiniPlayerSource? _mini;

  StatefulNavigationShell get _shell => widget.navigationShell;

  @override
  void initState() {
    super.initState();
    _mini = widget.miniPlayer?.call(context);
  }

  @override
  void dispose() {
    _mini?.dispose();
    super.dispose();
  }

  void _onSelected(int index) =>
      _shell.goBranch(index, initialLocation: index == _shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final mini = _mini;
    if (mini == null) return _scaffold(context, null);
    return ListenableBuilder(
      listenable: mini,
      builder: (context, _) => _scaffold(context, mini),
    );
  }

  Widget _scaffold(BuildContext context, MiniPlayerSource? source) {
    final l10n = AppLocalizations.of(context);
    final tabBarVisible = context.select<ShellChrome, bool>(
      (chrome) => chrome.tabBarVisible,
    );
    final miniVisible = context.select<ShellChrome, bool>(
      (chrome) => chrome.miniPlayerVisible,
    );
    final mini =
        _shell.currentIndex == ShellTab.listen.index ||
            !miniVisible ||
            source == null
        ? null
        : source.build(context);
    return Scaffold(
      body: _shell,
      // Null when both are hidden: a bottom bar, even an empty one, takes
      // the bottom inset from the body.
      bottomNavigationBar: mini == null && !tabBarVisible
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (mini != null)
                  SafeArea(top: false, bottom: !tabBarVisible, child: mini),
                if (tabBarVisible)
                  TabBar(
                    items: [
                      TabBarItem(IconName.home, l10n.tabHome),
                      TabBarItem(IconName.mushaf, l10n.tabMushaf),
                      TabBarItem(IconName.listen, l10n.tabListen),
                      TabBarItem(IconName.study, l10n.tabStudy),
                      TabBarItem(IconName.more, l10n.tabMore),
                    ],
                    currentIndex: _shell.currentIndex,
                    onSelected: _onSelected,
                    semanticLabel: l10n.mainNavigationLabel,
                  ),
              ],
            ),
    );
  }
}
