import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../testing/packs/synthetic_pack.dart';
import '../../testing/packs/synthetic_recitation_pack.dart';
import '../../testing/packs/synthetic_tafsir_pack.dart';
import 'pack_file_suite.dart';
import 'pack_integrity_suite.dart';
import 'recitation_pack_integrity_suite.dart';
import 'tafsir_pack_integrity_suite.dart';

// The integrity suites on synthetic packs of format 2, and each fault shown
// to be caught by the check written for it.

void main() {
  late Directory root;
  late String textPack;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('synthetic_v2_integrity');
    textPack = (await buildSyntheticPack(
      Directory('${root.path}/text'),
    )).directory.path;
  });
  tearDownAll(() => root.delete(recursive: true));

  definePackIntegritySuite(
    'a synthetic format 2 text pack',
    () async => (await buildSyntheticPack(
      Directory('${root.path}/v2'),
      formatVersion: 2,
    )).directory.path,
  );

  definePackIntegritySuite(
    'a synthetic format 2 text pack without search forms',
    () async => (await buildSyntheticPack(
      Directory('${root.path}/v2-none'),
      formatVersion: 2,
      searchFormKinds: const [],
    )).directory.path,
  );

  defineTafsirPackIntegritySuite(
    'a synthetic tafsir pack',
    () async => (await buildSyntheticTafsirPack(
      Directory('${root.path}/tafsir'),
    )).directory.path,
    textPackDirectory: () async => textPack,
  );

  for (final unit in ['ayah', 'surah']) {
    defineRecitationPackIntegritySuite(
      'a synthetic recitation pack by $unit',
      () async => (await buildSyntheticRecitationPack(
        Directory('${root.path}/recitation-$unit'),
        unit: unit,
      )).directory.path,
      textPackDirectory: () async => textPack,
    );
  }

  group('the search form check finds the fault', () {
    for (final fault in SyntheticSearchFormFault.values) {
      test(fault.name, () async {
        final pack = await PackUnderTest.load(
          (await buildSyntheticPack(
            Directory('${root.path}/form-${fault.name}'),
            formatVersion: 2,
            searchFormFault: fault,
          )).directory.path,
        );
        addTearDown(pack.close);
        expect(await searchFormProblems(pack), isNotEmpty);
      });
    }
  });

  Future<List<String>> problemsOf(
    String name,
    String fileName,
    Future<String> Function() build,
    PackFileCheck check,
  ) async {
    final pack = await PackFileUnderTest.load(
      await build(),
      fileName,
      textPackDirectory: textPack,
    );
    addTearDown(pack.close);
    return check(pack);
  }

  test('the riwaya check finds a text pack of another riwaya', () async {
    final other = await Directory(
      '${root.path}/warsh/text/1',
    ).create(recursive: true);
    await File('$textPack/$textFileName').copy('${other.path}/$textFileName');
    final manifest =
        jsonDecode(await File('$textPack/$manifestFileName').readAsString())
            as Map<String, Object?>;
    await File(
      '${other.path}/$manifestFileName',
    ).writeAsString(jsonEncode({...manifest, 'riwaya': 'warsh'}));
    final tafsir = await buildSyntheticTafsirPack(
      Directory('${root.path}/tafsir-warsh'),
    );
    final pack = await PackFileUnderTest.load(
      tafsir.directory.path,
      tafsirFileName,
      textPackDirectory: other.path,
    );
    addTearDown(pack.close);
    expect(await textRiwayaProblems(pack), [
      'the text pack is of riwaya warsh, not hafs',
    ]);
  });

  group('the tafsir checks find the fault', () {
    final checks = <SyntheticTafsirFault, PackFileCheck>{
      SyntheticTafsirFault.overlappingPassages: tafsirRangeProblems,
      SyntheticTafsirFault.reversedRange: tafsirRangeProblems,
      SyntheticTafsirFault.passageOutsideText: tafsirTextProblems,
      SyntheticTafsirFault.wrongPassageCount: tafsirNumberingProblems,
      SyntheticTafsirFault.twoBookRows: tafsirBookProblems,
      SyntheticTafsirFault.leadingBom: tafsirTextBytesProblems,
    };
    test('every fault has a check', () {
      expect(checks.keys.toSet(), SyntheticTafsirFault.values.toSet());
    });
    for (final MapEntry(key: fault, value: check) in checks.entries) {
      test(fault.name, () async {
        expect(
          await problemsOf(
            fault.name,
            tafsirFileName,
            () async => (await buildSyntheticTafsirPack(
              Directory('${root.path}/tafsir-${fault.name}'),
              fault: fault,
            )).directory.path,
            check,
          ),
          isNotEmpty,
        );
      });
    }
  });

  group('the recitation checks find the fault', () {
    final checks = <SyntheticRecitationFault, PackFileCheck>{
      SyntheticRecitationFault.zeroBytes: recitationFileProblems,
      SyntheticRecitationFault.upperCaseHash: recitationFileProblems,
      SyntheticRecitationFault.duplicateBasmala: recitationPartProblems,
      SyntheticRecitationFault.partOfOtherUnit: recitationPartProblems,
      SyntheticRecitationFault.fileOutsideText: recitationTextProblems,
      SyntheticRecitationFault.wrongFileCount: recitationFileProblems,
      SyntheticRecitationFault.insecureBaseUrl: recitationFactsProblems,
      SyntheticRecitationFault.parentPath: recitationFileProblems,
    };
    test('every fault has a check', () {
      expect(checks.keys.toSet(), SyntheticRecitationFault.values.toSet());
    });
    for (final unit in ['ayah', 'surah']) {
      for (final MapEntry(key: fault, value: check) in checks.entries) {
        test('${fault.name} by $unit', () async {
          expect(
            await problemsOf(
              fault.name,
              recitationFileName,
              () async => (await buildSyntheticRecitationPack(
                Directory('${root.path}/recitation-${fault.name}-$unit'),
                unit: unit,
                fault: fault,
              )).directory.path,
              check,
            ),
            isNotEmpty,
          );
        });
      }
    }
  });
}
