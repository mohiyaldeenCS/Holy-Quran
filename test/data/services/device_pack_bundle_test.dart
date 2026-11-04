import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/services/device_pack_bundle.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('device_pack_bundle');
    Directory('${root.path}/unapproved-x/1').createSync(recursive: true);
    File('${root.path}/unapproved-x/1/text.sqlite')
        .writeAsBytesSync([0, 1, 2, 255, 10, 13]);
    File('${root.path}/secret.txt').writeAsBytesSync([1]);
  });
  tearDown(() => root.deleteSync(recursive: true));

  DevicePackBundle bundle() => DevicePackBundle(() async => root);

  test('serves assets/packs/<id>/<version>/<name> from the root', () async {
    final data = await bundle().load('assets/packs/unapproved-x/1/text.sqlite');
    expect(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      Uint8List.fromList([0, 1, 2, 255, 10, 13]),
    );
  });

  test('a file that is not there fails like the root bundle', () async {
    expect(
      bundle().load('assets/packs/unapproved-x/1/manifest.json'),
      throwsA(isA<FlutterError>()),
    );
    expect(
      bundle().load('assets/packs/unapproved-y/1/text.sqlite'),
      throwsA(isA<FlutterError>()),
    );
  });

  test('refuses any other key', () async {
    for (final key in [
      'text.sqlite',
      'assets/fonts/x.ttf',
      'assets/packs/unapproved-x/text.sqlite',
      'assets/packs/unapproved-x/1/sub/text.sqlite',
      'assets/packs/unapproved-x/1/',
      'assets/packs//1/text.sqlite',
      'assets/packs/../secret.txt',
      'assets/packs/unapproved-x/../secret.txt',
      'assets/packs/unapproved-x/1/..',
      'assets/packs/./1/text.sqlite',
      r'assets/packs/unapproved-x/1/..\secret.txt',
      '/assets/packs/unapproved-x/1/text.sqlite',
    ]) {
      await expectLater(
        bundle().load(key),
        throwsA(isA<FlutterError>()),
        reason: key,
      );
    }
  });

  test('a null root, as on iOS, reads as missing', () async {
    final none = DevicePackBundle(() async => null);
    await expectLater(
      none.load('assets/packs/unapproved-x/1/text.sqlite'),
      throwsA(isA<FlutterError>()),
    );
  });

  test('writes nothing', () async {
    await bundle().load('assets/packs/unapproved-x/1/text.sqlite');
    expect(root.listSync(recursive: true).whereType<File>().length, 2);
  });
}
