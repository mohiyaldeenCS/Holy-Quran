/// What a recitation file holds: a surah, an ayah, or the reciter's own
/// basmala or isti'adha (`AU-24`).
enum RecitationFilePart { surah, ayah, basmala, istiadha }

/// One audio file of a recitation pack, at one quality (`AU-13`, `AU-14`).
/// It is fetched from [path] under the pack's base URL and refused unless
/// its size and SHA-256 match.
final class RecitationFile {
  RecitationFile({
    required this.qualityKbps,
    required this.part,
    required this.surah,
    required this.ayah,
    required this.path,
    required this.bytes,
    required this.sha256,
    required this.duration,
  }) {
    if (qualityKbps < 1) {
      throw ArgumentError.value(qualityKbps, 'qualityKbps', 'is not positive');
    }
    final (needsSurah, needsAyah) = switch (part) {
      RecitationFilePart.surah => (true, false),
      RecitationFilePart.ayah => (true, true),
      RecitationFilePart.basmala ||
      RecitationFilePart.istiadha => (false, false),
    };
    if ((surah != null) != needsSurah || (ayah != null) != needsAyah) {
      throw ArgumentError('A ${part.name} file has surah $surah, ayah $ayah');
    }
    for (final (name, number) in [('surah', surah), ('ayah', ayah)]) {
      if (number != null && number < 1) {
        throw ArgumentError.value(number, name, 'is not positive');
      }
    }
    if (!pathPattern.hasMatch(path) || _dotSegment.hasMatch(path)) {
      throw ArgumentError.value(path, 'path', 'is not a plain relative path');
    }
    if (bytes < 1) throw ArgumentError.value(bytes, 'bytes', 'is not positive');
    if (!_sha256.hasMatch(sha256)) {
      throw ArgumentError.value(sha256, 'sha256', 'is not lowercase hex');
    }
    if (duration case final duration? when duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'duration', 'is not positive');
    }
  }

  /// Segments of letters, digits, `.`, `_` and `-`, joined by `/`.
  static final pathPattern = RegExp(r'^[A-Za-z0-9._-]+(?:/[A-Za-z0-9._-]+)*$');
  static final _dotSegment = RegExp(r'(?:^|/)\.\.?(?:/|$)');
  static final _sha256 = RegExp(r'^[0-9a-f]{64}$');

  final int qualityKbps;
  final RecitationFilePart part;

  /// Null for a basmala or isti'adha file.
  final int? surah;

  /// Set for an ayah file only.
  final int? ayah;

  /// Relative to the pack's base URL.
  final String path;
  final int bytes;
  final String sha256;

  /// Null when the pack does not state it exactly.
  final Duration? duration;
}
