import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/services/free_space_service.dart';

const _channel = MethodChannel('disk_space_2');

void main() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('free_space_test');
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(_channel, null);
    await temp.delete(recursive: true);
  });

  void answer(Object? Function(MethodCall call) reply) =>
      messenger.setMockMethodCallHandler(_channel, (call) async => reply(call));

  test('the reserve is 100 MiB', () {
    expect(packSpaceReserveBytes, 100 * 1024 * 1024);
  });

  test(
    'creates the directory, then reports its free mebibytes as bytes',
    () async {
      final directory = '${temp.path}/packs/staging';
      final calls = <MethodCall>[];
      answer((call) {
        calls.add(call);
        expect(Directory(directory).existsSync(), isTrue);
        return 1.5;
      });
      expect(
        await const DiskFreeSpaceService().freeBytesAt(directory),
        3 << 19,
      );
      expect(calls.single.method, 'getFreeDiskSpaceForPath');
      expect(calls.single.arguments, {'path': directory});
    },
  );

  test('null, zero, a negative or a non-finite answer is unknown', () async {
    for (final reply in <double?>[null, 0, -1, double.nan, double.infinity]) {
      answer((_) => reply);
      expect(
        await const DiskFreeSpaceService().freeBytesAt(temp.path),
        isNull,
        reason: '$reply',
      );
    }
  });

  test('a platform error or a missing plugin is unknown', () async {
    answer((_) => throw PlatformException(code: 'synthetic'));
    expect(await const DiskFreeSpaceService().freeBytesAt(temp.path), isNull);
    messenger.setMockMethodCallHandler(_channel, null);
    expect(await const DiskFreeSpaceService().freeBytesAt(temp.path), isNull);
  });

  test('a directory that cannot be made is unknown', () async {
    final file = File('${temp.path}/file');
    await file.writeAsBytes([1]);
    answer((_) => 1.0);
    expect(
      await const DiskFreeSpaceService().freeBytesAt('${file.path}/below'),
      isNull,
    );
  });
}
