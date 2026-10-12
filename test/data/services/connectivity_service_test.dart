import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/services/connectivity_service.dart';

const _method = MethodChannel('dev.fluttercommunity.plus/connectivity');
const _events = EventChannel('dev.fluttercommunity.plus/connectivity_status');

final class _Events implements MockStreamHandler {
  _Events(this.batches);

  final List<List<String>> batches;

  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {
    for (final batch in batches) {
      events.success(batch);
    }
  }

  @override
  void onCancel(Object? arguments) {}
}

void main() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger
      ..setMockMethodCallHandler(_method, null)
      ..setMockStreamHandler(_events, null);
  });

  group('kindOf', () {
    test('Wi-Fi or Ethernet is unmetered, also with others', () {
      for (final results in [
        [ConnectivityResult.wifi],
        [ConnectivityResult.ethernet],
        [ConnectivityResult.mobile, ConnectivityResult.wifi],
        [ConnectivityResult.wifi, ConnectivityResult.vpn],
      ]) {
        expect(
          PlusConnectivityService.kindOf(results),
          NetworkKind.unmetered,
          reason: '$results',
        );
      }
    });

    test('nothing, or only none, is none', () {
      expect(PlusConnectivityService.kindOf([]), NetworkKind.none);
      expect(
        PlusConnectivityService.kindOf([ConnectivityResult.none]),
        NetworkKind.none,
      );
    });

    test('any other network is other', () {
      for (final result in [
        ConnectivityResult.mobile,
        ConnectivityResult.vpn,
        ConnectivityResult.bluetooth,
        ConnectivityResult.satellite,
        ConnectivityResult.other,
      ]) {
        expect(
          PlusConnectivityService.kindOf([result]),
          NetworkKind.other,
          reason: '$result',
        );
      }
    });
  });

  test('current asks the plugin', () async {
    messenger.setMockMethodCallHandler(_method, (call) async {
      expect(call.method, 'check');
      return ['mobile'];
    });
    expect(await PlusConnectivityService().current(), NetworkKind.other);
  });

  test('changes follow the plugin', () async {
    messenger.setMockStreamHandler(
      _events,
      _Events([
        ['wifi'],
        ['none'],
      ]),
    );
    expect(await PlusConnectivityService().changes.take(2).toList(), [
      NetworkKind.unmetered,
      NetworkKind.none,
    ]);
  });
}
