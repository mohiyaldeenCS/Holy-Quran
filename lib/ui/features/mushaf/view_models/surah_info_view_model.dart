import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/domain/models/surah_info.dart';

/// The facts of one surah for «مقدمة السورة» (`RD-17`, Phase 1: the basic
/// facts the pack gives). It has none while the app has no base pack, the
/// pack stops serving (PRD §9.5), or the surah is not in it.
final class SurahInfoViewModel extends ChangeNotifier {
  SurahInfoViewModel({required this.surah, this._index, this._integrity}) {
    _integrity?.addListener(notifyListeners);
  }

  final int surah;
  final QuranIndexRepository? _index;
  final PackIntegrityRepository? _integrity;

  SurahInfo? get info {
    final surahs = _index?.surahs ?? const <SurahInfo>[];
    return surah <= surahs.length ? surahs[surah - 1] : null;
  }

  @override
  void dispose() {
    _integrity?.removeListener(notifyListeners);
    super.dispose();
  }
}
