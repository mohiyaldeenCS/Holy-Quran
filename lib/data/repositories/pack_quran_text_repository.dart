import '../../domain/models/edition_map.dart';
import '../../domain/models/mark_span.dart';
import '../../domain/models/pack_failure.dart';
import '../../domain/models/pack_manifest.dart';
import '../../domain/models/pack_text.dart';
import '../../domain/models/quran_address.dart';
import '../../domain/models/surah_info.dart';
import '../../domain/models/verified_pack.dart';
import '../../domain/models/word_span.dart';
import '../../utils/result.dart';
import '../models/pack_manifest_json.dart';
import '../services/pack_database.dart';
import 'quran_text_repository.dart';

/// Reads a verified text pack through its [PackDatabase]. Failures name the
/// pack by its id.
///
/// Before the first read, the database's rows are compared with the
/// manifest's counts. Before the first read of a surah, its digest is
/// compared with the manifest, each of its texts is decoded and the word
/// and mark spans of each ayah are checked together. Any of these failing,
/// or a text the database refuses, fails that call and disables the pack:
/// every later call fails with [PackDisabled], and the failure is passed to
/// `onDisabled`, so that the pack's integrity can be reported. A count,
/// numbering, reference or span that is wrong is a [PackInconsistent].
/// While `serving` says the pack is not in use, because another reader
/// failed it, every call fails with [PackDisabled] as well.
///
/// The reads are synchronous inside; the interface is asynchronous so that
/// they can move to an isolate without changing it.
final class PackQuranTextRepository implements QuranTextRepository {
  /// Throws an [ArgumentError] when the manifest names no riwaya; [open]
  /// returns that as a failure instead.
  PackQuranTextRepository({
    required VerifiedPack pack,
    required this._database,
    this._onDisabled,
    this._serving,
  }) : _manifest = pack.manifest,
       riwaya =
           pack.manifest.riwaya ??
           (throw ArgumentError.value(pack.directory, 'pack', 'has no riwaya'));

  /// Opens `text.sqlite` of [pack] read-only. A file that is not a text pack
  /// of the manifest's format version fails with [UnsupportedPackFormat], a
  /// file that cannot be read with [FileHashMismatch].
  static Result<PackQuranTextRepository> open(
    VerifiedPack pack, {
    void Function(PackFailure failure)? onDisabled,
    bool Function()? serving,
  }) {
    final manifest = pack.manifest;
    if (manifest.kind != PackKind.text || manifest.riwaya == null) {
      return Failure(
        UnsupportedPackFormat(manifest.id, manifest.formatVersion),
      );
    }
    try {
      final database = PackDatabase.open(
        '${pack.directory}/$textPackFileName',
        formatVersion: manifest.formatVersion,
      );
      return Ok(
        PackQuranTextRepository(
          pack: pack,
          database: database,
          onDisabled: onDisabled,
          serving: serving,
        ),
      );
    } on PackFailure catch (failure) {
      return Failure(_named(manifest.id, failure));
    }
  }

  final PackManifest _manifest;
  final PackDatabase _database;
  final void Function(PackFailure failure)? _onDisabled;
  final bool Function()? _serving;

  @override
  final String riwaya;

  var _disabled = false;
  List<SurahInfo>? _surahs;
  EditionMap? _editionMap;
  final _verifiedSurahs = <int>{};

  String get _id => _manifest.id;

  /// Closes the pack file. No call may follow.
  void close() => _database.close();

  @override
  PackFont get font => _manifest.font;

  @override
  Future<Result<List<SurahInfo>>> surahs() async => _read(_surahList);

  @override
  Future<Result<PackText>> ayahText(QuranAddress address) async => _read(() {
    _expectAyah(address);
    _verifySurah(address.surah);
    return _database.ayahText(address.surah, address.ayah) ??
        (throw _missingAyah(address.surah, address.ayah));
  });

