import 'dart:io';

import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/utils/result.dart';

import '../../testing/packs/synthetic_pack.dart';
import 'widget_publisher.dart';

// The synthetic pack of the S4 publishing tests: repeats of a synthetic
// phrase written as escapes, never Quran text, read back through the app's
// verifying repositories.

/// «نص تجريبي».
const String widgetTestPhrase =
    '\u{646}\u{635} \u{62A}\u{62C}\u{631}\u{64A}\u{628}\u{64A}';

String _repeat(int n) => List.filled(n, widgetTestPhrase).join(' ');

/// «سورة تجريبية».
const String _secondName =
    '\u{633}\u{648}\u{631}\u{629} '
    '\u{62A}\u{62C}\u{631}\u{64A}\u{628}\u{64A}\u{629}';

/// «اسم تجريبي», «سورة تجريبية» and «اسم».
const List<String> widgetTestSurahNames = [
  '\u{627}\u{633}\u{645} \u{62A}\u{62C}\u{631}\u{64A}\u{628}\u{64A}',
  _secondName,
  '\u{627}\u{633}\u{645}',
];

/// From one phrase to more than either face holds, in the surah shapes the
/// default divisions and sajdas need.
final List<SyntheticSurah> _surahs = [
  SyntheticSurah(
    name: widgetTestSurahNames[0],
    ayat: [
      for (final n in [1, 30, 2, 3]) SyntheticAyah(_repeat(n)),
    ],
  ),
  SyntheticSurah(
    name: widgetTestSurahNames[1],
    ayat: [
      for (final n in [5, 1, 8]) SyntheticAyah(_repeat(n)),
    ],
  ),
  SyntheticSurah(
    name: widgetTestSurahNames[2],
    ayat: [SyntheticAyah(_repeat(2))],
  ),
];

typedef WidgetTestPack = ({
  List<WidgetAyah> ayat,
  String textSha256,
  void Function() close,
});

/// Every ayah of the synthetic pack built under [root], in order, and the
/// verified manifest's digest of its text file.
Future<WidgetTestPack> loadWidgetTestPack(Directory root) async {
  final built = await buildSyntheticPack(root, surahs: _surahs);
  final verified = _ok(
    await const LocalPackRepository(
      files: PackFileService(),
      signatures: SignatureNotConfigured(),
    ).verify(built.directory.path),
  );
  final repository = _ok(PackQuranTextRepository.open(verified));
  final ayat = <WidgetAyah>[
    for (final surah in _ok(await repository.surahs()))
      for (var ayah = 1; ayah <= surah.ayahCount; ayah++)
        (
          address: QuranAddress(repository.riwaya, surah.number, ayah),
          ayah: _ok(
            await repository.ayahText(
              QuranAddress(repository.riwaya, surah.number, ayah),
            ),
          ),
          surahName: surah.name,
        ),
  ];
  return (
    ayat: ayat,
    textSha256: verified.manifest.files
        .singleWhere((file) => file.name == textFileName)
        .sha256,
    close: repository.close,
  );
}

T _ok<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Failure(:final error) => throw StateError('$error'),
};
