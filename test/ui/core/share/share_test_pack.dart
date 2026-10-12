import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../testing/packs/synthetic_pack.dart';
import '../../../integrity/pack_integrity_suite.dart';

/// A synthetic phrase, «نص تجريبي», written as escapes.
const _phrase = '\u{646}\u{635} \u{62A}\u{62C}\u{631}\u{64A}\u{628}\u{64A}';

/// The default synthetic surahs with ayat of every length added to each, from
/// one phrase to far more than the tall card holds, so that the 50 shortest
/// and the 50 longest differ and some fit no card.
final shareTestSurahs = [
  for (final (index, surah) in defaultSyntheticSurahs.indexed)
    SyntheticSurah(
      name: surah.name,
      basmala: surah.basmala,
      revelationPlace: surah.revelationPlace,
      revelationOrder: surah.revelationOrder,
      ayat: [
        ...surah.ayat,
        for (var length = 1 + index; length <= 120; length += 3)
          SyntheticAyah(List.filled(length, _phrase).join(' ')),
      ],
    ),
];

/// An ayah of a pack as the repository gives it, with its surah's name, and
/// the bytes the independent reader finds for both.
typedef PackAyah = ({
  QuranAddress address,
  PackText text,
  Uint8List stored,
  PackText surahName,
  Uint8List storedName,
});

/// Every ayah of [pack] in stored order, through its repository.
Future<List<PackAyah>> packAyat(
  PackUnderTest pack,
  QuranTextRepository repository,
) async {
  T ok<T>(Result<T> result, String what) => switch (result) {
    Ok(:final value) => value,
    Failure(:final error) => fail('$what: $error'),
  };
  final names = {
    for (final surah in ok(await repository.surahs(), 'surah list'))
      surah.number: surah.name,
  };
  return [
    for (final row in pack.raw.surahs())
      for (final (number, bytes) in pack.raw.ayat(row.number))
        (
          address: QuranAddress(repository.riwaya, row.number, number),
          text: ok(
            await repository.ayahText(
              QuranAddress(repository.riwaya, row.number, number),
            ),
            '${row.number}:$number',
          ),
          stored: bytes,
          surahName: names[row.number] ?? fail('surah ${row.number}'),
          storedName: row.name,
        ),
  ];
}

/// The [count] shortest and [count] longest of [ayat] by stored length.
List<PackAyah> shortestAndLongest(List<PackAyah> ayat, int count) {
  final sorted = [...ayat]
    ..sort((a, b) => a.stored.length.compareTo(b.stored.length));
  if (sorted.length <= 2 * count) return sorted;
  return [...sorted.take(count), ...sorted.skip(sorted.length - count)];
}

/// Builds the share test pack under a new temporary directory and loads it;
/// [tearDownAll] removes it.
Future<PackUnderTest> loadShareTestPack() async {
  final root = await Directory.systemTemp.createTemp('share_test_pack');
  final built = await buildSyntheticPack(root, surahs: shareTestSurahs);
  final pack = await PackUnderTest.load(built.directory.path);
  addTearDown(() async {
    pack.close();
    await root.delete(recursive: true);
  });
  return pack;
}

/// The pack given with `--dart-define=HOLYQURAN_PACK_DIR=<pack-id/version>`,
/// as the integrity suite takes it; empty when none is given.
const givenPackDirectory = String.fromEnvironment('HOLYQURAN_PACK_DIR');