  /// Completes with an [ArgumentError] when [surah] is below 1, as
  /// [QuranAddress] throws one. A surah after the last fails with
  /// [AddressNotInPack] naming its first ayah.
  @override
  Future<Result<PackText?>> basmala(int surah) async {
    final address = QuranAddress(riwaya, surah, 1);
    return _read(() {
      if (!_hasSurah(address)) throw AddressNotInPack(_id, address);
      _verifySurah(surah);
      return _database.basmala(surah);
    });
  }

  @override
  Future<Result<Set<int>>> basmalaSurahs() async => _read(() {
    _surahList();
    return _database.surahsWithBasmala().toSet();
  });

  @override
  Future<Result<List<WordSpan>>> words(QuranAddress address) async => _read(() {
    _expectAyah(address);
    _verifySurah(address.surah);
    return [
      for (final word in _database.words(address.surah, address.ayah))
        WordSpan(number: word.number, start: word.start, end: word.end),
    ];
  });

  @override
  Future<Result<List<MarkSpan>>> marks(QuranAddress address) async => _read(() {
    _expectAyah(address);
    _verifySurah(address.surah);
    return [
      for (final mark in _database.marks(address.surah, address.ayah))
        MarkSpan(
          number: mark.number,
          afterWord: mark.afterWord,
          start: mark.start,
          end: mark.end,
        ),
    ];
  });

  @override
  Future<Result<EditionMap>> editionMap() async =>
      _read(() => _editionMap ??= _buildEditionMap());

  @override
  Future<Result<bool>> contains(QuranAddress address) async => _read(() {
    if (!_hasAyah(address.ayahAddress)) return false;
    final word = address.word;
    if (word == null) return true;
    _verifySurah(address.surah);
    return word <= _database.words(address.surah, address.ayah).length;
  });

  Result<T> _read<T>(T Function() read) {
    if (_disabled || !(_serving?.call() ?? true)) {
      return Failure(PackDisabled(_id));
    }
    try {
      return Ok(read());
    } on AddressNotInPack catch (failure) {
      return Failure(failure);
    } on PackFailure catch (failure) {
      _disabled = true;
      final named = _named(_id, failure);
      _onDisabled?.call(named);
      return Failure(named);
    }
  }

  /// The database names the file; the repository names the pack [id].
  static PackFailure _named(String id, PackFailure failure) =>
      switch (failure) {
        UnsupportedPackFormat(:final formatVersion) => UnsupportedPackFormat(
          id,
          formatVersion,
        ),
        TextEncodingRejected(:final surah, :final ayah) => TextEncodingRejected(
          id,
          surah,
          ayah,
        ),
        FileHashMismatch(:final file) => FileHashMismatch(id, file),
        _ => failure,
      };

  List<SurahInfo> _surahList() => _surahs ??= _checkedSurahs();

  List<SurahInfo> _checkedSurahs() {
    final counts = _manifest.counts;
    final rows = _database.rowCounts();
    final surahs = _database.surahs();
    void expect(String field, int listed, int stored) {
      if (listed != stored) {
        throw PackInconsistent(
          _id,
          'counts.$field is $listed; the pack holds $stored',
        );
      }
    }

    expect('surahs', counts.surahs, rows.surahs);
    expect('ayat', counts.ayat, rows.ayat);
    expect(
      'ayat',
      counts.ayat,
      surahs.fold(0, (sum, surah) => sum + surah.ayahCount),
    );
    expect('words', counts.words, rows.words);
    expect('marks', counts.marks, rows.marks);
    for (final division in Division.values) {
      expect(
        'divisions.${division.name}',
        counts.divisions[division]!,
        rows.divisions[division]!,
      );
    }
    expect('sajdas', counts.sajdas, rows.sajdas);
    for (final (index, surah) in surahs.indexed) {
      if (surah.number != index + 1) {
        throw PackInconsistent(_id, 'surah ${index + 1} is missing');
      }
    }
    return surahs;
  }

  bool _hasSurah(QuranAddress address) =>
      address.riwaya == riwaya && address.surah <= _surahList().length;

  bool _hasAyah(QuranAddress address) =>
      !address.isWord &&
      _hasSurah(address) &&
      address.ayah <= _surahList()[address.surah - 1].ayahCount;

