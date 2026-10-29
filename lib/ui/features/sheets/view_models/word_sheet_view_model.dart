import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/repositories/tafsir_repository.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/word_span.dart';
import 'package:holyquran/ui/core/widgets/word_sheet.dart';
import 'package:holyquran/ui/features/sheets/view_models/ayah_tafsir.dart';
import 'package:holyquran/utils/result.dart';

/// The word sheet's state (`LX-01`, `LX-11`): the word of [address], its
/// place in its ayah, and the tabs whose packs are installed. The text tab
/// is always there, since the base pack holds the word; the tafsir tab is
/// there while a tafsir is installed. No other tab is offered, as no other
/// pack is built yet.
///
/// The word is not read as a string: the sheet gets the ayah's pack text and
/// the word's stored offsets, and draws the slice between them. The ayah is
/// read as the model is made. A change in the pack's integrity is heard, and
/// the sheet closes when the pack no longer serves the word.
final class WordSheetViewModel extends ChangeNotifier {
  WordSheetViewModel({
    required this.address,
    required this._text,
    required TafsirRepository? tafsirs,
    this._integrity,
  }) : assert(address.isWord),
       tafsir = AyahTafsir(ayah: address.ayahAddress, tafsirs: tafsirs) {
    _integrity?.addListener(_onIntegrity);
    tafsir.addListener(notifyListeners);
    unawaited(_load());
  }

  /// The word the sheet was opened for.
  final QuranAddress address;
  final QuranTextRepository _text;
  final PackIntegrityRepository? _integrity;

  /// The tafsir tab's passage, read when the tab is first selected.
  final AyahTafsir tafsir;

  WordSheetTab _selected = WordSheetTab.text;
  PackText? _ayahText;
  List<WordSpan> _spans = const [];
  bool _loaded = false;
  bool _failed = false;
  int _loads = 0;
  bool _disposed = false;

  /// False until the ayah has been read.
  bool get loaded => _loaded;

  /// Whether the sheet cannot be shown: the pack does not serve the ayah, or
  /// the ayah has no such word. The sheet then closes.
  bool get unavailable => _failed;

  /// The whole ayah, as the pack stores it; only the word's slice is drawn.
  PackText? get ayahText => _ayahText;

  /// The stored offsets of the word in [ayahText].
  WordSpan? get span {
    for (final span in _spans) {
      if (span.number == address.word) return span;
    }
    return null;
  }

  /// How many words the ayah has.
  int get wordCount => _spans.length;

  /// The tabs to show, in the identity's order by the widget.
  Set<WordSheetTab> get tabs => {
    WordSheetTab.text,
    if (tafsir.available) WordSheetTab.tafsir,
  };

  /// The selected tab: the text tab again once the tafsir is removed.
  WordSheetTab get selectedTab =>
      tabs.contains(_selected) ? _selected : WordSheetTab.text;

  void select(WordSheetTab tab) {
    if (!tabs.contains(tab)) return;
    final changed = tab != selectedTab;
    _selected = tab;
    if (tab == WordSheetTab.tafsir) unawaited(tafsir.load());
    if (changed) notifyListeners();
  }

  void _onIntegrity() => unawaited(_load());

  Future<void> _load() async {
    final load = ++_loads;
    final ayah = address.ayahAddress;
    final text = await _text.ayahText(ayah);
    final words = await _text.words(ayah);
    if (load != _loads || _disposed) return;
    switch ((text, words)) {
      case (Ok(value: final text), Ok(value: final words)):
        _ayahText = text;
        _spans = words;
        _failed = span == null;
      default:
        _ayahText = null;
        _spans = const [];
        _failed = true;
    }
    _loaded = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _integrity?.removeListener(_onIntegrity);
    tafsir
      ..removeListener(notifyListeners)
      ..dispose();
    super.dispose();
  }
}
