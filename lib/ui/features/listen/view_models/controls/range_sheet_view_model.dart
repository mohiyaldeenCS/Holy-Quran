import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/playback_plan.dart';
import 'package:holyquran/domain/models/playback_plan_builder.dart';
import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/quran_address.dart';

import 'current_plan.dart';

/// What the range picker plays: the kinds of PRD §7.7, «محدد النطاق», and
/// the surah of `AU-02`.
enum RangeKind { ayah, page, juz, hizb, surah }

/// The range picker (`AU-02`): an ayah of the surah being heard, a page, a
/// juz, a hizb or a surah, each starting where playback was when it opened.
/// It plays the range with the recitation, repeat and silence of the plan
/// playing then, so it offers nothing before any plan.
final class RangeSheetViewModel extends ChangeNotifier with PlaysOnce {
  RangeSheetViewModel({
    required this._player,
    required this._builder,
    required this._index,
  }) {
    final plan = _player.state.plan;
    if (plan == null) return;
    // Surah files without timing data play whole surahs only (D-112).
    _kinds = plan.hasAyahBoundaries
        ? RangeKind.values
        : const [RangeKind.surah];
    _kind = _kinds.first;
    final at = heardIn(_player.state) ?? _builder.ayatOf(plan.range).first;
    _surah = at.surah;
    _values = {
      RangeKind.ayah: at.ayah,
      RangeKind.page: _index.numberAt(Division.page, at),
      RangeKind.juz: _index.numberAt(Division.juz, at),
      RangeKind.hizb: _index.numberAt(Division.hizb, at),
      RangeKind.surah: at.surah,
    };
  }

  final PlayerRepository _player;
  final PlaybackPlanBuilder _builder;
  final QuranIndexRepository _index;
  List<RangeKind> _kinds = const [];
  int _surah = 1;
  Map<RangeKind, int> _values = const {};
  RangeKind _kind = RangeKind.ayah;

  /// The kinds the recitation can play; none before any plan.
  List<RangeKind> get kinds => _kinds;

  RangeKind get kind => _kind;

  int get value => _values[_kind]!;

  int get min => 1;

  int get max => switch (_kind) {
    RangeKind.ayah => _index.ayahCount(_surah),
    RangeKind.page => _index.count(Division.page),
    RangeKind.juz => _index.count(Division.juz),
    RangeKind.hizb => _index.count(Division.hizb),
    RangeKind.surah => _index.surahCount,
  };

  /// The surah of the ayah or surah picked; null for the other kinds and
  /// while the pack lists no names.
  PackText? get surahName => switch (_kind) {
    RangeKind.ayah => _nameOf(_surah),
    RangeKind.surah => _nameOf(value),
    _ => null,
  };

  PlaybackRange get range => switch (_kind) {
    RangeKind.ayah => SingleAyah(QuranAddress(_index.riwaya, _surah, value)),
    RangeKind.page => PageSpan(value),
    RangeKind.juz => WholeJuz(value),
    RangeKind.hizb => WholeHizb(value),
    RangeKind.surah => WholeSurah(value),
  };

  void selectKind(RangeKind kind) {
    if (kind == _kind || !_kinds.contains(kind)) return;
    _kind = kind;
    notifyListeners();
  }

  void setValue(int value) {
    final next = value.clamp(min, max);
    if (next == this.value) return;
    _values = {..._values, _kind: next};
    notifyListeners();
  }

  /// Plays [range] in place of what is playing, with its recitation; a
  /// surah goes on into the next ones when the plan playing did (`AU-04`).
  /// False when nothing has played or the recitation cannot play the range.
  Future<bool> play() => playOnce(() async {
    final plan = _player.state.plan;
    if (plan == null || _kinds.isEmpty) return false;
    if (rebuildPlan(_builder, plan, range: range) case PlanReady(:final plan)) {
      await _player.play(plan);
      return true;
    }
    return false;
  });

  PackText? _nameOf(int surah) =>
      _index.surahs.where((info) => info.number == surah).firstOrNull?.name;
}