  void _expectAyah(QuranAddress address) {
    if (!_hasAyah(address)) throw AddressNotInPack(_id, address);
  }

  void _verifySurah(int surah) {
    if (_verifiedSurahs.contains(surah)) return;
    if (_database.surahSha256(surah) != _manifest.surahSha256[surah]) {
      throw SurahHashMismatch(_id, surah);
    }
    _database.basmala(surah);
    for (var ayah = 1; ayah <= _surahList()[surah - 1].ayahCount; ayah++) {
      _checkSpans(
        QuranAddress(riwaya, surah, ayah),
        _database.ayahText(surah, ayah) ?? (throw _missingAyah(surah, ayah)),
        _database.words(surah, ayah),
        _database.marks(surah, ayah),
      );
    }
    _verifiedSurahs.add(surah);
  }

  /// The words and marks of an ayah, merged in text order: each kind
  /// numbered from 1, every span non-empty, on character boundaries within
  /// the ayah and after the span before it, and every mark after the word
  /// its after_word names (D-078).
  void _checkSpans(
    QuranAddress ayah,
    PackText text,
    List<WordRow> words,
    List<MarkRow> marks,
  ) {
    var previous = (kind: 'word', end: 0);
    var w = 0;
    var m = 0;
    while (w < words.length || m < marks.length) {
      final isWord =
          m == marks.length ||
          (w < words.length && words[w].start <= marks[m].start);
      final (kind, expected, number, start, end) = isWord
          ? ('word', w + 1, words[w].number, words[w].start, words[w].end)
          : ('mark', m + 1, marks[m].number, marks[m].start, marks[m].end);
      final problem =
          _spanProblem(kind, expected, number, start, end, text, previous) ??
          (isWord || marks[m].afterWord == w
              ? null
              : 'mark $number has after_word ${marks[m].afterWord}, not $w');
      if (problem != null) {
        throw PackInconsistent(_id, '$ayah: $problem: [$start, $end)');
      }
      previous = (kind: kind, end: end);
      if (isWord) {
        w++;
      } else {
        m++;
      }
    }
  }

  static String? _spanProblem(
    String kind,
    int expected,
    int number,
    int start,
    int end,
    PackText text,
    ({String kind, int end}) previous,
  ) {
    if (number != expected) return '$kind $expected is numbered $number';
    if (start >= end) return '$kind $number is empty or reversed';
    if (!text.isSliceBoundary(start) || !text.isSliceBoundary(end)) {
      return '$kind $number is outside the ayah or splits a character';
    }
    if (start < previous.end) {
      return '$kind $number overlaps the ${previous.kind} before';
    }
    return null;
  }

  PackInconsistent _missingAyah(int surah, int ayah) =>
      PackInconsistent(_id, 'surah $surah lacks ayah $ayah');

  EditionMap _buildEditionMap() {
    final starts = {
      for (final division in Division.values) division: <QuranAddress>[],
    };
    for (final row in _database.divisions()) {
      final list = starts[row.kind]!;
      final unit = '${row.kind.name} ${row.number}';
      if (row.number != list.length + 1) {
        throw PackInconsistent(_id, '$unit is out of sequence');
      }
      final start = _storedAyah(row.surah, row.ayah, unit);
      if (list.isNotEmpty && list.last.compareTo(start) >= 0) {
        throw PackInconsistent(_id, '$unit does not follow the unit before');
      }
      list.add(start);
    }
    return EditionMap(
      edition: _manifest.edition,
      starts: starts,
      sajdas: {
        for (final (surah, ayah) in _database.sajdas())
          _storedAyah(surah, ayah, 'sajda'),
      },
    );
  }

  /// The address of an ayah a row of the pack refers to.
  QuranAddress _storedAyah(int surah, int ayah, String row) {
    final surahs = _surahList();
    if (surah < 1 ||
        surah > surahs.length ||
        ayah < 1 ||
        ayah > surahs[surah - 1].ayahCount) {
      throw PackInconsistent(_id, '$row refers to no ayah of the pack');
    }
    return QuranAddress(riwaya, surah, ayah);
  }
}
