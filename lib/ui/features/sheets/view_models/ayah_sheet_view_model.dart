import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/note_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/repositories/tafsir_repository.dart';
import 'package:holyquran/domain/models/note.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/features/sheets/view_models/ayah_tafsir.dart';
import 'package:holyquran/utils/result.dart';

/// The mini ayah sheet's state (`ST-01`): the ayah from the base pack, its
/// tafsir, the user's notes on it and the way to play from it. A section
/// whose data is not there is not offered: [tafsir] is shown only while one
/// is installed, [notesAvailable] says whether notes can be read, and
/// [canPlay] whether the player holds a plan to play the ayah with.
///
/// The ayah is read as the model is made. A change in the pack's integrity
/// is heard, and the sheet closes when the pack no longer serves the ayah.
/// The notes are read again whenever they change, so that a note saved in
/// the note sheet appears here when it closes.
final class AyahSheetViewModel extends ChangeNotifier {
  AyahSheetViewModel({
    required QuranAddress address,
    required this._text,
    required TafsirRepository? tafsirs,
    required this._notes,
    required this._player,
    this._integrity,
  }) : address = address.ayahAddress,
       tafsir = AyahTafsir(ayah: address.ayahAddress, tafsirs: tafsirs) {
    _integrity?.addListener(_onIntegrity);
    _notes?.addListener(_onNotes);
    _player?.addListener(notifyListeners);
    tafsir.addListener(notifyListeners);
    unawaited(tafsir.load());
    unawaited(_load());
    unawaited(_loadNotes());
  }

  /// The ayah the sheet was opened for.
  final QuranAddress address;
  final QuranTextRepository _text;
  final NoteRepository? _notes;
  final PlayerRepository? _player;
  final PackIntegrityRepository? _integrity;

  /// The tafsir section's passage.
  final AyahTafsir tafsir;

  PackText? _ayahText;
  PackText? _surahName;
  List<Note> _noteList = const [];
  bool _loaded = false;
  bool _failed = false;
  int _loads = 0;
  int _noteLoads = 0;
  bool _disposed = false;

  /// False until the ayah has been read.
  bool get loaded => _loaded;

  /// Whether the pack does not serve the ayah; the sheet then closes.
  bool get unavailable => _failed;

  PackText? get ayahText => _ayahText;

  /// The name of the ayah's surah in the pack.
  PackText? get surahName => _surahName;

  /// Whether the user's notes can be read, and so added to.
  bool get notesAvailable => _notes != null;

  /// The notes on the ayah, older first; none while unread or unreadable.
  List<Note> get notes => _noteList;

  /// Whether the player holds a plan, which the play options need to play
  /// from the ayah with the recitation, repeat and silence in use.
  bool get canPlay => _player?.state.plan != null;

  void _onIntegrity() => unawaited(_load());

  void _onNotes() => unawaited(_loadNotes());

  Future<void> _load() async {
    final load = ++_loads;
    final text = await _text.ayahText(address);
    final surahs = await _text.surahs();
    if (load != _loads || _disposed) return;
    switch ((text, surahs)) {
      case (Ok(value: final text), Ok(value: final surahs)):
        _ayahText = text;
        _surahName = surahs
            .where((surah) => surah.number == address.surah)
            .map((surah) => surah.name)
            .firstOrNull;
        _failed = false;
      default:
        _ayahText = null;
        _surahName = null;
        _failed = true;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _loadNotes() async {
    final notes = _notes;
    if (notes == null) return;
    final load = ++_noteLoads;
    final result = await notes.notesAt(address);
    if (load != _noteLoads || _disposed) return;
    _noteList = switch (result) {
      Ok(:final value) => value,
      Failure() => const [],
    };
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _integrity?.removeListener(_onIntegrity);
    _notes?.removeListener(_onNotes);
    _player?.removeListener(notifyListeners);
    tafsir
      ..removeListener(notifyListeners)
      ..dispose();
    super.dispose();
  }
}
