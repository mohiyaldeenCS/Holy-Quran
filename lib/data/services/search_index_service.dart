import 'dart:isolate';

import '../../domain/models/pack_failure.dart';
import '../../domain/models/pack_manifest.dart';
import '../../domain/models/quran_address.dart';
import '../../domain/models/quran_range.dart';
import '../../domain/models/search_form.dart';
import '../../domain/models/search_hit.dart';
import '../../domain/models/search_query.dart';
import '../../domain/models/verified_pack.dart';
import '../../utils/result.dart';
import '../models/pack_manifest_json.dart';
import 'pack_database.dart';

/// Builds the [SearchIndex] of a verified text pack from its stored search
/// forms, off the main isolate. Nothing is written: the index lives in
/// memory, unfolded, for the session (D-118).
final class SearchIndexService {
  const SearchIndexService(this._pack);

  final VerifiedPack _pack;

  /// Fails with a [PackFailure] naming the pack: those of opening
  /// `text.sqlite`, [TextEncodingRejected] for a form that is not strict
  /// UTF-8, and [PackInconsistent] when the forms are not numbered word by
  /// word or their number of each kind is not the manifest's.
  Future<Result<SearchIndex>> build() {
    final pack = _pack;
    return Isolate.run(() => _build(pack));
  }

  static Result<SearchIndex> _build(VerifiedPack pack) {
    final manifest = pack.manifest;
    final riwaya = manifest.riwaya;
    if (manifest.kind != PackKind.text || riwaya == null) {
      return Failure(
        UnsupportedPackFormat(manifest.id, manifest.formatVersion),
      );
    }
    PackDatabase? database;
    try {
      final opened = database = PackDatabase.open(
        '${pack.directory}/$textPackFileName',
        formatVersion: manifest.formatVersion,
      );
      final index = SearchIndex.fromForms(
        manifest.id,
        opened.surahs().expand(
          (surah) => opened.searchForms(surah.number, riwaya: riwaya),
        ),
      );
      final listed = manifest.counts.searchForms;
      final stored = {for (final kind in index.kinds) kind: index.count(kind)};
      if (listed.length != stored.length ||
          listed.entries.any((entry) => stored[entry.key] != entry.value)) {
        throw PackInconsistent(
          manifest.id,
          'counts.search_forms is $listed; the pack holds $stored',
        );
      }
      return Ok(index);
    } on PackFailure catch (failure) {
      return Failure(_named(manifest.id, failure));
    } finally {
      database?.close();
    }
  }

  /// The database names the file; the index names the pack [id].
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
        PackInconsistent(:final reason) => PackInconsistent(id, reason),
        _ => failure,
      };
}

/// The search forms of a text pack, by kind and ayah, compared with a
/// query's folded words exactly as stored. A sink of D-114: it reads the
/// forms only to compare them, and a form that holds U+0020, as when the
/// source spells one word as several, matches that many words of the query.
final class SearchIndex {
  SearchIndex._(this._kinds);

  /// Throws [PackInconsistent] naming [pack] unless [forms] come in mushaf
  /// order, each kind numbering the words of an ayah from 1 without a gap.
  factory SearchIndex.fromForms(String pack, Iterable<SearchForm> forms) {
    final kinds = <String, List<_AyahForms>>{};
    for (final form in forms) {
      final ayah = form.word.ayahAddress;
      final ayat = kinds.putIfAbsent(form.kind, () => []);
      final last = ayat.isEmpty ? null : ayat.last;
      final List<String> words;
      if (last != null && last.ayah == ayah) {
        words = last.forms;
      } else if (last == null || last.ayah.compareTo(ayah) < 0) {
        words = [];
        ayat.add(_AyahForms(ayah, words));
      } else {
        throw PackInconsistent(pack, 'search forms out of order at $ayah');
      }
      if (form.word.word != words.length + 1) {
        throw PackInconsistent(
          pack,
          'search form ${form.kind} of ${form.word} follows word '
          '${words.length}',
        );
      }
      words.add(form.form.verbatim);
    }
    return SearchIndex._(kinds);
  }

  final Map<String, List<_AyahForms>> _kinds;

  /// The kinds of form held, in name order.
  List<String> get kinds => [..._kinds.keys]..sort();

  /// The number of forms of [kind]; 0 for a kind not held.
  int count(String kind) =>
      _kinds[kind]?.fold<int>(0, (sum, ayah) => sum + ayah.forms.length) ?? 0;

  /// The ayat, within [within] when given, whose forms of [kind] hold
  /// [words], a query's folded words, as [mode] asks; in mushaf order.
  /// Throws an [ArgumentError] for a kind not held.
  List<SearchHit> search(
    String kind,
    List<String> words,
    SearchMode mode, {
    QuranRange? within,
  }) {
    final ayat =
        _kinds[kind] ??
        (throw ArgumentError.value(kind, 'kind', 'is not a form kind held'));
    if (words.isEmpty) return const [];
    final query = _Query(words);
    return [
      for (final ayah in ayat)
        if (within == null || within.contains(ayah.ayah))
          ?query.hit(ayah, mode),
    ];
  }
}

