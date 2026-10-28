import 'quran_range.dart';
import 'recitation.dart';
import 'recitation_file.dart';

/// What of a recitation is downloaded together (`AU-13`): all of it, a
/// surah, or the ayat of a range such as a juz.
sealed class RecitationSelection {
  const RecitationSelection();

  /// Whether [file] belongs to it. The reciter's own basmala and isti'adha
  /// belong to every selection, since playing needs them (`AU-24`).
  bool includes(RecitationFile file);

  /// Names the selection inside a job key.
  String get key;
}

final class WholeRecitation extends RecitationSelection {
  const WholeRecitation();

  @override
  bool includes(RecitationFile file) => true;

  @override
  String get key => 'all';
}

final class RecitationSurah extends RecitationSelection {
  const RecitationSurah(this.surah);

  final int surah;

  @override
  bool includes(RecitationFile file) =>
      file.surah == null || file.surah == surah;

  @override
  String get key => 'surah-$surah';
}

/// The ayat of [range]. A recitation cut by surah cannot be cut inside a
/// surah, so it takes every surah the range touches.
final class RecitationSpan extends RecitationSelection {
  const RecitationSpan(this.range);

  final QuranRange range;

  @override
  bool includes(RecitationFile file) {
    final surah = file.surah;
    if (surah == null) return true;
    final (start, end) = (range.start, range.end);
    if (surah < start.surah || surah > end.surah) return false;
    return switch (file.ayah) {
      null => true,
      final ayah =>
        (surah > start.surah || ayah >= start.ayah) &&
            (surah < end.surah || ayah <= end.ayah),
    };
  }

  @override
  String get key =>
      'span-${range.start.surah}:${range.start.ayah}-'
      '${range.end.surah}:${range.end.ayah}';
}

/// The files an installed recitation pack indexes, at every quality.
final class RecitationContents {
  RecitationContents({
    required this.recitationId,
    required this.packId,
    required this.baseUrl,
    required this.unit,
    required List<RecitationFile> files,
  }) : files = List.unmodifiable(files);

  final String recitationId;
  final String packId;
  final Uri baseUrl;
  final RecitationUnit unit;
  final List<RecitationFile> files;

  Uri urlOf(RecitationFile file) => baseUrl.resolve(file.path);
}

/// One download: [selection] of the recitation at [qualityKbps].
final class RecitationTarget {
  RecitationTarget(this.contents, this.qualityKbps, this.selection)
    : files = List.unmodifiable([
        for (final file in contents.files)
          if (file.qualityKbps == qualityKbps && selection.includes(file)) file,
      ]);

  final RecitationContents contents;
  final int qualityKbps;
  final RecitationSelection selection;
  final List<RecitationFile> files;

  String get key => '${contents.recitationId}/$qualityKbps/${selection.key}';

  int get bytes => files.fold(0, (sum, file) => sum + file.bytes);
}
