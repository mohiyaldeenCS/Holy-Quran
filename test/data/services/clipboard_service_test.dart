import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/services/clipboard_service.dart';
import 'package:holyquran/utils/result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const service = SystemClipboardService();

  // Synthetic: edge and doubled spaces, a combining mark, a non-BMP character
  // and a line break, all of which a careless copy would alter.
  const text = '  loreḿ  ipsum \u{1F600}\r\n ';

  tearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );

  test('puts the exact text on the clipboard', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });

    final result = await service.copyText(text);

    expect(result, isA<Ok<void>>());
    expect(calls, hasLength(1));
    expect(calls.single.method, 'Clipboard.setData');
    final copied = (calls.single.arguments as Map)['text'] as String;
    expect(copied, text);
    expect(copied.codeUnits, text.codeUnits);
  });

  test('a platform error becomes a Failure', () async {
    messenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => throw PlatformException(code: 'denied'),
    );

    final result = await service.copyText(text);

    expect(
      result,
      isA<Failure<void>>().having(
        (failure) => failure.error,
        'error',
        isA<PlatformException>().having((e) => e.code, 'code', 'denied'),
      ),
    );
  });
}
