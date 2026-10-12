import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/services/wakelock_service.dart';

const _channel =
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle';

/// Reads the plugin's toggle message, a list holding the wanted state.
final class _Codec extends StandardMessageCodec {
  const _Codec();

  @override
  Object? readValueOfType(int type, ReadBuffer buffer) =>
      type == 129 ? readValue(buffer) : super.readValueOfType(type, buffer);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<Object?> toggles;

  setUp(() {
    toggles = [];
    messenger.setMockMessageHandler(_channel, (message) async {
      final [toggle] = const _Codec().decodeMessage(message)! as List<Object?>;
      toggles.add((toggle! as List<Object?>).single);
      return const _Codec().encodeMessage(<Object?>[]);
    });
  });
  tearDown(() => messenger.setMockMessageHandler(_channel, null));

  test('enables and disables the platform wakelock', () async {
    await const WakelockService().enable();
    await const WakelockService().disable();

    expect(toggles, [true, false]);
  });

  test('passes on a platform failure', () async {
    messenger.setMockMessageHandler(_channel, (_) async => null);

    expect(const WakelockService().enable(), throwsA(isA<PlatformException>()));
  });
}
