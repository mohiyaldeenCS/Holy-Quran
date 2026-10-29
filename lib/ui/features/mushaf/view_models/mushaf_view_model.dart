import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/bookmark_repository.dart';
import 'package:holyquran/data/repositories/category_repository.dart';
import 'package:holyquran/data/repositories/keep_awake_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/level_policy.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_position.dart';
import 'package:holyquran/domain/models/ui_level.dart';
import 'package:holyquran/ui/core/reader/gesture_target.dart';
import 'package:holyquran/ui/core/reader/reader_anchors.dart';
import 'package:holyquran/ui/core/reader/reader_text_scale.dart';
import 'package:holyquran/ui/core/reader/surah_text.dart';
import 'package:holyquran/ui/features/mushaf/view_models/reader_bookmarks.dart';
import 'package:holyquran/ui/features/mushaf/view_models/reader_keep_awake.dart';
import 'package:holyquran/ui/features/mushaf/view_models/reader_surah.dart';
import 'package:holyquran/ui/features/mushaf/view_models/recitation_follow.dart';
import 'package:holyquran/utils/command.dart';
import 'package:holyquran/utils/result.dart';

enum ReaderStatus { loading, ready, unavailable }

/// Which of the selected ayah's tools can work in this app: each needs
/// objects that only a verified pack, or the player, provides. A tool that
/// cannot work is not offered (D-138, 3).
final class AyahTools {
  const AyahTools({this.play = false, this.copy = false, this.share = false});

  static const none = AyahTools();

  final bool play;
  final bool copy;
  final bool share;
}

/// The reader cannot show text: the app has no verified base pack, or it
/// stopped serving.
final class ReaderUnavailable implements Exception {
  const ReaderUnavailable();
}

/// The surah-mode reader's state (`RD-02`, PRD §7.2): the surahs read so far
/// from the base pack, the address to open at, and the first visible ayah
/// with its place in the mushaf. The layout itself is the view's. While the
/// pack fails its check, no text is held (PRD §9.5).
///
/// It opens at the address of its route, else at the last reading position,
/// else at the first ayah. The first visible ayah is saved when a scroll the
/// user made ends and when the reader is left (`RD-12`, D-106); a reader only
/// opened, or only shown again, never overwrites the position. Shown again,
/// it keeps what it has when no other reader saved a position meanwhile, and
/// else reopens at the saved position (a reader opened over this one moves
/// the position on).
///
/// It also holds what the reader's gestures change: the selected ayah and its
/// tools (PRD §7.4), the text size step (`RD-07`), the distraction-free state
/// (`RD-09`), the bookmarks the margin shows (`UD-05`), the recitation it
/// follows (`SY-01`, `SY-03`, `SY-05`) and the screen kept on (`RD-16`).
final class MushafViewModel extends ChangeNotifier {
  MushafViewModel({
    this._text,
    this._index,
    this._positions,
    this._integrity,
    this._address,
    AppSettingsRepository? settings,
    BookmarkRepository? bookmarks,
    CategoryRepository? categories,
    KeepAwakeRepository? keepAwake,
    PlayerRepository? player,
    this.tools = AyahTools.none,
  }) : _settings = settings,
       _keepAwake = ReaderKeepAwake(keepAwake),
       bookmarks = ReaderBookmarks(
         bookmarks: bookmarks,
         categories: categories,
       ),
       follow = RecitationFollow(player),
       _textStep = _stepOf(settings) {
    _integrity?.addListener(_onIntegrity);
    _positions?.addListener(_onPositions);
    _settings?.addListener(_onSettings);
    this.bookmarks.addListener(notifyListeners);
    follow.addListener(_onFollow);
    unawaited(this.bookmarks.load());
  }

  static int _stepOf(AppSettingsRepository? settings) => settings == null
      ? defaultReaderTextStep
      : nearestReaderTextStep(settings.surahTextScale);

  final AppSettingsRepository? _settings;
  final ReaderKeepAwake _keepAwake;

  /// The selected ayah's tools that can work.
  final AyahTools tools;

