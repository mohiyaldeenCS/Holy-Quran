import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/domain/models/verified_pack.dart';
import 'package:holyquran/utils/result.dart';

import '../../testing/packs/raw_pack.dart';
import '../../testing/packs/synthetic_pack.dart' show textFileName;
import 'pack_integrity_suite.dart' show expectNoProblems;

/// A pack of a kind other than text, verified through the production path
/// and opened by the independent reader, with the text pack its addresses
/// are checked against when one is given.
final class PackFileUnderTest {
  PackFileUnderTest._(
    this.directory,
    this.file,
    this.verification,
    this._raw,
    this._rawError,
    this.text,
    this.textRiwaya,
  );

  static Future<PackFileUnderTest> load(
    String directory,
    String fileName, {
    String? textPackDirectory,
  }) async {
    final verification = await const LocalPackRepository(
      files: PackFileService(),
      signatures: SignatureNotConfigured(),
    ).verify(directory);
    final file = File('$directory/$fileName');
    RawPack? raw;
    Exception? rawError;
    try {
      raw = RawPack.open(file);
    } on Exception catch (error) {
      rawError = error;
    }
    return PackFileUnderTest._(
      directory,
      file,
      verification,
      raw,
      rawError,
      textPackDirectory == null
          ? null
          : RawPack.open(File('$textPackDirectory/$textFileName')),
      textPackDirectory == null
          ? null
          : switch (jsonDecode(
              await File('$textPackDirectory/manifest.json').readAsString(),
            )) {
              {'kind': 'text', 'riwaya': final String riwaya} => riwaya,
              _ => null,
            },
    );
  }

  final String directory;
  final File file;
  final Result<VerifiedPack> verification;
  final RawPack? _raw;
  final Exception? _rawError;

  /// The text pack of the same riwaya, when one was given.
  final RawPack? text;

  /// The riwaya the text pack's manifest names, when it is a text pack.
  final String? textRiwaya;
  final _closers = <void Function()>[];

  VerifiedPack get verified => switch (verification) {
    Ok(:final value) => value,
    Failure(:final error) => fail('The pack was not verified: $error'),
  };

  PackManifest get manifest => verified.manifest;

  RawPack get raw =>
      _raw ??
      fail('The independent reader could not open the pack: $_rawError');

  /// The ayah count of each surah of [text], by surah number.
  Map<int, int> get ayahCounts => {
    for (final surah in text!.surahs()) surah.number: surah.ayahCount,
  };

  /// Closes [close] with the pack.
  void onClose(void Function() close) => _closers.add(close);

  void close() {
    for (final close in _closers) {
      close();
    }
    _raw?.close();
    text?.close();
  }
}

typedef PackFileCheck = Future<List<String>> Function(PackFileUnderTest pack);

Future<List<String>> textRiwayaProblems(PackFileUnderTest pack) async {
  final (text, own) = (pack.textRiwaya, pack.manifest.riwaya);
  return [if (text != own) 'the text pack is of riwaya $text, not $own'];
}

/// Defines the tests of [checks] for the pack in the directory
/// [packDirectory] completes with, its data file [fileName]. The checks of
/// [textChecks] run only when [textPackDirectory] completes with a
/// directory.
void definePackFileSuite(
  String description,
  String fileName,
  Future<String> Function() packDirectory, {
  required Map<String, PackFileCheck> checks,
  required Map<String, PackFileCheck> textChecks,
  Future<String?> Function()? textPackDirectory,
}) {
  group(description, () {
    PackFileUnderTest? loaded;
    PackFileUnderTest pack() => loaded ?? fail('The pack was not loaded.');

    setUpAll(
      () async => loaded = await PackFileUnderTest.load(
        await packDirectory(),
        fileName,
        textPackDirectory: await textPackDirectory?.call(),
      ),
    );
    tearDownAll(() => loaded?.close());

    test('passes verification', () {
      final verification = pack().verification;
      expect(
        verification,
        isA<Ok<VerifiedPack>>(),
        reason: switch (verification) {
          Failure(:final error) => '$error',
          Ok() => null,
        },
      );
    });

    for (final MapEntry(key: name, value: check) in checks.entries) {
      test(name, () async => expectNoProblems(await check(pack())));
    }
    final withText = {
      'is checked against a text pack of its riwaya': textRiwayaProblems,
      ...textChecks,
    };
    for (final MapEntry(key: name, value: check) in withText.entries) {
      test(name, () async {
        if (pack().text == null) {
          markTestSkipped('no text pack was given to check addresses against');
          return;
        }
        expectNoProblems(await check(pack()));
      });
    }
  });
}
