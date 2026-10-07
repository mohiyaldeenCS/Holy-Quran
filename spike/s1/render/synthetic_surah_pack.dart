import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/packs/synthetic_pack.dart' show amiriQuranFontPath;
import '../text/gibberish.dart';
import '../text/spike_pack_writer.dart';
import '../text/tanzil_fixture.dart';
import '../text/tanzil_xml.dart';
import 'spike_surah_text.dart';

/// The surahs of the synthetic pack: a long one with a basmala and one
/// page every 10 ayat (the spike writer's synthetic divisions), and a short
/// one without a basmala. Every value is Arabic-script nonsense.
const syntheticLongSurah = 1;
const syntheticShortSurah = 2;
const syntheticLongAyat = 286;

/// Writes a spike pack of nonsense under [root] with the spike writer,
/// verifies it with [LocalPackRepository] and opens it with
/// [PackQuranTextRepository], as the app would.
Future<PackQuranTextRepository> openSyntheticSpikePack(
  Directory root, {
  int seed = 7,
}) async {
  final nonsense = SyntheticArabicScript(seed);
  final lengths = Random(seed);
  final bytes = tanzilFixtureXml([
    (
      name: nonsense.word(),
      bismillah: nonsense.phrase(4),
      ayat: [
        for (var a = 0; a < syntheticLongAyat; a++)
          nonsense.phrase(3 + lengths.nextInt(28)),
      ],
    ),
    (
      name: nonsense.word(),
      bismillah: null,
      ayat: [
        for (var a = 0; a < 6; a++) nonsense.phrase(2 + lengths.nextInt(6)),
      ],
    ),
  ]);
  final xml = readTanzilXml(bytes);
  final directory = await writeSpikePack(
    root,
    surahs: spikeSurahsOf(xml),
    fontSha256: sha256
        .convert(File(amiriQuranFontPath).readAsBytesSync())
        .toString(),
    source: (
      bytes: bytes,
      url: 'https://example.invalid/synthetic.xml',
      version: tanzilUthmaniVersion,
      fetchedOn: '2026-01-01',
      notice: xml.notice,
    ),
  );
  final verified = switch (await const LocalPackRepository(
    files: PackFileService(),
    signatures: SignatureNotConfigured(),
  ).verify(directory)) {
    Ok(:final value) => value,
    Failure(:final error) => throw StateError('verify failed: $error'),
  };
  return switch (PackQuranTextRepository.open(verified)) {
    Ok(:final value) => value,
    Failure(:final error) => throw StateError('open failed: $error'),
  };
}

/// Both synthetic surahs, read through the repository.
Future<
  ({SpikeSurahText long, SpikeSurahText short, PackQuranTextRepository pack})
>
readSyntheticSurahs(Directory root) async {
  final pack = await openSyntheticSpikePack(root);
  return (
    long: await readSpikeSurahText(pack, syntheticLongSurah),
    short: await readSpikeSurahText(pack, syntheticShortSurah),
    pack: pack,
  );
}