  /// The bookmarks of the ayat the reader shows.
  final ReaderBookmarks bookmarks;

  /// The recitation the reader follows.
  final RecitationFollow follow;

  final QuranTextRepository? _text;
  final QuranIndexRepository? _index;
  final ReadingPositionRepository? _positions;
  final PackIntegrityRepository? _integrity;
  final QuranAddress? _address;
  bool _moved = false;
  EditionMap? _map;
  bool _disposed = false;
  bool _opened = false;
  bool _shown = false;
  bool _changedWhileOpening = false;

  /// The saved position this reader knows of: the one it found when it
  /// opened or the one it saved itself. Another reader's save differs.
  QuranAddress? _seen;

  /// Reads the surah to open at and shows it.
  late final Command0<void> open = Command0(_open);

  /// Appends the surah after the last one shown, if there is one.
  late final Command0<void> loadNext = Command0(_loadNext);

  ReaderStatus _status = ReaderStatus.loading;
  List<ReaderSurah> _surahs = const [];
  QuranAddress? _anchor;
  QuranPosition? _position;
  PackText? _positionSurahName;
  bool _distractionFree = false;
  bool _standMode = false;
  QuranAddress? _selected;
  int _textStep;
  int _writes = 0;

  ReaderStatus get status => _status;

  /// The surahs shown, consecutive from the one opened; replaced, never
  /// changed, so that the identity says whether they did.
  List<ReaderSurah> get surahs => _surahs;

  /// The ayah the last [open] scrolls to; a new object with each open.
  QuranAddress? get anchor => _anchor;

  /// The first visible ayah's place in the edition.
  QuranPosition? get position => _position;

  /// The name of the surah the first visible ayah is in.
  PackText? get positionSurahName => _positionSurahName;

  /// Whether everything but the text is hidden (`RD-09`); stand mode hides
  /// it whatever a tap says.
  bool get distractionFree => _distractionFree || _standMode;

  /// Whether the reader is on a stand (`SY-05`): the interface hidden, the
  /// recitation followed on its own, the screen kept on.
  bool get standMode => _standMode;

  void setStandMode(bool value) {
    if (value == _standMode) return;
    _standMode = value;
    follow.stand = value;
    notifyListeners();
  }

  void setDistractionFree(bool value) {
    if (value == _distractionFree) return;
    _distractionFree = value;
    notifyListeners();
  }

  /// The ayah a long press or a tap on its marker chose, or null.
  QuranAddress? get selectedAyah => _selected;

  /// The index into `readerTextSteps` the text is set at (`RD-07`).
  int get textStep => _textStep;

  /// Sets the text size step; the new size is kept as the setting, which
  /// every other reader follows.
  void setTextStep(int step) {
    if (step == _textStep) return;
    _textStep = step;
    notifyListeners();
    if (_settings != null) {
      _writes++;
      unawaited(
        _settings
            .setSurahTextScale(readerTextSteps[step])
            .whenComplete(() => _writes--),
      );
    }
  }

  // The size another reader chose. This reader's own writes are not heard:
  // it already shows what it wrote, and one still on its way is older.
  void _onSettings() {
    final settings = _settings;
    if (settings == null || _writes > 0 || _disposed) return;
    final step = nearestReaderTextStep(settings.surahTextScale);
    if (step == _textStep) return;
    _textStep = step;
    notifyListeners();
  }

  /// A tap on [target] (PRD §7.4). A tap on a marker selects its ayah; any
  /// other tap first dismisses a selection. Otherwise a word opens its sheet
  /// where the level shows one and [wordSheet] says it exists, and shows or
  /// hides everything but the text everywhere else. Returns the word whose
  /// sheet to open, if any.
  QuranAddress? tap(GestureTarget target, {required bool wordSheet}) {
    switch (target) {
      case MarkerTarget(:final ayah):
        select(ayah);
      case _ when _selected != null:
        clearSelection();
      case WordTarget(:final word):
        if (wordSheet && LevelPolicy.shows(LevelTool.wordSheet, _level)) {
          return word;
        }
        setDistractionFree(!_distractionFree);
      case MarginTarget():
        setDistractionFree(!_distractionFree);
      case WaqfMarkTarget():
        break;
    }
    return null;
  }

