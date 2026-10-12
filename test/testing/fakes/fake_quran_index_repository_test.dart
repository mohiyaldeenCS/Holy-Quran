import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/domain/models/verified_pack.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_quran_index_repository.dart';
import '../../../testing/packs/synthetic_pack.dart';

void main() {
  test('the synthetic fake answers as the default synthetic pack', () async {
    final root = await Directory.systemTemp.createTemp('fake_index_test');
    addTearDown(() => root.delete(recursive: true));
    final pack = await buildSyntheticPack(root);
    const verifier = LocalPackRepository(
      files: PackFileService(),
      signatures: SignatureNotConfigured(),
    );
    final verified =
        (await verifier.verify(pack.directory.path) as Ok<VerifiedPack>).value;
    final text =
        (PackQuranTextRepository.open(verified) as Ok<PackQuranTextRepository>)
            .value;
    addTearDown(text.close);
    final real =
        (PackQuranIndexRepository.build(
                  riwaya: text.riwaya,
                  surahs: (await text.surahs() as Ok<List<SurahInfo>>).value,
                  map: (await text.editionMap() as Ok<EditionMap>).value,
                )
                as Ok<PackQuranIndexRepository>)
            .value;
    final fake = FakeQuranIndexRepository.synthetic();

    expect(fake.riwaya, real.riwaya);
    expect(fake.surahCount, real.surahCount);
    for (var surah = 1; surah <= real.surahCount; surah++) {
      expect(fake.ayahCount(surah), real.ayahCount(surah));
      expect(fake.nextSurah(surah), real.nextSurah(surah));
      expect(fake.firstPage(surah), real.firstPage(surah));
      expect(fake.pageStartsIn(surah), real.pageStartsIn(surah));
      for (var ayah = 1; ayah <= real.ayahCount(surah); ayah++) {
        final address = QuranAddress('hafs', surah, ayah);
        expect(fake.positionOf(address), real.positionOf(address));
        expect(fake.isSajda(address), real.isSajda(address));
      }
    }
    for (final division in Division.values) {
      expect(fake.divisions(division), real.divisions(division));
    }
    expect(fake.sajdas, real.sajdas);
  });
}
