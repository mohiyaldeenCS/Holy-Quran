import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../testing/flows/flow_pack.dart';
import '../../testing/packs/synthetic_pack.dart';

// A device has no repository: the pack builder must not need the font's path.

void main() {
  late Directory root;
  late Directory elsewhere;
  late Directory start;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('font_bytes_pack');
    elsewhere = await Directory.systemTemp.createTemp('font_bytes_cwd');
    start = Directory.current;
  });
  tearDown(() async {
    Directory.current = start;
    await root.delete(recursive: true);
    await elsewhere.delete(recursive: true);
  });

  Future<List<int>> fontBytesThenLeaveTheRepository() async {
    final bytes = await File('${start.path}/$amiriQuranFontPath').readAsBytes();
    Directory.current = elsewhere;
    expect(File(amiriQuranFontPath).existsSync(), isFalse);
    return bytes;
  }

  test(
    'the pack is built from given font bytes outside the repository',
    () async {
      final bytes = await fontBytesThenLeaveTheRepository();
      final fontBytes = Uint8List.fromList(bytes);

      final pack = await buildSyntheticPack(root, fontBytes: fontBytes);

      expect(
        (pack.manifest['font']! as Map)['sha256'],
        sha256.convert(bytes).toString(),
      );
    },
  );

  test('the flows\' pack is built from given font bytes outside the '
      'repository', () async {
    final bytes = await fontBytesThenLeaveTheRepository();

    final pack = await buildFlowPack(
      root,
      fontBytes: Uint8List.fromList(bytes),
    );

    expect(
      (pack.manifest['font']! as Map)['sha256'],
      sha256.convert(bytes).toString(),
    );
  });

  test('without the bytes the font is read from the repository', () async {
    final bytes = await File(amiriQuranFontPath).readAsBytes();

    final pack = await buildSyntheticPack(root);

    expect(
      (pack.manifest['font']! as Map)['sha256'],
      sha256.convert(bytes).toString(),
    );
  });
}
