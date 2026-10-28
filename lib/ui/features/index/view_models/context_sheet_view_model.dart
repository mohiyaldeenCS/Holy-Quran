import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/reader/surah_text.dart';
import 'package:holyquran/ui/core/widgets/context_sheet.dart';
import 'package:holyquran/utils/result.dart';

/// The ayah-context sheet's state (`NV-05`): how much context is chosen and
/// the ayat for it, read from the pack with their word and mark spans. The
/// ayat of one choice are read once; a later choice reads only what it adds.
/// The ayah alone is read as the model is made.
final class ContextSheetViewModel extends ChangeNotifier {
  ContextSheetViewModel({
    required QuranAddress address,
    required this._text,
    required this._index,
  }) : address = address.ayahAddress {
    unawaited(load());
  }

  /// How many ayat each choice shows, null for the whole surah, in the order
  /// the choices are offered (`NV-05`): the ayah, 3 ayat, 5 ayat, the surah.
  static const List<int?> choices = [1, 3, 5, null];

  /// Whether [address] is an ayah of the edition [index] describes and the
  /// pack serves the surah's name, which the sheet shows.
  static bool canShow(QuranIndexRepository index, QuranAddress address) =>
      address.riwaya == index.riwaya &&
      address.surah >= 1 &&
      address.surah <= index.surahs.length &&
      address.surah <= index.surahCount &&
      address.ayah >= 1 &&
      address.ayah <= index.ayahCount(address.surah);

  final QuranTextRepository _text;
  final QuranIndexRepository _index;

  /// The ayah the sheet was opened for.
  final QuranAddress address;

  int _amount = 0;
  ContextPassage? _passage;
  final _ayat = <int, AyahText>{};
  var _reads = 0;
  var _disposed = false;

  List<int?> get amounts => choices;

  /// The index in [amounts] of the choice made; the ayah alone at first.
  int get amount => _amount;

  /// The name of the ayah's surah in the pack, or null once the pack no
  /// longer serves it.
  PackText? get surahName {
    final surahs = _index.surahs;
    return address.surah <= surahs.length
        ? surahs[address.surah - 1].name
        : null;
  }

  /// The ayat of the choice made, or null until they are read, or when the
  /// pack cannot give them.
  ContextPassage? get passage => _passage;

  void select(int amount) {
    if (amount == _amount) return;
    _amount = amount;
    notifyListeners();
    unawaited(load());
  }

  /// Reads the ayat of the choice made. A choice made meanwhile wins.
  Future<void> load() async {
    final read = ++_reads;
    final (first, last) = _range();
    for (var ayah = first; ayah <= last; ayah++) {
      if (_ayat.containsKey(ayah)) continue;
      final text = await _read(ayah);
      if (_disposed || read != _reads) return;
      if (text == null) {
        _passage = null;
        notifyListeners();
        return;
      }
      _ayat[ayah] = text;
    }
    _passage = ContextPassage(
      riwaya: address.riwaya,
      surah: address.surah,
      firstAyah: first,
      ayat: [for (var ayah = first; ayah <= last; ayah++) _ayat[ayah]!],
      selectedAyah: address.ayah,
    );
    notifyListeners();
  }

  /// The ayat of the choice made: as many as it asks for, with as many before
  /// the ayah as after it, moved along the surah when it runs out of ayat on
  /// one side, so that the label stays true.
  (int, int) _range() {
    final count = _index.ayahCount(address.surah);
    final wanted = amounts[_amount] ?? count;
    final shown = wanted < count ? wanted : count;
    final before = (shown - 1) >> 1;
    var first = address.ayah - before;
    if (first < 1) first = 1;
    if (first + shown - 1 > count) first = count - shown + 1;
    return (first, first + shown - 1);
  }

  Future<AyahText?> _read(int ayah) async {
    final at = QuranAddress(address.riwaya, address.surah, ayah);
    final text = await _text.ayahText(at);
    final words = await _text.words(at);
    final marks = await _text.marks(at);
    return switch ((text, words, marks)) {
      (Ok(value: final text), Ok(value: final words), Ok(value: final marks)) =>
        AyahText(text: text, words: words, marks: marks),
      _ => null,
    };
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
