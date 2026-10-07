import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/verified_pack.dart';
import 'package:holyquran/utils/result.dart';

import '../../testing/packs/synthetic_pack.dart';

// The rejection row of PRD section 9.4: each faulty synthetic pack is refused
// through the production path (verify, open, read), and once a pack is
// refused while being read, no text of it comes out.

/// How far the production path got with a pack.
final class _Outcome {
  _Outcome(this.step, this.failure, this.repository, this.texts);

  final String? step;
  final PackFailure? failure;

  /// The repository, when the failure came while reading.
  final PackQuranTextRepository? repository;

  /// Every text read before the failure, by where it was read.
  final Map<String, PackText> texts;
}

Future<_Outcome> _readThrough(SyntheticPack pack) async {
  final texts = <String, PackText>{};
  const verifier = LocalPackRepository(
    files: PackFileService(),
    signatures: SignatureNotConfigured(),
  );
  final VerifiedPack verified;
  switch (await verifier.verify(pack.directory.path)) {
    case Ok(:final value):
      verified = value;
    case Failure(:final error):
      return _Outcome('verify', error as PackFailure, null, texts);
  }
  final PackQuranTextRepository repository;
  switch (PackQuranTextRepository.open(verified)) {
    case Ok(:final value):
      repository = value;
    case Failure(:final error):
      return _Outcome('open', error as PackFailure, null, texts);
  }
  addTearDown(repository.close);
  _Outcome failed(Exception error) =>
      _Outcome('read', error as PackFailure, repository, texts);

  switch (await repository.surahs()) {
    case Failure(:final error):
      return failed(error);
    case Ok(:final value):
      for (final surah in value) {
        texts['surah ${surah.number} name'] = surah.name;
      }
  }
  for (final (index, surah) in pack.surahs.indexed) {
    final number = index + 1;
    switch (await repository.basmala(number)) {
      case Failure(:final error):
        return failed(error);
      case Ok(:final value):
        if (value != null) texts['surah $number basmala'] = value;
    }
    for (var ayah = 1; ayah <= surah.ayat.length; ayah++) {
      final address = QuranAddress(repository.riwaya, number, ayah);
      switch (await repository.ayahText(address)) {
        case Failure(:final error):
          return failed(error);
        case Ok(:final value):
          texts['$address'] = value;
      }
      if (await repository.words(address) case Failure(:final error)) {
        return failed(error);
      }
    }
  }
  if (await repository.editionMap() case Failure(:final error)) {
    return failed(error);
  }
  return _Outcome(null, null, repository, texts);
}

/// What the pack stores, by the keys [_readThrough] uses.
Map<String, String> _stored(SyntheticPack pack) => {
  for (final (index, surah) in pack.surahs.indexed) ...{
    'surah ${index + 1} name': surah.name,
    'surah ${index + 1} basmala': ?surah.basmala,
    for (final (a, ayah) in surah.ayat.indexed)
      'hafs:${index + 1}:${a + 1}': ayah.text,
  },
};

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('pack_rejection_test');
  });
  tearDown(() => root.delete(recursive: true));

  final expected = <SyntheticFault, (String, TypeMatcher<PackFailure>)>{
    SyntheticFault.flippedByte: ('verify', isA<FileHashMismatch>()),
    SyntheticFault.wrongSurahHash: ('read', isA<SurahHashMismatch>()),
    SyntheticFault.wrongCounts: ('read', isA<PackInconsistent>()),
    SyntheticFault.leadingBom: ('read', isA<TextEncodingRejected>()),
    SyntheticFault.walHeader: ('open', isA<UnsupportedPackFormat>()),
    SyntheticFault.wrongApplicationId: ('open', isA<UnsupportedPackFormat>()),
    SyntheticFault.wrongUserVersion: ('open', isA<UnsupportedPackFormat>()),
    SyntheticFault.unsupportedFormatVersion: (
      'verify',
      isA<UnsupportedPackFormat>(),
    ),
    SyntheticFault.pathInFileName: ('verify', isA<ManifestUnreadable>()),
    SyntheticFault.missingFile: ('verify', isA<FileHashMismatch>()),
    SyntheticFault.wrongFileSize: ('verify', isA<FileHashMismatch>()),
    SyntheticFault.overlappingSpans: ('read', isA<PackInconsistent>()),
    SyntheticFault.nonStrictSchema: ('open', isA<UnsupportedPackFormat>()),
  };

  test('every synthetic fault is listed', () {
    expect(expected.keys.toSet(), SyntheticFault.values.toSet());
  });

  test('a valid pack is read through, every text as stored', () async {
    final pack = await buildSyntheticPack(root);
    final outcome = await _readThrough(pack);
    expect(outcome.failure, isNull);
    expect({
      for (final MapEntry(:key, :value) in outcome.texts.entries)
        key: value.verbatim,
    }, _stored(pack));
  });

  for (final MapEntry(key: fault, value: (step, failure)) in expected.entries) {
    test('${fault.name} is refused at $step, and no text comes out '
        'afterwards', () async {
      final pack = await buildSyntheticPack(root, fault: fault);
      final outcome = await _readThrough(pack);
      expect(outcome.step, step);
      expect(outcome.failure, failure);

      final stored = _stored(pack);
      for (final MapEntry(:key, :value) in outcome.texts.entries) {
        expect(
          utf8.encode(value.verbatim),
          utf8.encode(stored[key]!),
          reason: key,
        );
      }

      final repository = outcome.repository;
      if (repository == null) {
        expect(outcome.texts, isEmpty);
        return;
      }
      final disabled = isA<Failure<Object?>>().having(
        (f) => f.error,
        'error',
        isA<PackDisabled>(),
      );
      expect(await repository.surahs(), disabled);
      expect(await repository.editionMap(), disabled);
      for (final (index, surah) in pack.surahs.indexed) {
        expect(await repository.basmala(index + 1), disabled);
        for (var ayah = 1; ayah <= surah.ayat.length; ayah++) {
          final address = QuranAddress(repository.riwaya, index + 1, ayah);
          expect(
            await repository.ayahText(address),
            disabled,
            reason: '$address',
          );
          expect(await repository.words(address), disabled, reason: '$address');
          expect(
            await repository.contains(address),
            disabled,
            reason: '$address',
          );
        }
      }
    });
  }
}