final class _AyahForms {
  _AyahForms(this.ayah, this.forms);

  final QuranAddress ayah;
  final List<String> forms;
  late final bool spaced = forms.any((form) => form.contains(' '));
}

/// A query's folded words and what comparing them needs.
final class _Query {
  _Query(this._words)
    : _runs = [
        for (var j = 0; j < _words.length; j++)
          [
            for (var k = j + 2; k <= _words.length; k++)
              _words.sublist(j, k).join(' '),
          ],
      ],
      _labels = {} {
    for (final word in _words) {
      _labels.putIfAbsent(word, () => _labels.length);
    }
  }

  final List<String> _words;

  /// For each word, the runs of two or more words starting with it, joined
  /// by U+0020 to meet a form that holds a space.
  final List<List<String>> _runs;

  /// Each distinct word's number, for scattered words.
  final Map<String, int> _labels;

  SearchHit? hit(_AyahForms ayah, SearchMode mode) => switch (mode) {
    SearchMode.wholeAyah => _wholeAyah(ayah),
    SearchMode.phrase => _phrase(ayah),
    SearchMode.scattered => _scattered(ayah),
  };

  /// The number of query words from [j] that [form] stands for, or null.
  int? _consumed(String form, bool spaced, int j) {
    if (form == _words[j]) return 1;
    if (!spaced) return null;
    final runs = _runs[j];
    for (var k = 0; k < runs.length; k++) {
      if (form == runs[k]) return k + 2;
    }
    return null;
  }

  /// The index after the phrase when it starts at form [i], or null.
  int? _phraseAt(_AyahForms ayah, int i) {
    final forms = ayah.forms;
    var p = i;
    for (var j = 0; j < _words.length; p++) {
      if (p == forms.length) return null;
      final consumed = _consumed(forms[p], ayah.spaced, j);
      if (consumed == null) return null;
      j += consumed;
    }
    return p;
  }

  SearchHit? _wholeAyah(_AyahForms ayah) {
    if (_phraseAt(ayah, 0) != ayah.forms.length) return null;
    return _exactHit(ayah, [(0, ayah.forms.length)]);
  }

  SearchHit? _phrase(_AyahForms ayah) {
    final found = <(int, int)>[];
    for (var i = 0; i < ayah.forms.length;) {
      if (_phraseAt(ayah, i) case final end?) {
        found.add((i, end));
        i = end;
      } else {
        i++;
      }
    }
    return found.isEmpty ? null : _exactHit(ayah, found);
  }

  SearchHit? _scattered(_AyahForms ayah) {
    final positions = <int>[];
    final labels = <Set<int>>[];
    final seen = <int>{};
    for (final (i, form) in ayah.forms.indexed) {
      final covered = <int>{};
      if (ayah.spaced) {
        for (var j = 0; j < _words.length; j++) {
          final count = _consumed(form, true, j) ?? 0;
          for (var c = j; c < j + count; c++) {
            covered.add(_labels[_words[c]]!);
          }
        }
      } else if (_labels[form] case final label?) {
        covered.add(label);
      }
      if (covered.isEmpty) continue;
      positions.add(i);
      labels.add(covered);
      seen.addAll(covered);
    }
    if (seen.length < _labels.length) return null;
    final exact = Iterable<int>.generate(
      ayah.forms.length,
    ).any((i) => _phraseAt(ayah, i) != null);
    return SearchHit(
      ayah: ayah.ayah,
      matches: [for (final i in positions) _range(ayah, i, i + 1)],
      exact: exact,
      gaps: exact ? 0 : _fewestGaps(positions, labels),
    );
  }

  /// The fewest words, not matching, in a stretch of the ayah holding every
  /// distinct word: the shortest stretch ending at each match is the one
  /// with the fewest such words among those ending there.
  int _fewestGaps(List<int> positions, List<Set<int>> labels) {
    final counts = List.filled(_labels.length, 0);
    var held = 0;
    var fewest = -1;
    var left = 0;
    for (var right = 0; right < positions.length; right++) {
      for (final label in labels[right]) {
        if (counts[label]++ == 0) held++;
      }
      while (held == _labels.length) {
        final gaps =
            positions[right] - positions[left] + 1 - (right - left + 1);
        if (fewest < 0 || gaps < fewest) fewest = gaps;
        for (final label in labels[left]) {
          if (--counts[label] == 0) held--;
        }
        left++;
      }
    }
    return fewest;
  }

  SearchHit _exactHit(_AyahForms ayah, List<(int, int)> found) => SearchHit(
    ayah: ayah.ayah,
    matches: [for (final (start, end) in found) _range(ayah, start, end)],
    exact: true,
    gaps: 0,
  );

  /// Forms [start] to [end] (exclusive) as a range of word addresses.
  static QuranRange _range(_AyahForms ayah, int start, int end) {
    final at = ayah.ayah;
    return QuranRange(
      QuranAddress(at.riwaya, at.surah, at.ayah, start + 1),
      QuranAddress(at.riwaya, at.surah, at.ayah, end),
    );
  }
}