  /// A long press on [target] selects the ayah it is in.
  void longPress(GestureTarget target) {
    switch (target) {
      case WordTarget(:final word):
        select(word);
      case WaqfMarkTarget(:final ayah) || MarkerTarget(:final ayah):
        select(ayah);
      case MarginTarget():
        break;
    }
  }

  UiLevel get _level => _settings?.level ?? UiLevel.initial;

  void select(QuranAddress address) {
    final ayah = address.ayahAddress;
    if (ayah == _selected) return;
    _selected = ayah;
    bookmarks.leave();
    notifyListeners();
  }

  void clearSelection() {
    if (_selected == null) return;
    _selected = null;
    bookmarks.leave();
    notifyListeners();
  }

  /// The first visible ayah is now [address]; the position bar follows. A
  /// [byUser] scroll makes the position worth saving.
  void showFirstVisible(QuranAddress address, {bool byUser = false}) {
    if (byUser) _moved = true;
    final index = _index;
    if (index == null || _status != ReaderStatus.ready) return;
    final names = index.surahs;
    if (names.isEmpty) return;
    final position = index.positionOf(address);
    if (position == _position) return;
    _position = position;
    _positionSurahName = names[address.surah - 1].name;
    notifyListeners();
  }

  Future<Result<void>> _open() async {
    Result<void> result;
    do {
      _changedWhileOpening = false;
      result = await _openOnce();
    } while (_changedWhileOpening && !_disposed && result is Ok<void>);
    return result;
  }

  Future<Result<void>> _openOnce() async {
    final index = _index;
    if (_text == null || index == null || index.surahs.isEmpty) {
      return _unavailable();
    }
    _shown = true;
    _keepAwake.shown(true);
    _syncReciting();
    final elsewhere = _savedElsewhere;
    final target = _target(index, elsewhere);
    final kept =
        _opened &&
        !elsewhere &&
        _status == ReaderStatus.ready &&
        _surahs.any((surah) => surah.info.number == target.surah);
    _seen = _positions?.last;
    if (kept) return const Ok(null);
    _opened = true;
    final surah = await _readSurah(target.surah);
    if (_disposed) return const Ok(null);
    if (index.surahs.isEmpty) return _unavailable();
    switch (surah) {
      case Ok(:final value):
        _surahs = List.unmodifiable([value]);
        _anchor = QuranAddress(target.riwaya, target.surah, target.ayah);
        _status = ReaderStatus.ready;
        _syncReciting();
        _position = null;
        showFirstVisible(target);
        notifyListeners();
        return const Ok(null);
      case Failure(:final error):
        return _unavailable(error);
    }
  }

  Future<Result<void>> _loadNext() async {
    final index = _index;
    if (_status != ReaderStatus.ready || index == null) return const Ok(null);
    final shown = _surahs;
    final next = index.nextSurah(shown.last.info.number);
    if (next == null) return const Ok(null);
    final surah = await _readSurah(next);
    if (_disposed || _status != ReaderStatus.ready) return const Ok(null);
    if (index.surahs.isEmpty) return _unavailable();
    // An open that ran meanwhile replaced the surahs; the next one of the old
    // list does not belong to the new one.
    if (!identical(shown, _surahs)) return const Ok(null);
    switch (surah) {
      case Ok(:final value):
        _surahs = List.unmodifiable([...shown, value]);
        notifyListeners();
        return const Ok(null);
      case Failure(:final error):
        return _unavailable(error);
    }
  }

  /// Saves the first visible ayah, after the user scrolled.
  Future<void> saveFirstVisible() async {
    if (_moved) await _save();
  }

  /// The reader is no longer shown: the user's position is saved. One that
  /// was only opened leaves the saved position as it is.
  Future<void> leave() async {
    _shown = false;
    _keepAwake.shown(false);
    _syncReciting();
    if (!_moved) return;
    _moved = false;
    await _save();
  }

