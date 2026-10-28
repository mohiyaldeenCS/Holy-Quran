import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/services/share_service.dart';
import 'package:holyquran/utils/result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const share = MethodChannel('dev.fluttercommunity.plus/share');
  // share_plus stages in-memory files in the temporary directory before
  // handing their paths to the platform.
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  const service = SystemShareService();
  const fileName = 'card.png';
  final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 1, 2, 255]);
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('share_service_test');
    messenger.setMockMethodCallHandler(pathProvider, (call) async {
      if (call.method == 'getTemporaryDirectory') return temp.path;
      return null;
    });
  });

  tearDown(() async {
    messenger
      ..setMockMethodCallHandler(share, null)
      ..setMockMethodCallHandler(pathProvider, null);
    await temp.delete(recursive: true);
  });

  test('hands the PNG bytes to the platform under the file name', () async {
    final calls = <MethodCall>[];
    final shared = <Uint8List>[];
    messenger.setMockMethodCallHandler(share, (call) async {
      calls.add(call);
      final paths = (call.arguments as Map)['paths'] as List;
      shared.addAll([
        for (final path in paths) File(path as String).readAsBytesSync(),
      ]);
      return 'com.example.target';
    });

    final result = await service.shareImage(png, fileName: fileName);

    expect(result, isA<Ok<void>>());
    expect(calls, hasLength(1));
    expect(calls.single.method, 'share');
    final arguments = calls.single.arguments as Map;
    final paths = arguments['paths'] as List;
    expect(paths, hasLength(1));
    expect(File(paths.single as String).uri.pathSegments.last, fileName);
    expect(arguments['mimeTypes'], ['image/png']);
    expect(shared, [png]);
  });

  test('a dismissed sheet is not a failure', () async {
    messenger.setMockMethodCallHandler(share, (call) async => '');

    final result = await service.shareImage(png, fileName: fileName);

    expect(result, isA<Ok<void>>());
  });

  test('a platform error becomes a Failure', () async {
    messenger.setMockMethodCallHandler(
      share,
      (call) async => throw PlatformException(code: 'busy'),
    );

    final result = await service.shareImage(png, fileName: fileName);

    expect(
      result,
      isA<Failure<void>>().having(
        (failure) => failure.error,
        'error',
        isA<PlatformException>().having((e) => e.code, 'code', 'busy'),
      ),
    );
  });
}
