import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/route_table.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/l10n/speed_label.dart';
import 'package:holyquran/ui/core/metrics/player_metrics.dart';
import 'package:holyquran/ui/core/mini_player_source.dart';
import 'package:holyquran/ui/core/widgets/mini_player.dart';
import 'package:holyquran/ui/features/listen/view_models/player_view_model.dart';
import 'package:holyquran/ui/features/listen/views/listen_screen.dart';

/// The mini player over the app's player, for the tab shell (`AU-05`).
/// It shows while a recitation plays or is paused (PRD §8.21, the
/// acceptance criterion of `LV`); with no player, nothing.
MiniPlayerSource? createListenMiniPlayer(BuildContext context) =>
    switch (createPlayerViewModel(context)) {
      final viewModel? => _ListenMiniPlayer(viewModel),
      null => null,
    };

final class _ListenMiniPlayer implements MiniPlayerSource {
  _ListenMiniPlayer(this._player);

  final PlayerViewModel _player;

  @override
  void addListener(VoidCallback listener) => _player.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _player.removeListener(listener);

  @override
  void dispose() => _player.dispose();

  @override
  Widget? build(BuildContext context) {
    final player = _player;
    final surah = player.surah;
    final ayah = player.ayah;
    // MiniPlayer's title always names an ayah, which a plan of whole surahs
    // without timing data does not know.
    if (!player.active || surah == null || ayah == null) return null;
    final router = GoRouter.of(context);
    return Padding(
      padding: PlayerMetrics.miniPlayerPadding,
      child: MiniPlayer(
        surah: surah.name,
        ayah: ayah,
        reciter: player.reciter,
        speed: speedLabel(AppLocalizations.of(context), player.speed),
        playing: player.playing,
        progress: player.progress,
        repeat: player.repeatCount ?? 0,
        onRepeat: () => context.push(Routes.repeatSheet),
        onPrevious: player.previousAyah,
        onPlayPause: player.playPause,
        onNext: player.nextAyah,
        showSleepTimer: hasRoute(router, Routes.sleepSheet),
        onSleepTimer: () => context.push(Routes.sleepSheet),
      ),
    );
  }
}
