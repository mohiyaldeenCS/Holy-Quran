import 'quran_address.dart';

/// How a recitation's files are cut: one file per ayah, or one per surah.
enum RecitationUnit { ayah, surah }

/// A reciter with a riwaya and a style, as the catalogue gives them.
final class Recitation {
  Recitation({
    required this.id,
    required this.reciter,
    required this.riwaya,
    required this.style,
    required this.unit,
    required this.hasWordTiming,
    required this.rightsComplete,
    this.hasBasmalaFile = false,
    this.hasIstiadhaFile = false,
  }) {
    if (!QuranAddress.riwayaPattern.hasMatch(riwaya)) {
      throw ArgumentError.value(riwaya, 'riwaya', 'is not a riwaya name');
    }
  }

  final String id;
  final String reciter;
  final String riwaya;
  final String style;
  final RecitationUnit unit;

  /// Whether its word timing passed measurement (`SY-02`).
  final bool hasWordTiming;

  /// Whether its rights record is complete; if not, it is neither listed nor
  /// played.
  final bool rightsComplete;

  /// Whether the reciter's own files include a separate basmala or
  /// isti'adha; none is ever taken from another recording (`AU-24`).
  final bool hasBasmalaFile;
  final bool hasIstiadhaFile;

  @override
  bool operator ==(Object other) => other is Recitation && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Recitation($id)';
}
