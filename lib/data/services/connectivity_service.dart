import 'package:connectivity_plus/connectivity_plus.dart';

/// The network the device is on. [unmetered] is Wi-Fi or Ethernet, what a
/// Wi-Fi-only download waits for.
enum NetworkKind { none, unmetered, other }

/// The device's network, which the downloader does not report while a
/// Wi-Fi-only task waits (S5).
abstract interface class ConnectivityService {
  Future<NetworkKind> current();

  Stream<NetworkKind> get changes;
}

final class PlusConnectivityService implements ConnectivityService {
  final _connectivity = Connectivity();

  @override
  Future<NetworkKind> current() async =>
      kindOf(await _connectivity.checkConnectivity());

  @override
  Stream<NetworkKind> get changes =>
      _connectivity.onConnectivityChanged.map(kindOf);

  static NetworkKind kindOf(List<ConnectivityResult> results) {
    if (results.any(
      (r) => r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet,
    )) {
      return NetworkKind.unmetered;
    }
    if (results.every((r) => r == ConnectivityResult.none)) {
      return NetworkKind.none;
    }
    return NetworkKind.other;
  }
}
