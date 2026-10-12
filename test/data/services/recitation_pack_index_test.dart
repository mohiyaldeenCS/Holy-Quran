import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/services/recitation_pack_index.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/recitation_file.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../testing/packs/raw_pack.dart';
import '../../../testing/packs/synthetic_files.dart';
import '../../../testing/packs/synthetic_recitation_pack.dart';

// Every string is synthetic; non-ASCII characters are written as escapes.

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('recitation_pack_index_test');
  });
  tearDown(() => root.delete(recursive: true));

  RecitationPackIndex open(SyntheticRecitationPack pack) {
    final index = RecitationPackIndex.open(pack.file.path, formatVersion: 2);
    addTearDown(index.close);
    return index;
  }

  Matcher throwsFailure<T extends PackFailure>([
    Object? Function(T failure)? feature,
    Object? expected,
  ]) => throwsA(
    feature == null ? isA<T>() : isA<T>().having(feature, 'failure', expected),
  );

  void expectFile(RecitationFile file, SyntheticRecitationFile stored) {
    expect(file.qualityKbps, stored.qualityKbps);
    expect(file.part.name, stored.part);
    expect(file.surah, stored.surah);
    expect(file.ayah, stored.ayah);
    expect(file.path, stored.path);
    expect(file.bytes, stored.bytes);
    expect(file.sha256, stored.sha256);
    expect(file.duration?.inMilliseconds, stored.durationMs);
  }

  for (final unit in ['ayah', 'surah']) {
    group('a recitation by $unit', () {
      late SyntheticRecitationPack pack;
      late RecitationPackIndex index;

      setUp(() async {
        pack = await buildSyntheticRecitationPack(root, unit: unit);
        index = open(pack);
      });

      test('gives its facts, the texts byte for byte', () {
        final facts = index.recitation();
        expect(facts.reciter.verbatim, pack.reciter);
        expect(facts.style.verbatim, 'Synthetic style \u{E9}');
        expect(facts.unit.name, unit);
        expect(facts.baseUrl, Uri.parse(pack.baseUrl));
      });

      test('gives its qualities and the number of files', () {
        expect(index.qualities(), [64, 128]);
        expect(index.fileCount(), pack.files.length);
      });

      test('lists the files of each quality as stored', () {
        for (final quality in index.qualities()) {
          final stored = pack.files
              .where((f) => f.qualityKbps == quality)
              .toList();
          final files = index.files(quality);
          expect(files, hasLength(stored.length));
          final byPath = {for (final f in stored) f.path: f};
          for (final file in files) {
            expectFile(file, byPath[file.path]!);
          }
        }
        expect(index.files(32), isEmpty);
      });

      test(
        'lists the basmala and isti\'adha first, then by surah and ayah',
        () {
          final parts = index.files(128).map((f) => f.part).toList();
          expect(parts.take(2).toSet(), {
            RecitationFilePart.basmala,
            RecitationFilePart.istiadha,
          });
          final numbered = [
            for (final file in index.files(128).skip(2))
              (file.surah!, file.ayah ?? 0),
          ];
          expect(
            numbered,
            [...numbered]
              ..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2),
          );
        },
      );

      test('refuses a file of the other unit', () async {
        final faulty = open(
          await buildSyntheticRecitationPack(
            Directory('${root.path}/faulty'),
            unit: unit,
            fault: SyntheticRecitationFault.partOfOtherUnit,
          ),
        );
        expect(() => faulty.files(64), throwsFailure<PackInconsistent>());
        expect(faulty.files(128), isNotEmpty);
      });
    });
  }

  test('a file states its duration or none', () async {
    final pack = await buildSyntheticRecitationPack(root);
    final files = open(pack).files(64);
    expect(files.first.duration, isNull);
    expect(files.last.duration, isNotNull);
  });

  group('refuses', () {
    Future<RecitationPackIndex> faulty(SyntheticRecitationFault fault) async =>
        open(await buildSyntheticRecitationPack(root, fault: fault));

    for (final fault in [
      SyntheticRecitationFault.zeroBytes,
      SyntheticRecitationFault.upperCaseHash,
      SyntheticRecitationFault.parentPath,
    ]) {
      test('the fault ${fault.name}', () async {
        final index = await faulty(fault);
        expect(() => index.files(64), throwsFailure<PackInconsistent>());
      });
    }

    test('a base URL that is not https', () async {
      final index = await faulty(SyntheticRecitationFault.insecureBaseUrl);
      expect(index.recitation, throwsFailure<PackInconsistent>());
    });

    test('other base URLs and units, and a second recitation row', () async {
      final pack = await buildSyntheticRecitationPack(root);
      const changes = [
        "UPDATE recitation SET base_url = 'https://example.invalid/no-slash'",
        "UPDATE recitation SET base_url = 'https://example.invalid/a/?q=1'",
        "UPDATE recitation SET base_url = 'https://u@example.invalid/a/'",
        "UPDATE recitation SET base_url = '/relative/'",
        "UPDATE recitation SET unit = 'juz'",
        'INSERT INTO recitation SELECT * FROM recitation',
      ];
      for (final (number, change) in changes.indexed) {
        final copy = File('${root.path}/$number/$recitationFileName');
        await copy.parent.create();
        await pack.file.copy(copy.path);
        final writable = sqlite3.open(copy.path);
        try {
          writable
            ..execute('PRAGMA ignore_check_constraints = ON')
            ..execute(change);
        } finally {
          writable.close();
        }
        final index = RecitationPackIndex.open(copy.path, formatVersion: 2);
        addTearDown(index.close);
        expect(
          index.recitation,
          throwsFailure<PackInconsistent>(),
          reason: change,
        );
      }
    });

    test('a format version other than 2', () async {
      final pack = await buildSyntheticRecitationPack(root);
      for (final version in [1, 3]) {
        expect(
          () =>
              RecitationPackIndex.open(pack.file.path, formatVersion: version),
          throwsFailure<UnsupportedPackFormat>((f) => f.formatVersion, version),
        );
      }
    });
  });

  test('reading leaves the file unchanged', () async {
    final pack = await buildSyntheticRecitationPack(root);
    final hash = await fileSha256(pack.file);
    final index = open(pack)..recitation();
    for (final quality in index.qualities()) {
      index.files(quality);
    }
    expect(await fileSha256(pack.file), hash);
    expect(
      pack.directory.listSync().map((e) => e.uri.pathSegments.last).toSet(),
      {recitationFileName, manifestFileName},
    );
  });
}
