import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';

import '../application_support.dart';
import '../packs/synthetic_tafsir_pack.dart';
import 'flow_driver.dart';
import 'flow_pack.dart';
import 'flow_server.dart';
import 'flow_session.dart';

/// One run of a flow: a new application-support folder, which every session
/// of the run shares, as the app's runs on one device do.
final class FlowRun {
  FlowRun._(this.rig, this.support);

  final FlowRig rig;

  /// The folder `path_provider` answers with for this run.
  final Directory support;

  /// Starts the app, runs [body] with the user in front of it, and ends the
  /// session, leaving the folder as it is: a second call is a restart.
  Future<void> session(
    WidgetTester tester,
    Future<void> Function(FlowSession session) body,
  ) async {
    final session = await tester.runAsync(
      () => FlowSession.start(rig.sources, onDevice: rig.onDevice),
    );
    final semantics = tester.ensureSemantics();
    try {
      await pumpFlowApp(tester, session!.providers);
      await body(session);
    } finally {
      await leaveFlowApp(tester);
      semantics.dispose();
      await tester.runAsync(() => session!.close());
    }
  }
}

/// The synthetic base pack the flows bundle, built once for a test file.
/// Create it in `main`: it registers its own set-up and tear-down.
final class FlowRig {
  /// With [onDevice] the run is on a device: the folder is the app's own,
  /// emptied for each flow, and the user's database is opened as the app
  /// opens it.
  FlowRig({this.onDevice = false}) {
    final overrides = HttpOverrides.current;
    setUpAll(() async {
      // The test binding refuses every connection; the server is on loopback.
      HttpOverrides.global = null;
      _root = await Directory.systemTemp.createTemp('flows');
      bundle = (await buildFlowPack(
        Directory('${_root.path}/bundle'),
      )).directory;
      final served = Directory('${_root.path}/served');
      server = await FlowServer.start(served);
      tafsir = await serveCatalogue(served, server);
    });
    tearDownAll(() async {
      HttpOverrides.global = overrides;
      await server.close();
      await _root.delete(recursive: true);
    });
  }

  final bool onDevice;

  late final Directory _root;

  /// The directory of the pack the app bundles.
  late final Directory bundle;

  /// The server of the catalogue and the packs the catalogue lists.
  late final FlowServer server;

  /// The tafsir pack the catalogue lists, as served.
  late final SyntheticTafsirPack tafsir;

  FlowSources get sources => (bundle: bundle, server: server);

  Future<Directory> _freshSupport(WidgetTester tester) async {
    if (!onDevice) return useTemporaryApplicationSupport();
    final directory = await getApplicationSupportDirectory();
    if (directory.existsSync()) {
      for (final entry in directory.listSync()) {
        entry.deleteSync(recursive: true);
      }
    }
    return directory;
  }

  /// A widget test of one flow, run over a new application-support folder.
  void test(
    String description,
    Future<void> Function(WidgetTester tester, FlowRun run) body, {
    Timeout? timeout,
  }) => testWidgets(description, (tester) async {
    await body(tester, FlowRun._(this, await _freshSupport(tester)));
  }, timeout: timeout);
}
