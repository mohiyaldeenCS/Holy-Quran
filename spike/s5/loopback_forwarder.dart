import 'dart:async';
import 'dart:io';

/// Forwards TCP connections from a fixed port on 127.0.0.1 to [targetPort].
/// The loopback pack server binds a new port each start; after a force-stop
/// the native downloader retries the old URL, so the device screen serves
/// through this fixed port. A connection the server drops is dropped here
/// too.
final class LoopbackForwarder {
  LoopbackForwarder._(this._server, this.targetPort) {
    _server.listen((client) => unawaited(_pipe(client)));
  }

  static Future<LoopbackForwarder> start({
    required int port,
    required int targetPort,
  }) async => LoopbackForwarder._(
    await ServerSocket.bind(InternetAddress.loopbackIPv4, port),
    targetPort,
  );

  final ServerSocket _server;
  final int targetPort;

  Uri get baseUri => Uri(scheme: 'http', host: '127.0.0.1', port: _server.port);

  Future<void> close() => _server.close();

  Future<void> _pipe(Socket client) async {
    final Socket upstream;
    try {
      upstream = await Socket.connect(InternetAddress.loopbackIPv4, targetPort);
    } on SocketException {
      client.destroy();
      return;
    }
    await Future.wait([_copy(client, upstream), _copy(upstream, client)]);
  }

  static Future<void> _copy(Socket from, Socket to) async {
    try {
      await to.addStream(from);
      await to.close();
    } on SocketException {
      from.destroy();
      to.destroy();
    }
  }
}