  Future<void> _save() async {
    if (_position case final position?) {
      _seen = position.address;
      await _positions?.save(position.address);
    }
  }

  /// Another reader saved a position since this one last knew of it.
  bool get _savedElsewhere {
    final last = _positions?.last;
    return _opened && last != null && last != _seen;
  }

  // A reader opened over this one saved a position that this one, shown again
  // too early, did not see (the save may complete after the route is gone).
  void _onPositions() {
    if (!_shown || _disposed || !_savedElsewhere) return;
    if (open.running) {
      _changedWhileOpening = true;
    } else {
      unawaited(open.execute());
    }
  }

  QuranAddress _target(QuranIndexRepository index, bool elsewhere) {
    final last = _positions?.last;
    final candidates = !_opened
        ? [_address, last]
        : elsewhere
        ? [last, _position?.address, _address]
        : [_position?.address, _address, last];
    for (final candidate in candidates) {
      if (candidate != null && _inEdition(index, candidate)) {
        return candidate.ayahAddress;
      }
    }
    return QuranAddress(index.riwaya, 1, 1);
  }

  bool _inEdition(QuranIndexRepository index, QuranAddress address) =>
      address.riwaya == index.riwaya &&
      address.surah <= index.surahCount &&
      address.ayah <= index.ayahCount(address.surah);

  Future<Result<ReaderSurah>> _readSurah(int number) async {
    final text = _text!;
    final names = _index!.surahs;
    if (names.isEmpty) return const Failure(ReaderUnavailable());
    final info = names[number - 1];
    try {
      final EditionMap map = _map ?? _value(await text.editionMap());
      _map = map;
      final basmala = _value(await text.basmala(number));
      final ayat = <AyahText>[];
      for (var ayah = 1; ayah <= info.ayahCount; ayah++) {
        final address = QuranAddress(text.riwaya, number, ayah);
        ayat.add(
          AyahText(
            text: _value(await text.ayahText(address)),
            words: _value(await text.words(address)),
            marks: _value(await text.marks(address)),
          ),
        );
      }
      return Ok(
        ReaderSurah(
          info: info,
          text: SurahText(
            riwaya: text.riwaya,
            surah: number,
            ayat: ayat,
            basmala: basmala,
            pageStarts: pageStartsIn(map, text.riwaya, number),
            marginMarks: marginMarksIn(map, text.riwaya, number),
          ),
        ),
      );
    } on _ReadFailed catch (failed) {
      return Failure(failed.error);
    }
  }

  T _value<T>(Result<T> result) => switch (result) {
    Ok(:final value) => value,
    Failure(:final error) => throw _ReadFailed(error),
  };

  Result<void> _unavailable([Exception error = const ReaderUnavailable()]) {
    _surahs = const [];
    _anchor = null;
    _position = null;
    _positionSurahName = null;
    _selected = null;
    _status = ReaderStatus.unavailable;
    _keepAwake.shown(false);
    _syncReciting();
    notifyListeners();
    return Failure(error);
  }

  // The screen stays on while a recitation sounds under a reader that shows
  // text (`RD-16`).
  void _syncReciting() => _keepAwake.reciting(
    _shown && _status != ReaderStatus.unavailable && follow.playing,
  );

  void _onFollow() {
    _syncReciting();
    notifyListeners();
  }

  void _onIntegrity() {
    if (_status != ReaderStatus.unavailable &&
        (_index?.surahs.isEmpty ?? true)) {
      _unavailable();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _keepAwake.shown(false);
    _keepAwake.reciting(false);
    follow
      ..removeListener(_onFollow)
      ..dispose();
    bookmarks.dispose();
    _integrity?.removeListener(_onIntegrity);
    _positions?.removeListener(_onPositions);
    _settings?.removeListener(_onSettings);
    open.dispose();
    loadNext.dispose();
    super.dispose();
  }
}

final class _ReadFailed implements Exception {
  const _ReadFailed(this.error);

  final Exception error;
}
