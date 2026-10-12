import 'quran_address.dart';

/// Where the ayah of [address] sits in the reference edition. Every number
/// counts from 1.
final class QuranPosition {
  const QuranPosition({
    required this.address,
    required this.surah,
    required this.juz,
    required this.hizb,
    required this.rub,
    required this.page,
  });

  final QuranAddress address;
  final int surah;
  final int juz;
  final int hizb;
  final int rub;
  final int page;

  @override
  bool operator ==(Object other) =>
      other is QuranPosition &&
      other.address == address &&
      other.surah == surah &&
      other.juz == juz &&
      other.hizb == hizb &&
      other.rub == rub &&
      other.page == page;

  @override
  int get hashCode => Object.hash(address, surah, juz, hizb, rub, page);

  @override
  String toString() =>
      'QuranPosition($address: surah $surah, juz $juz, hizb $hizb, '
      'rub $rub, page $page)';
}
