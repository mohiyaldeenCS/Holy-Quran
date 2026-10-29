import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/catalogue_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/repositories/tafsir_repository.dart';
import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/tafsir_book.dart';
import 'package:holyquran/domain/models/tafsir_position.dart';
import 'package:holyquran/ui/core/share/copy_sheet_view_model.dart';
import 'package:holyquran/ui/features/tafsir/tafsir_copy_text.dart';
import 'package:holyquran/ui/features/tafsir/tafsir_source.dart';
import 'package:holyquran/ui/features/tafsir/view_models/tafsir_page.dart';
import 'package:holyquran/utils/command.dart';
import 'package:holyquran/utils/result.dart';

/// The tafsir of one ayah at a time (`TF-01` to `TF-05`, `TF-10`), for the
/// reader and the sheet: the ayah, the chosen book's passage for it, the
/// steps to the ayat before and after, and the books to choose the default
/// from.
///
/// [tafsirs] is null while the app provides none; there are then no books.
/// The book shown is the default tafsir, or the first installed one while
/// none is chosen.
final class TafsirViewModel extends ChangeNotifier {
  TafsirViewModel({
    required QuranAddress address,
    required this._quran,
    required this._tafsirs,
    required this._catalogue,
    required this._copyText,
    required this._copyToClipboard,
    this._withPicker = false,
  }) : _address = address.ayahAddress,
       _shown = address.ayahAddress {
    _tafsirs?.addListener(_onChanged);
    _catalogue?.addListener(_onChanged);
    copy = Command0(_copy);
    unawaited(_load());
  }

  final QuranTextRepository _quran;
  final TafsirRepository? _tafsirs;
  final CatalogueRepository? _catalogue;
  final TafsirCopyText? _copyText;
  final CopyToClipboard? _copyToClipboard;

  /// Whether [downloaded] is read: only the reader lists the books.
  final bool _withPicker;

  late final Command0<void> copy;

  // The ayah asked for, and the one the state below describes.
  QuranAddress _address;
  QuranAddress _shown;
  int _loads = 0;
  bool _loaded = false;
  bool _disposed = false;
  bool _choiceNotSaved = false;
  PackText? _ayahText;
  PackText? _surahName;
  TafsirPage? _page;
  Object? _failure;
  List<TafsirChoice> _downloaded = const [];
  List<String> _available = const [];

  /// The ayah the text, the page and the steps are of.
  QuranAddress get address => _shown;

  /// False until the first read has ended.
  bool get loaded => _loaded;

  /// The ayah's text from the text pack; null while unread or unreadable.
  PackText? get ayahText => _ayahText;

  /// The ayah's surah name from the text pack.
  PackText? get surahName => _surahName;

  /// Whether any tafsir is downloaded.
  bool get hasTafsirs => _tafsirs?.installed.isNotEmpty ?? false;

  /// The chosen book's reading of [address]; null when no book is downloaded
  /// or the book could not be read ([failure]).
  TafsirPage? get page => _page;

  /// Why the chosen book could not be read: a pack that failed its checks,
  /// for example. Null when it was read, or when there is none to read.
  Object? get failure => _failure;

  /// The ayah the step back leads to; null at the first or without a page.
  QuranAddress? get previous => _page?.position.previous;

  /// The ayah the step forward leads to; null at the last or without a page.
  QuranAddress? get next => _page?.position.next;

  /// Whether the app can copy a passage: the book and the clipboard are
  /// provided.
  bool get canCopy => _copyText != null && _copyToClipboard != null;

  /// Whether the last choice of a default tafsir could not be saved.
  bool get choiceNotSaved => _choiceNotSaved;

  /// The downloaded books, in the installer's order (`TF-01`); read after the
  /// chosen book is shown, and only when the model was made with a picker.
  List<TafsirChoice> get downloaded => _downloaded;

  /// The titles of the tafsirs the catalogue offers that are not downloaded.
  List<String> get available => _available;

  Future<void> goTo(QuranAddress target) {
    _address = target.ayahAddress;
    return _load();
  }

