import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/listening_position_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/data/repositories/recitation_repository.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/listening_position.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/playback_plan.dart';
import 'package:holyquran/domain/models/playback_plan_builder.dart';
import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/playback_segment.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/ui/features/home/view_models/pack_ayah.dart';

/// Where «أكمل القراءة» leads: the last ayah read, its surah's name from
/// the pack, and its place in the mushaf.
final class ContinueReading {
  const ContinueReading({
    required this.address,
    required this.surahName,
    required this.page,
    required this.juz,
    required this.progress,
  });

  final QuranAddress address;
  final PackText surahName;
  final int page;
  final int juz;

  /// The page over the edition's page count.
  final double progress;
}

/// Where «أكمل الاستماع» leads: the ayah where listening stopped, its
/// surah's name from the pack, and the reciter.
final class ContinueListening {
  const ContinueListening({
    required this.surahName,
    required this.ayah,
    required this.reciter,
  });

  final PackText surahName;
  final int ayah;
  final String reciter;
}

/// The home screen's state (PRD §7.1, M1.2). A repository is absent while
/// the app has no base pack or no user database. A pack that fails stops
/// serving its surah names, which [integrity] announces (PRD §9.5).
final class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    this._positions,
    this._index,
    this._integrity,
    this._listening,
    this._recitations,
    this._player,
    this._plans,
    this._basePackId,
  }) {
    _changes.addListener(notifyListeners);
  }

  final ReadingPositionRepository? _positions;
  final QuranIndexRepository? _index;
  final PackIntegrityRepository? _integrity;
  final ListeningPositionRepository? _listening;
  final RecitationRepository? _recitations;
  final PlayerRepository? _player;
  final PlaybackPlanBuilder? _plans;

  /// The id of the base pack the app bundles; null when it bundles none.
  final String? _basePackId;
  late final Listenable _changes = Listenable.merge([
    _positions,
    _integrity,
    _listening,
    _recitations,
  ]);

  /// Whether the base pack failed its check and so serves no text (PRD
  /// §9.5): home then says so.
  bool get baseFailed {
    final id = _basePackId;
    return id != null && _integrity?.stateOf(id) is IntegrityFailed;
  }

  /// The continue-reading card, or null when there is no position yet, no
  /// verified pack serving its surah names, or the position is not an ayah
  /// of that pack.
  ContinueReading? get continueReading {
    final address = _positions?.last;
    final index = _index;
    if (address == null || index == null || !isAyahOfPack(index, address)) {
      return null;
    }
    final surahs = index.surahs;
    final position = index.positionOf(address);
    return ContinueReading(
      address: position.address,
      surahName: surahs[address.surah - 1].name,
      page: position.page,
      juz: position.juz,
      progress: position.page / index.count(Division.page),
    );
  }

  /// The continue-listening row, or null when nothing can be resumed: no
  /// position, no player, no pack serving the surah's name, or a recitation
  /// the catalogue does not list.
  ContinueListening? get continueListening {
    final target = _listeningTarget;
    final index = _index;
    if (target == null || index == null) return null;
    final (:position, :recitation) = target;
    return ContinueListening(
      surahName: index.surahs[position.address.surah - 1].name,
      ayah: position.address.ayah,
      reciter: recitation.reciter,
    );
  }

  ({ListeningPosition position, Recitation recitation})? get _listeningTarget {
    final position = _listening?.last;
    final index = _index;
    if (position == null ||
        index == null ||
        _player == null ||
        _plans == null ||
        !isAyahOfPack(index, position.address)) {
      return null;
    }
    final listed = _recitations?.recitations
        .where((entry) => entry.id == position.recitationId)
        .firstOrNull;
    final recitation = listed?.recitation;
    if (recitation == null ||
        !recitation.rightsComplete ||
        recitation.riwaya != index.riwaya) {
      return null;
    }
    return (position: position, recitation: recitation);
  }

  /// Plays from where listening stopped, to the end of the mushaf, with the
  /// recitation it stopped in. A failure of the player is reported, as the
  /// player screens report theirs.
  Future<void> resumeListening() async {
    final target = _listeningTarget;
    final player = _player;
    if (target == null || player == null) return;
    final (:position, :recitation) = target;
    try {
      final plan = _planFrom(recitation, position.address);
      if (plan == null) return;
      await player.play(plan, startAt: _firstHeard(plan));
      if (position.offset > Duration.zero) await player.seek(position.offset);
    } on Exception catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'continue listening',
        ),
      );
    }
  }

  // A recitation served by whole surahs, without timing data, cannot start
  // inside a surah: it plays the surah, whose segment names the surah's
  // first ayah.
  PlaybackPlan? _planFrom(Recitation recitation, QuranAddress address) {
    final plans = _plans!;
    var outcome = plans.build(
      recitation,
      FromAyahTool(address, AyahToolEnd.untilStopped),
    );
    if (outcome case PlanRefused(reason: PlanRefusal.needsAyahTiming)) {
      outcome = plans.build(recitation, WholeSurah(address.surah));
    }
    return switch (outcome) {
      PlanReady(:final plan) => plan,
      PlanRefused() => null,
    };
  }

  // The plan may open with an isti'adha and a basmala before the ayah, which
  // the saved offset is not measured in.
  int _firstHeard(PlaybackPlan plan) => plan.segments
      .takeWhile(
        (segment) =>
            segment.kind == SegmentKind.istiadha ||
            segment.kind == SegmentKind.basmala,
      )
      .length;

  @override
  void dispose() {
    _changes.removeListener(notifyListeners);
    super.dispose();
  }
}
