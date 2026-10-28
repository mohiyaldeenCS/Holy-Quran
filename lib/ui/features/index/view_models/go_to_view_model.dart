import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/domain/models/go_to_error.dart';
import 'package:holyquran/domain/models/go_to_target.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/use_cases/parse_go_to.dart';
import 'package:holyquran/utils/result.dart';

/// The six places the go-to sheet offers (`NV-03`), in the PRD's order. A
/// surah and an ayah of a surah are two targets that share one parser.
enum GoToChoice {
  surah(GoToKind.surah),
  ayah(GoToKind.surah),
  page(GoToKind.page),
  juz(GoToKind.juz),
  hizb(GoToKind.hizb),
  rub(GoToKind.rub);

  const GoToChoice(this.kind);

  final GoToKind kind;

  /// Whether the target is an ayah of the surah, which asks for two numbers.
  bool get asksAyah => this == ayah;
}

/// The go-to sheet's state (`NV-03`): the target chosen and why the last
/// input was refused. Parsing and checking against the edition are
/// `parseGoTo`'s.
final class GoToViewModel extends ChangeNotifier {
  GoToViewModel({required this._index});

  final QuranIndexRepository _index;

  GoToChoice _choice = GoToChoice.surah;
  GoToError? _error;

  GoToChoice get choice => _choice;

  /// Why the last input was refused, until the input or the target changes.
  GoToError? get error => _error;

  void select(GoToChoice choice) {
    if (choice == _choice) return;
    _choice = choice;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  /// The name of [surah] in the pack, or null when it has none.
  PackText? surahName(int surah) {
    final surahs = _index.surahs;
    return surah >= 1 && surah <= surahs.length ? surahs[surah - 1].name : null;
  }

  /// The place [number] (and [ayah], for an ayah target) names, or null with
  /// [error] set when the input is refused. Both may be typed in any of the
  /// digit systems.
  GoToTarget? submit(String number, {String ayah = ''}) {
    final result = _choice.asksAyah && ayah.trim().isEmpty
        ? const Failure<GoToTarget>(UnreadableGoTo())
        : parseGoTo(
            _index,
            _choice.kind,
            number,
            ayah: _choice.asksAyah ? ayah : '',
          );
    switch (result) {
      case Ok(:final value):
        _error = null;
        return value;
      case Failure(:final error):
        _error = error is GoToError ? error : const UnreadableGoTo();
        notifyListeners();
        return null;
    }
  }
}
