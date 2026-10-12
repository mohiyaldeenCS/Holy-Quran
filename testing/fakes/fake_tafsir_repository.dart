import 'package:flutter/foundation.dart';
import 'package:holyquran/data/repositories/tafsir_repository.dart';
import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/tafsir_book.dart';
import 'package:holyquran/domain/models/tafsir_position.dart';
import 'package:holyquran/utils/result.dart';

/// A [TafsirRepository] in memory, for view-model tests. A test sets
/// [installed], which notifies listeners, the [books] and the answer of
/// [positionAt]. As in the app, the default is null unless it is installed,
/// and a pack that is not installed fails with [TafsirNotInstalled].
final class FakeTafsirRepository extends ChangeNotifier
    implements TafsirRepository {
  FakeTafsirRepository({
    this._installed = const [],
    String? defaultTafsir,
    Map<String, TafsirBook> books = const {},
  }) : _default = defaultTafsir,
       books = {...books};

  List<InstalledPack> _installed;
  String? _default;
  final Map<String, TafsirBook> books;

  /// Answers [positionAt] for an installed pack; a test that reads a
  /// position sets it.
  Result<TafsirPosition> Function(String packId, QuranAddress ayah) positions =
      (_, _) => throw StateError('positions is not set');

  @override
  List<InstalledPack> get installed => _installed;

  set installed(List<InstalledPack> value) {
    _installed = value;
    notifyListeners();
  }

  bool _isInstalled(String? packId) =>
      _installed.any((pack) => pack.id == packId);

  @override
  String? get defaultTafsir => _isInstalled(_default) ? _default : null;

  @override
  Future<Result<void>> setDefaultTafsir(String packId) async {
    if (!_isInstalled(packId)) return Failure(TafsirNotInstalled(packId));
    _default = packId;
    notifyListeners();
    return const Ok(null);
  }

  @override
  Future<Result<TafsirBook>> book(String packId) async =>
      switch (books[packId]) {
        final book? when _isInstalled(packId) => Ok(book),
        _ => Failure(TafsirNotInstalled(packId)),
      };

  @override
  Future<Result<TafsirPosition>> positionAt(
    String packId,
    QuranAddress ayah,
  ) async => _isInstalled(packId)
      ? positions(packId, ayah)
      : Failure(TafsirNotInstalled(packId));
}
