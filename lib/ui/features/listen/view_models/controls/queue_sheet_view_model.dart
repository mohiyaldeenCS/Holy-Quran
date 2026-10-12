import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/playback_plan.dart';

/// The queue (`AU-17`, «قائمة التشغيل» by D-127): the plans waiting after
/// the current one, reordered and removed in the player.
final class QueueSheetViewModel extends ChangeNotifier {
  QueueSheetViewModel({required this._player, required this._index}) {
    _player.addListener(notifyListeners);
  }

  final PlayerRepository _player;
  final QuranIndexRepository _index;

  List<PlaybackPlan> get queue => _player.state.queue;

  /// The name of [surah], or null while the pack lists no names.
  PackText? surahName(int surah) =>
      _index.surahs.where((info) => info.number == surah).firstOrNull?.name;

  /// Moves the plan at [from] so that it ends at [to].
  void move(int from, int to) {
    if (from != to) _player.moveInQueue(from, to);
  }

  void remove(int index) => _player.removeFromQueue(index);

  @override
  void dispose() {
    _player.removeListener(notifyListeners);
    super.dispose();
  }
}
