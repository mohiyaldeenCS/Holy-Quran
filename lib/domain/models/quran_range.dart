import 'quran_address.dart';

/// From [start] to [end] inclusive, both in one riwaya and both ayah or both
/// word addresses. Canonical form: `hafs:2:255-2:260` or
/// `hafs:2:255:3-2:255:7`, the riwaya written once.
final class QuranRange implements Comparable<QuranRange> {
  QuranRange(this.start, this.end) {
    if (_problem(start, end) case final problem?) {
      throw ArgumentError('$problem: $start, $end');
    }
  }

  final QuranAddress start;
  final QuranAddress end;

  /// Throws a [FormatException] unless [source] is in the canonical form.
  static QuranRange parse(String source) =>
      tryParse(source) ??
      (throw FormatException('Not a canonical Quran range', source));

  static QuranRange? tryParse(String source) {
    if (source.split('-') case [final head, final tail]) {
      final start = QuranAddress.tryParse(head);
      if (start == null) return null;
      final end = QuranAddress.tryParse('${start.riwaya}:$tail');
      if (end == null || _problem(start, end) != null) return null;
      return QuranRange(start, end);
    }
    return null;
  }

  static String? _problem(QuranAddress start, QuranAddress end) {
    if (start.riwaya != end.riwaya) return 'different riwayat';
    if (start.isWord != end.isWord) return 'different granularity';
    if (start.compareTo(end) > 0) return 'start after end';
    return null;
  }

  /// An ayah range contains its ayat and every word of them. A word range
  /// contains only word addresses, never an ayah address. An address in
  /// another riwaya is not contained.
  bool contains(QuranAddress address) {
    if (address.riwaya != start.riwaya) return false;
    if (start.isWord && !address.isWord) return false;
    final probe = start.isWord ? address : address.ayahAddress;
    return start.compareTo(probe) <= 0 && probe.compareTo(end) <= 0;
  }

  /// Orders by [start], then by [end]. Throws an [ArgumentError] across
  /// riwayat.
  @override
  int compareTo(QuranRange other) {
    final byStart = start.compareTo(other.start);
    return byStart != 0 ? byStart : end.compareTo(other.end);
  }

  @override
  bool operator ==(Object other) =>
      other is QuranRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() =>
      '$start-${end.surah}:${end.ayah}${end.isWord ? ':${end.word}' : ''}';
}
