import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/services/pack_file_service.dart';

void main() {
  const service = PackFileService();
  late Directory root;
  late File file;
  late Uint8List bytes;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('pack_file_service_test');
    final random = Random(7);
    // Larger than one read chunk, so the hash is streamed in several parts.
    bytes = Uint8List.fromList([
      for (var i = 0; i < 3 * 65536 + 17; i++) random.nextInt(256),
    ]);
    file = await File('${root.path}/data.bin').writeAsBytes(bytes);
  });
  tearDown(() => root.delete(recursive: true));

  String missing() => '${root.path}/missing.bin';

  test(
    'readIfExists returns the bytes, or null when there is no file',
    () async {
      expect(await service.readIfExists(file.path), bytes);
      expect(await service.readIfExists(missing()), isNull);
      expect(File(missing()).existsSync(), isFalse);
    },
  );

  test('sizeOf returns the size, or null when there is no file', () async {
    expect(await service.sizeOf(file.path), bytes.length);
    expect(await service.sizeOf(missing()), isNull);
  });

  test('sha256Of returns lowercase hex SHA-256 of the whole file', () async {
    final hash = await service.sha256Of(file.path);
    expect(hash, sha256.convert(bytes).toString());
    expect(hash, matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('sha256Of hashes an empty file and returns null for none', () async {
    final empty = await File('${root.path}/empty.bin').create();
    expect(await service.sha256Of(empty.path), sha256.convert([]).toString());
    expect(await service.sha256Of(missing()), isNull);
    expect(File(missing()).existsSync(), isFalse);
  });

  test('reading leaves the file unchanged', () async {
    final modified = file.lastModifiedSync();
    await service.readIfExists(file.path);
    await service.sizeOf(file.path);
    await service.sha256Of(file.path);
    expect(file.readAsBytesSync(), bytes);
    expect(file.lastModifiedSync(), modified);
    expect(root.listSync().map((e) => e.path), [file.path]);
  });

  test('an error other than a missing file is thrown', () async {
    expect(
      service.readIfExists(root.path),
      throwsA(isA<FileSystemException>()),
    );
  });
}
