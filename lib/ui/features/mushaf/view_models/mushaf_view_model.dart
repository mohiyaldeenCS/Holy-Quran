import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_position.dart';
import 'package:holyquran/ui/core/reader/reader_anchors.dart';
import 'package:holyquran/ui/core/reader/surah_text.dart';
import 'package:holyquran/ui/features/mushaf/view_models/reader_surah.dart';
import 'package:holyquran/utils/command.dart';
import 'package:holyquran/utils/result.dart';

enum ReaderStatus { loading, ready, unavailable }

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
/// opened, or only shown again, never overwrites the position.
final class MushafViewModel extends ChangeNotifier {
  MushafViewModel({
    this._text,
    this._index,
    this._positions,
    this._integrity,
    this._address,
  }) {
    _integrity?.addListener(_onIntegrity);
  }

  final QuranTextRepository? _text;
  final QuranIndexRepository? _index;
  final ReadingPositionRepository? _positions;
  final PackIntegrityRepository? _integrity;
  QuranAddress? _address;
  bool _moved = false;
  EditionMap? _map;
  bool _disposed = false;

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

  /// Whether everything but the text is hidden (`RD-09`).
  bool get distractionFree => _distractionFree;

  void setDistractionFree(bool value) {
    if (value == _distractionFree) return;
    _distractionFree = value;
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
    final index = _index;
    if (_text == null || index == null || index.surahs.isEmpty) {
      return _unavailable();
    }
    final target = _target(index);
    final surah = await _readSurah(target.surah);
    if (_disposed) return const Ok(null);
    if (index.surahs.isEmpty) return _unavailable();
    switch (surah) {
      case Ok(:final value):
        _surahs = List.unmodifiable([value]);
        _anchor = QuranAddress(target.riwaya, target.surah, target.ayah);
        _status = ReaderStatus.ready;
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
    final next = index.nextSurah(_surahs.last.info.number);
    if (next == null) return const Ok(null);
    final surah = await _readSurah(next);
    if (_disposed || _status != ReaderStatus.ready) return const Ok(null);
    if (index.surahs.isEmpty) return _unavailable();
    switch (surah) {
      case Ok(:final value):
        _surahs = List.unmodifiable([..._surahs, value]);
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

  /// The reader is no longer shown: the user's position is saved, and the
  /// reader opens there when shown again. One that was only opened leaves
  /// the saved position as it is.
  Future<void> leave() async {
    if (!_moved) return;
    _moved = false;
    _address = _position?.address ?? _address;
    await _save();
  }

  Future<void> _save() async {
    if (_position case final position?) {
      await _positions?.save(position.address);
    }
  }

  QuranAddress _target(QuranIndexRepository index) {
    for (final candidate in [_address, _positions?.last]) {
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
    _status = ReaderStatus.unavailable;
    notifyListeners();
    return Failure(error);
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
    _integrity?.removeListener(_onIntegrity);
    open.dispose();
    loadNext.dispose();
    super.dispose();
  }
}

final class _ReadFailed implements Exception {
  const _ReadFailed(this.error);

  final Exception error;
}
