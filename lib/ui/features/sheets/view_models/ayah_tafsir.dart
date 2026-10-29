import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/tafsir_repository.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/tafsir/read_tafsir_page.dart';
import 'package:holyquran/ui/core/tafsir/tafsir_page.dart';
import 'package:holyquran/utils/result.dart';

/// The shown tafsir's passage for one ayah, for the sheets that carry it
/// beside other things (`TF-02`, `LX-01`, `ST-01`): the default book, or the
/// first installed one while none is chosen. [available] says whether any
/// tafsir is installed; nothing is read until [load] is called, so that a
/// sheet whose tab is not opened does not pay for the pack's first check.
/// Once loaded it is read again when the installed books or the default
/// change.
final class AyahTafsir extends ChangeNotifier {
  AyahTafsir({required this._ayah, required this._tafsirs}) {
    _tafsirs?.addListener(_onChanged);
  }

  final QuranAddress _ayah;
  final TafsirRepository? _tafsirs;

  bool _requested = false;
  bool _loaded = false;
  bool _disposed = false;
  int _loads = 0;
  TafsirPage? _page;
  Object? _failure;

  /// Whether any tafsir is installed.
  bool get available => _tafsirs?.installed.isNotEmpty ?? false;

  /// False until the first read has ended.
  bool get loaded => _loaded;

  /// The shown book's reading of the ayah; null while unread, or when the
  /// book could not be read ([failure]).
  TafsirPage? get page => _page;

  /// Why the book could not be read: a pack that failed its checks, for
  /// example. Null when it was read, or when there is nothing to read.
  Object? get failure => _failure;

  /// Starts the first read; later calls do nothing.
  Future<void> load() {
    if (_requested) return Future.value();
    _requested = true;
    return _read();
  }

  void _onChanged() {
    if (_requested) {
      unawaited(_read());
    } else {
      notifyListeners();
    }
  }

  Future<void> _read() async {
    final load = ++_loads;
    final tafsirs = _tafsirs;
    final packId = tafsirs == null ? null : shownTafsirPack(tafsirs);
    TafsirPage? page;
    Object? failure;
    if (tafsirs != null && packId != null) {
      try {
        switch (await readTafsirPage(tafsirs, packId, _ayah)) {
          case Ok(:final value):
            page = value;
          case Failure(:final error):
            failure = error;
        }
      } on Exception catch (error) {
        failure = error;
      }
    }
    // A newer read started, or the sheet closed, meanwhile.
    if (load != _loads || _disposed) return;
    _page = page;
    _failure = failure;
    _loaded = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _tafsirs?.removeListener(_onChanged);
    super.dispose();
  }
}
