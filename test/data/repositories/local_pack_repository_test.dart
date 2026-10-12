import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/verified_pack.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/packs/raw_pack.dart';
import '../../../testing/packs/synthetic_pack.dart';

final class _Verifier implements ManifestSignatureVerifier {
  _Verifier(this.answer);

  final SignatureCheck answer;
  final calls = <(Uint8List, Uint8List?)>[];

  @override
  Future<SignatureCheck> verify({
    required Uint8List manifest,
    required Uint8List? signature,
  }) async {
    calls.add((manifest, signature));
    return answer;
  }
}

/// Reads like [PackFileService] but fails with an I/O error on [failing].
final class _FailingFiles extends PackFileService {
  const _FailingFiles(this.failing);

  final String failing;

  Never _fail(String path) => throw FileSystemException('synthetic', path);

  @override
  Future<Uint8List?> readIfExists(String path) =>
      path.endsWith(failing) ? _fail(path) : super.readIfExists(path);

  @override
  Future<int?> sizeOf(String path) =>
      path.endsWith(failing) ? _fail(path) : super.sizeOf(path);
}

/// Reads like [PackFileService] and records each call, in order.
final class _SpyFiles extends PackFileService {
  _SpyFiles();

  final calls = <String>[];

  @override
  Future<Uint8List?> readIfExists(String path) {
    calls.add('readIfExists ${path.split('/').last}');
    return super.readIfExists(path);
  }

  @override
  Future<int?> sizeOf(String path) {
    calls.add('sizeOf ${path.split('/').last}');
    return super.sizeOf(path);
  }

