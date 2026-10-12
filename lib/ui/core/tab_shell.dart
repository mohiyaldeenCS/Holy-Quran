import 'package:flutter/material.dart' hide TabBar;
import 'package:go_router/go_router.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/metrics/player_metrics.dart';
import 'package:holyquran/ui/core/shell_chrome.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/mini_player.dart';
import 'package:holyquran/ui/core/widgets/tab_bar.dart';
import 'package:holyquran/ui/features/listen/view_models/player_view_model.dart';
import 'package:holyquran/ui/features/listen/views/listen_screen.dart';
import 'package:provider/provider.dart';

/// Hosts the five tab branches under the identity's [TabBar], which the
/// [ShellChrome] above it may hide. Tapping the current tab returns its
/// branch to the branch's first screen. Above the tab bar, the [MiniPlayer]
/// shows while a recitation plays or is paused, except on the listen tab,
/// whose screen is the full player.
class TabShell extends StatefulWidget {
  const TabShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  State<TabShell> createState() => _TabShellState();
}

class _TabShellState extends State<TabShell> {
  PlayerViewModel? _player;

  StatefulNavigationShell get _shell => widget.navigationShell;

  @override
  void initState() {
    super.initState();
    _player = createPlayerViewModel(context);
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  void _onSelected(int index) =>
      _shell.goBranch(index, initialLocation: index == _shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final player = _player;
    if (player == null) return _scaffold(context, null);
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) => _scaffold(context, player),
    );
  }

  Widget _scaffold(BuildContext context, PlayerViewModel? player) {
    final l10n = AppLocalizations.of(context);
    final tabBarVisible = context.select<ShellChrome, bool>(
      (chrome) => chrome.tabBarVisible,
    );
    final mini = _shell.currentIndex == ShellTab.listen.index || player == null
        ? null
        : _miniPlayer(context, player);
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

/// The mini player while a recitation plays or is paused (PRD §8.21, the
/// acceptance criterion of `LV`); null otherwise.
Widget? _miniPlayer(BuildContext context, PlayerViewModel player) {
  final surah = player.surah;
  final ayah = player.ayah;
  // MiniPlayer's title always names an ayah, which a plan of whole surahs
  // without timing data does not know.
  if (!player.active || surah == null || ayah == null) return null;
  return Padding(
    // The boards draw no mini player over the tab bar; the gaps are the
    // spacing scale's.
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.space4,
      AppSpacing.space2,
      AppSpacing.space4,
      AppSpacing.space2,
    ),
    child: MiniPlayer(
      surah: surah.name,
      ayah: ayah,
      reciter: player.reciter,
      speed: playerSpeedLabel(player.speed),
      playing: player.playing,
      progress: player.progress ?? 0,
      repeat: player.repeatCount ?? 0,
      onRepeat: () => context.push(Routes.repeatSheet),
      onPrevious: player.previousAyah,
      onPlayPause: player.playPause,
      onNext: player.nextAyah,
      onSleepTimer: () => context.push(Routes.sleepSheet),
    ),
  );
}
