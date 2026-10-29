import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/domain/models/playback_plan.dart';
import 'package:holyquran/domain/models/playback_segment.dart';
import 'package:holyquran/domain/models/player_state.dart';
import 'package:holyquran/domain/models/quran_address.dart';

/// Asks the reader to bring [address] into view. A new object for each ask,
/// so that the reader tells an ask it has met from one it has not.
final class FollowRequest {
  FollowRequest(this.address);

  final QuranAddress address;
}

/// The reader's view of the recitation (`SY-01`, `SY-03`, `SY-05`, D-112):
/// the ayah being recited, whether the reader follows it, and the asks to
/// scroll to it.
///
/// The recited ayah is the one the playing plan has reached, announced with
/// the segment of that ayah. A plan of whole surahs without timing data has
/// no ayah events, so it recites none here (its ayah timing waits for
/// registry row 6). Nothing is recited once playback stops. Pausing keeps the
/// ayah, and so does a change of speed, which changes no ayah.
///
/// The reader follows from the start of each recitation: a plan that reaches
/// another ayah than the one heard when it replaced the last, or any plan
/// after playback stopped. A plan rebuilt at the ayah being heard, as the
/// repeat and silence sheets do, goes on as it was: a reader the user
/// scrolled away from stays away. Until the new plan reaches its first ayah
/// none is recited. A reader opened while a recitation is already running
/// does not follow it: it opened on its own position, and [showReturn]
/// offers the way to the recitation. A scroll the user makes
/// ([userScrolled]) stops following until [resume]. In stand mode the reader
/// follows whatever the user does (`SY-05`).
///
/// It also gives the floating player bar what it draws (Screens board): the
/// address of the segment being heard, its reciter, and the actions on the
/// player.
final class RecitationFollow extends ChangeNotifier {
  RecitationFollow(this._player) {
    final player = _player;
    if (player == null) return;
    final state = player.state;
    _plan = state.plan;
    _recited = _heard(state, ayahOnly: true);
    _heardNow = _heard(state);
    _following = !_running(state);
    _playing = state.playing;
    player.addListener(_onPlayer);
  }

  final PlayerRepository? _player;
  PlaybackPlan? _plan;

  // The segment the player still holds from the plan before, which says
  // nothing of the new plan until the player gives another.
  PlaybackSegment? _stale;
  QuranAddress? _recited;
  QuranAddress? _heardNow;
  bool _following = true;

  // A plan replaced the one being heard: the ayah heard before, until the new
  // plan announces its first, which says whether it goes on from there.
  QuranAddress? _carryFrom;
  bool _stand = false;
  bool _playing = false;
  FollowRequest? _request;

  /// The ayah being recited, or null when the plan reached none, stopped, or
  /// has no ayah events.
  QuranAddress? get recited => _recited;

  /// The ayah the segment being heard belongs to, a basmala's included, or
  /// null while there is none: the player bar names it.
  QuranAddress? get heard => _heardNow;

  /// The reciter of the plan being played.
  String? get reciter => _plan?.recitation.reciter;

  /// Whether the reader scrolls to each ayah as it is recited.
  bool get following => _following || _stand;

  /// The last ask to scroll; null before the first.
  FollowRequest? get request => _request;

  /// Whether a recitation is sounding, for the screen to stay on (`RD-16`).
  bool get playing => _playing;

  /// Whether «عُد إلى موضع التلاوة» is offered: a recitation is running and
  /// the reader no longer follows it.
  bool get showReturn => _recited != null && !following;

  /// Stand mode keeps the reader on the recitation (`SY-05`).
  set stand(bool value) {
    if (value == _stand) return;
    _stand = value;
    if (value) _ask();
    notifyListeners();
  }

  /// The user scrolled the text: following stops while a recitation runs.
  void userScrolled() {
    if (_stand || _recited == null || !_following) return;
    _following = false;
    notifyListeners();
  }

  /// Follows again and scrolls to the ayah being recited.
  void resume() {
    _following = true;
    _ask();
    notifyListeners();
  }

  /// Pauses the recitation, or goes on with it.
  Future<void> playPause() => _run(_playing ? _player!.pause : _player!.resume);

  Future<void> nextAyah() => _run(_player!.nextAyah);

  // The bar's buttons fire without awaiting; a failure is reported.
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on Exception catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack, library: 'player'),
      );
    }
  }

  void _ask() {
    if (_recited case final ayah?) _request = FollowRequest(ayah);
  }

  void _onPlayer() {
    final state = _player!.state;
    final before = (_recited, _heardNow, _plan, _following, _playing);
    if (!identical(state.plan, _plan)) {
      // The segment the player holds is the old plan's; after a stop the
      // plan was forgotten and the segment noted then still is.
      _stale = _plan == null ? _stale : state.segment;
      _carryFrom = _heardNow;
      _plan = state.plan;
      _recited = null;
      if (_carryFrom == null) _following = true;
    } else if (!identical(state.segment, _stale)) {
      _stale = null;
    }
    final plan = state.plan;
    if (plan == null || state.stopReason != null || !plan.hasAyahBoundaries) {
      _recited = null;
      _following = true;
      _carryFrom = null;
      if (plan != null && state.stopReason != null) {
        // A plan played again after it stopped is a new run.
        _plan = null;
        _stale = state.segment;
      }
    } else if (_heard(state, ayahOnly: true) case final ayah?) {
      if (_carryFrom != null && ayah != _carryFrom) _following = true;
      _carryFrom = null;
      if (ayah != _recited) {
        _recited = ayah;
        if (_following) _ask();
      }
    }
    _heardNow = _heard(state) ?? (_carryFrom != null ? _heardNow : null);
    _playing = state.playing;
    if (before != (_recited, _heardNow, _plan, _following, _playing)) {
      notifyListeners();
    }
  }

  // Whether the player holds a recitation with ayah events that has not
  // stopped; a basmala before the first ayah counts.
  bool _running(PlayerState state) =>
      (state.plan?.hasAyahBoundaries ?? false) && state.stopReason == null;

  // The ayah of the segment being heard, once the plan has one of its own. A
  // basmala or an isti'adha names the ayah it comes before, which is not
  // heard yet, so only with [ayahOnly] false does it count.
  QuranAddress? _heard(PlayerState state, {bool ayahOnly = false}) {
    final plan = state.plan;
    final segment = state.segment;
    if (plan == null ||
        !plan.hasAyahBoundaries ||
        state.stopReason != null ||
        segment == null ||
        (ayahOnly && segment.kind != SegmentKind.ayah) ||
        identical(segment, _stale)) {
      return null;
    }
    return segment.address.ayahAddress;
  }

  @override
  void dispose() {
    _player?.removeListener(_onPlayer);
    super.dispose();
  }
}
