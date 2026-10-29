import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/domain/use_cases/is_ayah_of_pack.dart';

void main() {
  final surahs = [
    for (final (number, ayat) in [(1, 4), (2, 3)])
      SurahInfo(
        number: number,
        name: PackText.fromPack('Synthetic surah $number'),
        ayahCount: ayat,
      ),
  ];

  bool inPack(QuranAddress address, [List<SurahInfo>? served]) =>
      isAyahOfPack(address, riwaya: 'hafs', surahs: served ?? surahs);

  test('accepts the first and the last ayah of each surah', () {
    for (final (surah, ayah) in [(1, 1), (1, 4), (2, 1), (2, 3)]) {
      expect(inPack(QuranAddress('hafs', surah, ayah)), isTrue);
    }
  });

  test('refuses another riwaya, a surah or an ayah beyond the pack', () {
    for (final address in [
      QuranAddress('warsh', 1, 1),
      QuranAddress('hafs', 3, 1),
      QuranAddress('hafs', 1, 5),
      QuranAddress('hafs', 2, 4),
    ]) {
      expect(inPack(address), isFalse, reason: '$address');
    }
  });

  test('refuses everything while the pack serves no surahs', () {
    expect(inPack(QuranAddress('hafs', 1, 1), const []), isFalse);
  });
}
