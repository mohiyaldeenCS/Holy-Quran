import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:holyquran/config/test_copy.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/routing/routes/home_routes.dart';

import 'flow_pack.dart';

/// The id of the synthetic pack a flow runs as the unapproved test copy; it
/// begins with the prefix the test copy requires.
const flowTestCopyId = 'unapproved-synthetic-flow';

/// An unapproved test copy as `adb push` leaves one: [root] is the folder
/// that holds `<id>/<version>/`, and [copy] is what the build's defines parse
/// to, with the public half of a throwaway key.
typedef TestCopyPack = ({Directory root, TestCopy copy});

/// Builds the flows' synthetic pack as the test copy's pack under
/// `<parent>/test_copy/`, with a key generated here. Its manifest is signed
/// with that key unless [signed] is false. Run it in `WidgetTester.runAsync`.
Future<TestCopyPack> buildFlowTestCopy(
  Directory parent, {
  bool signed = true,
}) async {
  final root = Directory('${parent.path}/test_copy');
  final pack = await buildFlowPack(root, id: flowTestCopyId);
  final algorithm = Ed25519();
  final key = await algorithm.newKeyPair();
  if (signed) {
    final manifest = await pack.manifestFile.readAsBytes();
    final signature = await algorithm.sign(manifest, keyPair: key);
    await File('${pack.manifestFile.path}.sig').writeAsBytes(signature.bytes);
  }
  final publicKey = (await key.extractPublicKey()).bytes;
  final copy = TestCopy.parse(
    '$flowTestCopyId/$flowPackVersion',
    base64.encode(publicKey),
    release: false,
  )!;
  return (root: root, copy: copy);
}

/// The app's routes as a build of the test copy [pack] has them. Home reads
/// the id of the base pack from a constant fixed when the app is built
/// (`basePackInUse`), and a test cannot build with the defines, so home is
/// the one route given the copy's pack here.
List<FeatureRoutes> testCopyFeatures(TestCopyPack pack) => [
  for (final feature in appFeatures)
    identical(feature, homeRoutes) ? homeRoutesFor(pack.copy.pack) : feature,
];
