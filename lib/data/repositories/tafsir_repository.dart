import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../../domain/models/installed_pack.dart';
import '../../domain/models/pack_failure.dart';
import '../../domain/models/pack_integrity.dart';
import '../../domain/models/pack_manifest.dart';
import '../../domain/models/quran_address.dart';
import '../../domain/models/quran_structure.dart';
import '../../domain/models/tafsir_book.dart';
import '../../domain/models/tafsir_position.dart';
import '../../utils/result.dart';
import '../models/pack_manifest_json.dart';
import '../services/daos/settings_dao.dart';
import '../services/settings_store.dart';
import '../services/tafsir_pack_database.dart';
import 'pack_install_repository.dart';
import 'pack_integrity_repository.dart';
import 'pack_repository.dart';

/// The installed tafsir books (`TF-01` to `TF-05`). Listeners hear of every
/// change to [installed] and [defaultTafsir].
abstract interface class TafsirRepository implements Listenable {
  /// The installed tafsir packs, in the installer's order. The digitisation
  /// source and the version of the source badge (`TF-05`) are a pack's
  /// manifest `tafsir` source and its version.
  List<InstalledPack> get installed;

  /// The id of the default tafsir (`TF-01`); null while none is chosen, or
  /// while the chosen one is not installed.
  String? get defaultTafsir;

  /// Fails with [TafsirNotInstalled] unless [packId] is installed.
  Future<Result<void>> setDefaultTafsir(String packId);

  /// The book's own facts for the source badge (`TF-05`).
  Future<Result<TafsirBook>> book(String packId);

  /// Ayah [ayah] as book [packId] explains it. An address that is not an
  /// ayah of the Quran fails with [AddressNotInPack].
  Future<Result<TafsirPosition>> positionAt(String packId, QuranAddress ayah);
}

/// [packId] is not an installed tafsir pack.
final class TafsirNotInstalled implements Exception {
  const TafsirNotInstalled(this.packId);

  final String packId;

  @override
  String toString() => 'TafsirNotInstalled($packId)';
}