  @override
  Future<String?> sha256Of(String path) {
    calls.add('sha256Of ${path.split('/').last}');
    return super.sha256Of(path);
  }
}

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('local_pack_repository_test');
  });
  tearDown(() => root.delete(recursive: true));

  LocalPackRepository repository({
    ManifestSignatureVerifier signatures = const SignatureNotConfigured(),
    PackFileService files = const PackFileService(),
  }) => LocalPackRepository(files: files, signatures: signatures);

  Matcher fails<T extends PackFailure>([
    Object? Function(T failure)? feature,
    Object? expected,
  ]) => isA<Failure<VerifiedPack>>().having(
    (failure) => failure.error,
    'error',
    feature == null ? isA<T>() : isA<T>().having(feature, 'failure', expected),
  );

  test('accepts a valid pack, its signature not checked', () async {
    final pack = await buildSyntheticPack(root);
    final result = await repository().verify(pack.directory.path);
    final verified = (result as Ok<VerifiedPack>).value;
    expect(verified.directory, pack.directory.path);
    expect(verified.manifest.id, pack.manifest['id']);
    expect(verified.manifest.files.single.name, textFileName);
    expect(verified.signatureChecked, isFalse);
  });

  group('signature', () {
    test('valid marks the pack checked', () async {
      final pack = await buildSyntheticPack(root);
      final result = await repository(
        signatures: _Verifier(SignatureCheck.valid),
      ).verify(pack.directory.path);
      expect((result as Ok<VerifiedPack>).value.signatureChecked, isTrue);
    });

    test('invalid rejects the pack before its manifest is parsed', () async {
      final pack = await buildSyntheticPack(
        root,
        fault: SyntheticFault.unsupportedFormatVersion,
      );
      expect(
        await repository(
          signatures: _Verifier(SignatureCheck.invalid),
        ).verify(pack.directory.path),
        fails<SignatureRejected>((f) => f.pack, pack.directory.path),
      );
    });

    test(
      'is given the exact manifest bytes, and the signature or null',
      () async {
        final pack = await buildSyntheticPack(root);
        final verifier = _Verifier(SignatureCheck.notChecked);
        await repository(signatures: verifier).verify(pack.directory.path);
        final signature = Uint8List.fromList(List.generate(64, (i) => i));
        await File(
          '${pack.directory.path}/manifest.json.sig',
        ).writeAsBytes(signature);
        await repository(signatures: verifier).verify(pack.directory.path);
        final manifest = await pack.manifestFile.readAsBytes();
        expect(verifier.calls.map((c) => c.$1), [manifest, manifest]);
        expect(verifier.calls.map((c) => c.$2), [null, signature]);
      },
    );
  });

  group('rejects', () {
    Future<void> expectFault(SyntheticFault fault, Matcher matcher) async {
      final pack = await buildSyntheticPack(root, fault: fault);
      expect(await repository().verify(pack.directory.path), matcher);
    }

    final fileMismatch = fails<FileHashMismatch>((f) => f.file, textFileName);

    test('a flipped byte', () async {
      await expectFault(SyntheticFault.flippedByte, fileMismatch);
    });

    test('a wrong file size', () async {
      await expectFault(SyntheticFault.wrongFileSize, fileMismatch);
    });

    test('a missing file, as a file whose bytes differ', () async {
      await expectFault(SyntheticFault.missingFile, fileMismatch);
    });

    test('a path in a file name', () async {
      await expectFault(
        SyntheticFault.pathInFileName,
        fails<ManifestUnreadable>(
          (f) => f.reason,
          'manifest.files[0].name is not a bare file name',
        ),
      );
    });

    test('an unsupported format version', () async {
      await expectFault(
        SyntheticFault.unsupportedFormatVersion,
        fails<UnsupportedPackFormat>((f) => f.formatVersion, 2),
      );
    });

    test('a directory with no manifest', () async {
      expect(
        await repository().verify(root.path),
        fails<ManifestUnreadable>((f) => (f.pack, f.reason), (
          root.path,
          'manifest.json is missing',
        )),
      );
      expect(root.listSync(), isEmpty);
    });

    test('a manifest that cannot be read', () async {
      final pack = await buildSyntheticPack(root);
      expect(
        await repository(
          files: const _FailingFiles('manifest.json'),
        ).verify(pack.directory.path),
        fails<ManifestUnreadable>(),
      );
    });

    test('a manifest whose id and version do not name its directory', () async {
      for (final (index, place) in [
        'synthetic-moved/2',
        'synthetic-other/1',
        'synthetic-moved/01',
      ].indexed) {
        final pack = await buildSyntheticPack(
          Directory('${root.path}/$index'),
          id: 'synthetic-moved',
        );
        final moved = Directory('${root.path}/$index/$place');
        await moved.parent.create(recursive: true);
        await pack.directory.rename(moved.path);
        expect(
          await repository().verify(moved.path),
          fails<ManifestUnreadable>((f) => (f.pack, f.reason), (
            moved.path,
            'id and version are synthetic-moved/1; the pack sits in $place',
          )),
          reason: place,
        );
      }
    });

    test('a data file that cannot be read', () async {
      final pack = await buildSyntheticPack(root);
      expect(
        await repository(
          files: const _FailingFiles(textFileName),
        ).verify(pack.directory.path),
        fileMismatch,
      );
    });
  });

  test('resolves a relative directory against the working directory', () async {
    final pack = await buildSyntheticPack(root);
    final previous = Directory.current;
    addTearDown(() => Directory.current = previous);
    Directory.current = pack.directory;
    expect(await repository().verify('.'), isA<Ok<VerifiedPack>>());
    Directory.current = pack.directory.parent;
    expect(await repository().verify('1/'), isA<Ok<VerifiedPack>>());
  });

  group('checks each file', () {
    test('by size, then by hash', () async {
      final pack = await buildSyntheticPack(root);
      final files = _SpyFiles();
      expect(
        await repository(files: files).verify(pack.directory.path),
        isA<Ok<VerifiedPack>>(),
      );
      expect(files.calls, [
        'readIfExists manifest.json',
        'readIfExists manifest.json.sig',
        'sizeOf $textFileName',
        'sha256Of $textFileName',
      ]);
    });

    test('without hashing a file whose size differs', () async {
      final pack = await buildSyntheticPack(
        root,
        fault: SyntheticFault.wrongFileSize,
      );
      final files = _SpyFiles();
      expect(
        await repository(files: files).verify(pack.directory.path),
        fails<FileHashMismatch>(),
      );
      expect(files.calls, contains('sizeOf $textFileName'));
      expect(files.calls.where((call) => call.startsWith('sha256Of')), isEmpty);
    });

    test('by size only in verifySizes', () async {
      final pack = await buildSyntheticPack(root);
      final files = _SpyFiles();
      expect(
        await repository(files: files).verifySizes(pack.directory.path),
        isA<Ok<VerifiedPack>>(),
      );
      expect(files.calls, [
        'readIfExists manifest.json',
        'readIfExists manifest.json.sig',
        'sizeOf $textFileName',
      ]);
    });

    test('verifySizes passes a changed byte and refuses a size', () async {
      final flipped = await buildSyntheticPack(
        Directory('${root.path}/flipped'),
        fault: SyntheticFault.flippedByte,
      );
      final resized = await buildSyntheticPack(
        Directory('${root.path}/resized'),
        fault: SyntheticFault.wrongFileSize,
      );
      expect(
        await repository().verifySizes(flipped.directory.path),
        isA<Ok<VerifiedPack>>(),
      );
      expect(
        await repository().verifySizes(resized.directory.path),
        fails<FileHashMismatch>(),
      );
    });
  });

  test('passes the faults found only once the file is open', () async {
    for (final fault in [
      SyntheticFault.wrongSurahHash,
      SyntheticFault.wrongCounts,
      SyntheticFault.leadingBom,
      SyntheticFault.walHeader,
      SyntheticFault.wrongApplicationId,
      SyntheticFault.wrongUserVersion,
      SyntheticFault.overlappingSpans,
      SyntheticFault.nonStrictSchema,
    ]) {
      final pack = await buildSyntheticPack(
        Directory('${root.path}/${fault.name}'),
        fault: fault,
      );
      expect(
        await repository().verify(pack.directory.path),
        isA<Ok<VerifiedPack>>(),
        reason: fault.name,
      );
    }
  });

  test('leaves the pack unchanged', () async {
    final pack = await buildSyntheticPack(root);
    final hash = await fileSha256(pack.textFile);
    final manifest = await pack.manifestFile.readAsBytes();
    await repository().verify(pack.directory.path);
    expect(await fileSha256(pack.textFile), hash);
    expect(await pack.manifestFile.readAsBytes(), manifest);
    expect(pack.directory.listSync(), hasLength(2));
  });
}
