import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/playback_plan.dart';
import 'package:holyquran/domain/models/playback_plan_builder.dart';
import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/quran_address.dart';

import 'current_plan.dart';

/// Play from the ayah tools (`AU-03`): from [address] to the end of the
/// ayah, page, surah or juz, or until stopped. It plays with the recitation,
/// repeat and silence of the last plan; before any plan it offers nothing.
final class PlayOptionsViewModel extends ChangeNotifier with PlaysOnce {
  PlayOptionsViewModel({
    required this.address,
    required this._player,
    required this._builder,
    required this._index,
  });

  final QuranAddress address;
  final PlayerRepository _player;
  final PlaybackPlanBuilder _builder;
  final QuranIndexRepository _index;

  /// The name of [address]'s surah, or null while the pack lists no names.
  PackText? get surahName => _index.surahs
      .where((info) => info.number == address.surah)
      .firstOrNull
      ?.name;

  /// The ends the recitation can play, in the order of `AU-03`; a
  /// recitation served by surah files without timing data plays whole
  /// surahs only (D-112).
  List<AyahToolEnd> get options => [
    for (final until in AyahToolEnd.values)
      if (_outcome(until) is PlanReady) until,
  ];

  /// Plays from [address] to [until]; false when it cannot.
  Future<bool> play(AyahToolEnd until) => playOnce(() async {
    if (_outcome(until) case PlanReady(:final plan)) {
      await _player.play(plan);
      return true;
    }
    return false;
  });

  PlanOutcome? _outcome(AyahToolEnd until) => switch (_player.state.plan) {
    final plan? when _inEdition => rebuildPlan(
      _builder,
      plan,
      range: FromAyahTool(address.ayahAddress, until),
    ),
    _ => null,
  };

  bool get _inEdition =>
      address.riwaya == _index.riwaya &&
      address.surah <= _index.surahCount &&
      address.ayah <= _index.ayahCount(address.surah);
}