/// [TafsirRepository] over the installed packs.
///
/// The first use of a pack in a session verifies it in full through the
/// verifier and then checks its rows against its manifest and the Quran's
/// structure (docs/CONTENT_PACKS.md, "Verification by kind"): one book, as
/// many passages as `counts.passages`, numbered from 1 in mushaf order
/// without a gap, each within the ayat of its surah, none overlapping, and
/// every text strict UTF-8. The outcome is reported to the integrity
/// repository. A pack that fails, then or at a later read, serves nothing
/// for the rest of the session: every call for it fails with that failure.
/// A new version of a pack is checked anew.
final class LocalTafsirRepository extends ChangeNotifier
    implements TafsirRepository {
  LocalTafsirRepository._(
    this._installs,
    this._integrity,
    this._verifier,
    this._structure,
    this._settings,
  ) {
    _installed = List.unmodifiable(_tafsirsIn(_installs.installed));
    _installs.addListener(_onInstalls);
  }

  /// Reads the stored default once, so that it is there synchronously.
  static Future<Result<LocalTafsirRepository>> load({
    required PackInstallRepository installs,
    required PackIntegrityRepository integrity,
    required PackRepository verifier,
    required QuranStructure structure,
    required SettingsDao settings,
  }) async {
    try {
      return Ok(
        LocalTafsirRepository._(
          installs,
          integrity,
          verifier,
          structure,
          await SettingsStore.load(settings),
        ),
      );
    } on Exception catch (error) {
      return Failure(error);
    }
  }

  static const _defaultKey = 'tafsir.default';

  final PackInstallRepository _installs;
  final PackIntegrityRepository _integrity;
  final PackRepository _verifier;
  final QuranStructure _structure;
  final SettingsStore _settings;

  /// By pack directory, so that each version is checked once.
  final _books = <String, Future<Result<_Book>>>{};
  List<InstalledPack> _installed = const [];
  var _disposed = false;

  @override
  List<InstalledPack> get installed => _installed;

  @override
  String? get defaultTafsir {
    final id = _settings.readString(_defaultKey);
    return _installedPack(id) == null ? null : id;
  }

  @override
  Future<Result<void>> setDefaultTafsir(String packId) async {
    if (_installedPack(packId) == null) {
      return Failure(TafsirNotInstalled(packId));
    }
    try {
      await _settings.writeString(_defaultKey, packId);
    } on Exception catch (error) {
      return Failure(error);
    }
    notifyListeners();
    return const Ok(null);
  }

  @override
  Future<Result<TafsirBook>> book(String packId) =>
      _read(packId, (book) => book.facts);

  @override
  Future<Result<TafsirPosition>> positionAt(String packId, QuranAddress ayah) =>
      _read(packId, (book) {
        if (!_isAyah(ayah)) throw AddressNotInPack(packId, ayah);
        return TafsirPosition(
          ayah: ayah,
          passage: book.database.passageAt(ayah.surah, ayah.ayah),
          previous: _previous(book, ayah),
          next: _next(book, ayah),
        );
      });

  bool _isAyah(QuranAddress address) =>
      !address.isWord &&
      address.riwaya == _structure.riwaya &&
      address.surah <= _structure.surahCount &&
      address.ayah <= _structure.ayahCount(address.surah);

  /// The first ayah after the passage of [ayah], or after [ayah] when it has
  /// none.
  QuranAddress? _next(_Book book, QuranAddress ayah) {
    final (_, last) = book.unitOf(ayah.surah, ayah.ayah);
    if (last < _structure.ayahCount(ayah.surah)) {
      return _ayah(ayah.surah, last + 1);
    }
    final surah = _structure.nextSurah(ayah.surah);
    return surah == null ? null : _ayah(surah, 1);
  }

  /// The first ayah of the passage before that of [ayah], or of the ayah
  /// before it when that has none.
  QuranAddress? _previous(_Book book, QuranAddress ayah) {
    final (first, _) = book.unitOf(ayah.surah, ayah.ayah);
    if (first > 1) {
      return _ayah(ayah.surah, book.unitOf(ayah.surah, first - 1).$1);
    }
    if (ayah.surah == 1) return null;
    final surah = ayah.surah - 1;
    return _ayah(surah, book.unitOf(surah, _structure.ayahCount(surah)).$1);
  }

  QuranAddress _ayah(int surah, int ayah) =>
      QuranAddress(_structure.riwaya, surah, ayah);

  InstalledPack? _installedPack(String? id) {
    for (final pack in _installed) {
      if (pack.id == id) return pack;
    }
    return null;
  }

  /// Runs [read] on the checked book of [packId]. A [PackFailure] other than
  /// [AddressNotInPack] disables the pack.
  Future<Result<T>> _read<T>(String packId, T Function(_Book book) read) async {
    final pack = _installedPack(packId);
    if (_disposed || pack == null) return Failure(TafsirNotInstalled(packId));
    final opening = _books[pack.directory] ??= _check(pack);
    final checked = await opening;
    // The pack was removed, replaced or disabled meanwhile.
    if (!identical(_books[pack.directory], opening)) return _read(packId, read);
    switch (checked) {
      case Failure(:final error):
        return Failure(error);
      case Ok(value: final book):
        try {
          return Ok(read(book));
        } on AddressNotInPack catch (failure) {
          return Failure(failure);
        } on PackFailure catch (failure) {
          final named = _named(packId, failure);
          book.database.close();
          _books[pack.directory] = Future.value(Failure(named));
          _integrity.report(
            packId,
            IntegrityFailed(named),
            version: pack.version,
          );
          return Failure(named);
        }
    }
  }

  /// Checks [pack] and opens it. Nothing is reported for a pack removed, or
  /// a repository disposed, while the check ran.
  Future<Result<_Book>> _check(InstalledPack pack) async {
    final id = pack.id;
    bool current() =>
        !_disposed && _installedPack(id)?.directory == pack.directory;
    Result<_Book> checked;
    try {
      checked = switch (await _verifier.verify(pack.directory)) {
        Ok(:final value) => Ok(await _open(value.directory, value.manifest)),
        Failure(:final error) => Failure(error),
      };
    } on Exception catch (error) {
      checked = Failure(error);
    }
    switch (checked) {
      case Ok(value: final book) when !current():
        book.database.close();
        return Failure(TafsirNotInstalled(id));
      case _ when !current():
        return Failure(TafsirNotInstalled(id));
      case Ok():
        _integrity.report(id, const IntegrityOk(), version: pack.version);
        return checked;
      case Failure(:final error):
        final failure = error is PackFailure
            ? _named(id, error)
            : ManifestUnreadable(id, '$error');
        _integrity.report(id, IntegrityFailed(failure), version: pack.version);
        return Failure(failure);
    }
  }

  /// Checks every row of the pack on another isolate, so that decoding the
  /// whole book does not hold up the screen, then opens it for reading.
  Future<_Book> _open(String directory, PackManifest manifest) async {
    final id = manifest.id;
    final counts = manifest.kindCounts;
    final riwaya = _structure.riwaya;
    if (manifest.kind != PackKind.tafsir || counts is! TafsirCounts) {
      throw UnsupportedPackFormat(id, manifest.formatVersion);
    }
    if (manifest.riwaya != riwaya) {
      throw PackInconsistent(
        id,
        'riwaya ${manifest.riwaya} is not the text pack\'s',
      );
    }
    final path = '$directory/$tafsirPackFileName';
    final formatVersion = manifest.formatVersion;
    final ayahCounts = [
      for (var surah = 1; surah <= _structure.surahCount; surah++)
        _structure.ayahCount(surah),
    ];
    final listed = counts.passages;
    final (facts, units) = await Isolate.run(
      () => _checkRows(
        id,
        TafsirPackDatabase.open(
          path,
          formatVersion: formatVersion,
          riwaya: riwaya,
        ),
        ayahCounts,
        listed,
      ),
    );
    return _Book(
      database: TafsirPackDatabase.open(
        path,
        formatVersion: formatVersion,
        riwaya: riwaya,
      ),
      facts: facts,
      units: units,
    );
  }

  /// The book's facts and the ayah ranges of the passages of each surah, in
  /// order, after decoding and checking every row; closes [database].
  static (TafsirBook, List<List<(int, int)>>) _checkRows(
    String id,
    TafsirPackDatabase database,
    List<int> ayahCounts,
    int listed,
  ) {
    try {
      final facts = database.book();
      var numbered = 0;
      final units = <List<(int, int)>>[];
      for (final (index, ayat) in ayahCounts.indexed) {
        final surah = index + 1;
        final passages = database.passagesOfSurah(surah);
        for (final passage in passages) {
          final last = passage.range.end.ayah;
          if (passage.number != ++numbered) {
            throw PackInconsistent(
              id,
              'passage $numbered is numbered ${passage.number}',
            );
          }
          if (last > ayat) {
            throw PackInconsistent(
              id,
              'passage ${passage.number} reaches ayah $last of surah '
              '$surah, which has $ayat',
            );
          }
        }
        units.add([
          for (final passage in passages)
            (passage.range.start.ayah, passage.range.end.ayah),
        ]);
      }
      final stored = database.passageCount();
      if (listed != stored) {
        throw PackInconsistent(
          id,
          'counts.passages is $listed; the pack holds $stored',
        );
      }
      if (numbered != stored) {
        throw PackInconsistent(
          id,
          '${stored - numbered} passages lie outside the surahs',
        );
      }
      return (facts, units);
    } finally {
      database.close();
    }
  }

  /// The database names the file; the repository names the pack [id].
  static PackFailure _named(String id, PackFailure failure) =>
      switch (failure) {
        ManifestUnreadable(:final reason) => ManifestUnreadable(id, reason),
        SignatureRejected() => SignatureRejected(id),
        UnsupportedPackFormat(:final formatVersion) => UnsupportedPackFormat(
          id,
          formatVersion,
        ),
        FileHashMismatch(:final file) => FileHashMismatch(id, file),
        SurahHashMismatch(:final surah) => SurahHashMismatch(id, surah),
        TextEncodingRejected(:final surah, :final ayah) => TextEncodingRejected(
          id,
          surah,
          ayah,
        ),
        PackInconsistent(:final reason) => PackInconsistent(id, reason),
        AddressNotInPack(:final address) => AddressNotInPack(id, address),
        PackDisabled() => PackDisabled(id),
      };

  static List<InstalledPack> _tafsirsIn(List<InstalledPack> packs) => [
    for (final pack in packs)
      if (pack.manifest.kind == PackKind.tafsir) pack,
  ];

  void _onInstalls() {
    final tafsirs = _tafsirsIn(_installs.installed);
    final directories = {for (final pack in tafsirs) pack.directory};
    for (final directory in [..._books.keys]) {
      if (!directories.contains(directory)) _close(_books.remove(directory)!);
    }
    if (listEquals(
      [for (final pack in tafsirs) pack.directory],
      [for (final pack in _installed) pack.directory],
    )) {
      return;
    }
    _installed = List.unmodifiable(tafsirs);
    notifyListeners();
  }

  static void _close(Future<Result<_Book>> book) => unawaited(
    book.then((checked) {
      if (checked case Ok(:final value)) value.database.close();
    }),
  );

  @override
  void dispose() {
    _disposed = true;
    _installs.removeListener(_onInstalls);
    for (final book in _books.values) {
      _close(book);
    }
    _books.clear();
    super.dispose();
  }
}

/// A pack that passed its checks this session.
final class _Book {
  _Book({required this.database, required this.facts, required this.units});

  final TafsirPackDatabase database;
  final TafsirBook facts;
  final List<List<(int, int)>> units;

  /// The first and last ayah of the passage over [ayah] of [surah], or
  /// [ayah] alone when it has none.
  (int, int) unitOf(int surah, int ayah) {
    for (final unit in units[surah - 1]) {
      if (unit.$1 <= ayah && ayah <= unit.$2) return unit;
    }
    return (ayah, ayah);
  }
}