  /// Makes [packId] the default tafsir; the reader then shows it. When it
  /// cannot be saved the previous choice stays and [choiceNotSaved] is set,
  /// until the next choice.
  Future<void> choose(String packId) async {
    final result = await _tafsirs?.setDefaultTafsir(packId);
    if (_disposed) return;
    _choiceNotSaved = result is Failure;
    if (_choiceNotSaved) notifyListeners();
  }

  void _onChanged() => unawaited(_load());

  String? get _shownPack {
    final tafsirs = _tafsirs;
    if (tafsirs == null) return null;
    return tafsirs.defaultTafsir ?? tafsirs.installed.firstOrNull?.id;
  }

  Future<void> _load() async {
    final load = ++_loads;
    final ayah = _address;
    final tafsirs = _tafsirs;
    final packId = _shownPack;
    final installed = tafsirs?.installed ?? const <InstalledPack>[];

    final text = await _quran.ayahText(ayah);
    final surahs = await _quran.surahs();
    TafsirPage? page;
    Object? failure;
    if (tafsirs != null && packId != null) {
      switch (await _read(tafsirs, packId, ayah)) {
        case Ok(:final value):
          page = value;
        case Failure(:final error):
          failure = error;
      }
    }
    // A newer read started, or the screen closed, meanwhile.
    if (load != _loads || _disposed) return;
    _shown = ayah;
    _ayahText = switch (text) {
      Ok(:final value) => value,
      Failure() => null,
    };
    _surahName = switch (surahs) {
      Ok(:final value) =>
        value
            .where((surah) => surah.number == ayah.surah)
            .map((surah) => surah.name)
            .firstOrNull,
      Failure() => null,
    };
    _page = page;
    _failure = failure;
    _available = _availableTitles(installed);
    _loaded = true;
    notifyListeners();
    if (!_withPicker || tafsirs == null) return;

    // The other books are checked after the chosen one is shown: the first
    // read of each runs its pack's full verification.
    final downloaded = <TafsirChoice>[];
    for (final pack in installed) {
      final chosen = pack.id == packId;
      final book = chosen && page != null
          ? Ok(page.book)
          : await tafsirs.book(pack.id);
      if (load != _loads || _disposed) return;
      downloaded.add(
        TafsirChoice(
          packId: pack.id,
          title: switch (book) {
            Ok(:final value) => value.title,
            Failure() => null,
          },
          chosen: chosen,
        ),
      );
    }
    _downloaded = downloaded;
    notifyListeners();
  }

  Future<Result<TafsirPage>> _read(
    TafsirRepository tafsirs,
    String packId,
    QuranAddress ayah,
  ) async {
    final TafsirPosition position;
    switch (await tafsirs.positionAt(packId, ayah)) {
      case Ok(:final value):
        position = value;
      case Failure(:final error):
        return Failure(error);
    }
    final TafsirBook book;
    switch (await tafsirs.book(packId)) {
      case Ok(:final value):
        book = value;
      case Failure(:final error):
        return Failure(error);
    }
    final pack = installedTafsirOf(tafsirs, packId);
    if (pack == null) return Failure(TafsirNotInstalled(packId));
    return Ok(
      TafsirPage(
        packId: packId,
        position: position,
        book: book,
        source: digitisationSourceOf(pack).name,
        version: pack.version,
      ),
    );
  }

  List<String> _availableTitles(List<InstalledPack> installed) {
    final offered = _catalogue?.catalogue?.offeredPacks ?? const [];
    final have = {for (final pack in installed) pack.id};
    return [
      for (final entry in offered)
        if (entry.kind == PackKind.tafsir && !have.contains(entry.id))
          entry.title,
    ];
  }

  Future<Result<void>> _copy() async {
    final page = _page;
    final copyText = _copyText;
    final clipboard = _copyToClipboard;
    if (page == null || copyText == null || clipboard == null) {
      return Failure(NoPassageToCopy(_shown));
    }
    return switch (await copyText.compose(page.packId, page.position.ayah)) {
      Ok(:final value) => clipboard(value),
      Failure(:final error) => Failure(error),
    };
  }

  /// A command still running when the screen closes notifies once more as
  /// it ends, so it is left to the collector rather than disposed.
  @override
  void dispose() {
    _disposed = true;
    _tafsirs?.removeListener(_onChanged);
    _catalogue?.removeListener(_onChanged);
    if (!copy.running) copy.dispose();
    super.dispose();
  }
}
