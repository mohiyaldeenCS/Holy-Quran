import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/services/base_pack_service.dart';

import '../../../testing/packs/synthetic_pack.dart';

/// Serves the files of [directory] as the bundled pack synthetic-text/1.
final class _DirectoryBundle extends CachingAssetBundle {
  _DirectoryBundle(this.directory);

  final Directory directory;

  @override
  Future<ByteData> load(String key) async {
    const prefix = 'assets/packs/synthetic-text/1/';
    final file = File('${directory.path}/${key.substring(prefix.length)}');
    if (!key.startsWith(prefix) || !file.existsSync()) {
      throw FlutterError('Unable to load asset: "$key".');
    }
    return ByteData.sublistView(await file.readAsBytes());
  }
}

void main() {
  late Directory root;
  late Directory support;
  late SyntheticPack pack;
  late BasePackService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('base_pack_service_test');
    support = await Directory('${root.path}/support').create();
    pack = await buildSyntheticPack(Directory('${root.path}/bundle'));
    service = BasePackService(
      id: 'synthetic-text',
      version: 1,
      bundle: _DirectoryBundle(pack.directory),
      supportDirectory: () async => support,
    );
  });
  tearDown(() => root.delete(recursive: true));

  test('copies to packs/<id>/<version> in the support directory', () async {
    expect(await service.directory(), '${support.path}/packs/synthetic-text/1');
  });

  test('reads a bundled file, or null for one not bundled', () async {
    expect(
      await service.readBundled(manifestFileName),
      pack.manifestFile.readAsBytesSync(),
    );
    expect(await service.readBundled('manifest.json.sig'), isNull);
  });

  test('extracts the bundled files given, leaving out the others', () async {
    await service.extract([
      manifestFileName,
      'manifest.json.sig',
      textFileName,
    ]);

    final copy = Directory(await service.directory());
    expect(copy.listSync().map((e) => e.uri.pathSegments.last).toSet(), {
      manifestFileName,
      textFileName,
    });
    expect(
      File('${copy.path}/$textFileName').readAsBytesSync(),
      pack.textFile.readAsBytesSync(),
    );
  });

  test('an extract replaces the copy before it', () async {
    await service.extract([manifestFileName, textFileName]);
    final stale = File('${await service.directory()}/stale');
    stale.writeAsStringSync('synthetic');

    await service.extract([manifestFileName]);

    expect(stale.existsSync(), isFalse);
    expect(
      File('${await service.directory()}/$textFileName').existsSync(),
      isFalse,
    );
  });

  test('remembers a manifest until it forgets it', () async {
    final manifest = pack.manifestFile.readAsBytesSync();
    final other = Uint8List.fromList(manifest)..[0] ^= 1;
    await service.extract([manifestFileName]);
    expect(await service.remembers(manifest), isFalse);

    await service.remember(manifest);
    expect(await service.remembers(manifest), isTrue);
    expect(await service.remembers(other), isFalse);
    final otherVersion = BasePackService(
      id: 'synthetic-text',
      version: 2,
      bundle: _DirectoryBundle(pack.directory),
      supportDirectory: () async => support,
    );
    expect(await otherVersion.remembers(manifest), isFalse);

    await service.forget();
    expect(await service.remembers(manifest), isFalse);
    await service.forget();
  });

  test('does not remember a copy whose manifest changed', () async {
    final manifest = pack.manifestFile.readAsBytesSync();
    await service.extract([manifestFileName]);
    await service.remember(manifest);
    File(
      '${await service.directory()}/$manifestFileName',
    ).writeAsBytesSync(Uint8List.fromList(manifest)..[0] ^= 1);

    expect(await service.remembers(manifest), isFalse);
  });

  test('never writes into the bundled files', () async {
    final before = pack.textFile.readAsBytesSync();
    await service.extract([manifestFileName, textFileName]);
    expect(pack.textFile.readAsBytesSync(), before);
  });
}
