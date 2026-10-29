import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_range.dart';
import 'package:holyquran/domain/models/recitation_file.dart';
import 'package:holyquran/domain/models/recitation_target.dart';
import 'package:holyquran/ui/features/resources/view_models/recitation_block_state.dart';

/// One thing of a recitation that can be downloaded: the whole, a surah or
/// a juz.
final class RecitationScope {
  const RecitationScope(this.kind, this.number, this.selection);

  final ScopeKind kind;
  final int number;
  final RecitationSelection selection;
}

/// What a scope holds, and how much of it is not on the device yet.
final class RecitationCount {
  const RecitationCount(this.total, this.missing);

  final int total;
  final int missing;
}

/// The whole, each surah and each juz of the edition [index] describes;
/// only the whole without an index.
List<RecitationScope> scopesOf(QuranIndexRepository? index) => [
  const RecitationScope(ScopeKind.whole, 0, WholeRecitation()),
  if (index != null) ...[
    for (var surah = 1; surah <= index.surahCount; surah++)
      RecitationScope(ScopeKind.surah, surah, RecitationSurah(surah)),
    for (var juz = 1; juz <= index.count(Division.juz); juz++)
      RecitationScope(
        ScopeKind.juz,
        juz,
        RecitationSpan(_juzRange(index, juz)),
      ),
  ],
];

/// From the first ayah of the juz to the ayah before the next juz starts.
QuranRange _juzRange(QuranIndexRepository index, int juz) {
  final start = index.firstAyah(Division.juz, juz);
  final QuranAddress end;
  if (juz < index.count(Division.juz)) {
    final next = index.firstAyah(Division.juz, juz + 1);
    end = next.ayah > 1
        ? QuranAddress(next.riwaya, next.surah, next.ayah - 1)
        : QuranAddress(
            next.riwaya,
            next.surah - 1,
            index.ayahCount(next.surah - 1),
          );
  } else {
    final last = index.surahCount;
    end = QuranAddress(index.riwaya, last, index.ayahCount(last));
  }
  return QuranRange(start, end);
}

/// The files of one quality: those of no surah, which every selection
/// takes, and the others by surah.
final class RecitationQualityFiles {
  const RecitationQualityFiles({
    this.common = const [],
    this.bySurah = const {},
  });

  final List<RecitationFile> common;
  final Map<int, List<RecitationFile>> bySurah;
}

/// The files of a recitation's installed pack, grouped for counting.
final class RecitationPackFiles {
  RecitationPackFiles(this.contents, this.version) {
    final common = <int, List<RecitationFile>>{};
    final bySurah = <int, Map<int, List<RecitationFile>>>{};
    for (final file in contents.files) {
      final surah = file.surah;
      if (surah == null) {
        common.putIfAbsent(file.qualityKbps, () => []).add(file);
      } else {
        bySurah
            .putIfAbsent(file.qualityKbps, () => {})
            .putIfAbsent(surah, () => [])
            .add(file);
      }
    }
    byQuality = {
      for (final quality in {...common.keys, ...bySurah.keys})
        quality: RecitationQualityFiles(
          common: common[quality] ?? const [],
          bySurah: bySurah[quality] ?? const {},
        ),
    };
  }

  final RecitationContents contents;
  final int version;
  late final Map<int, RecitationQualityFiles> byQuality;

  /// What each of [scopes] holds at [quality], and how much of it is not
  /// among the [present] paths. A scope counts the files every selection
  /// needs, so it is whole only once they are on the device too.
  Map<String, RecitationCount> tally(
    List<RecitationScope> scopes,
    int quality,
    Set<String> present,
  ) {
    final files = byQuality[quality] ?? const RecitationQualityFiles();
    return {
      for (final scope in scopes)
        scope.selection.key: _count(files, scope.selection, present),
    };
  }

  static RecitationCount _count(
    RecitationQualityFiles files,
    RecitationSelection selection,
    Set<String> present,
  ) {
    var total = 0;
    var missing = 0;
    void add(RecitationFile file) {
      total += file.bytes;
      if (!present.contains(file.path)) missing += file.bytes;
    }

    files.common.forEach(add);
    final (first, last) = switch (selection) {
      WholeRecitation() => (1, files.bySurah.keys.fold(1, _larger)),
      RecitationSurah(:final surah) => (surah, surah),
      RecitationSpan(:final range) => (range.start.surah, range.end.surah),
    };
    for (var surah = first; surah <= last; surah++) {
      for (final file in files.bySurah[surah] ?? const <RecitationFile>[]) {
        if (selection.includes(file)) add(file);
      }
    }
    return RecitationCount(total, missing);
  }

  static int _larger(int a, int b) => a > b ? a : b;
}
