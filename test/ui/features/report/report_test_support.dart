import 'dart:convert';
import 'dart:io';

import 'package:holyquran/data/models/pack_manifest_json.dart';
import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../testing/packs/synthetic_tafsir_pack.dart';

/// The default synthetic tafsir pack at [version], installed as the
/// installer would list it, read from the manifest the pack builder wrote.
Future<InstalledPack> installedSyntheticTafsir(
  Directory root, {
  int version = 3,
}) async {
  final pack = await buildSyntheticTafsirPack(root, version: version);
  final manifest = switch (parsePackManifest(
    utf8.encode(jsonEncode(pack.manifest)),
    pack: 'synthetic-tafsir',
  )) {
    Ok(:final value) => value,
    Failure(:final error) => throw error,
  };
  return InstalledPack(
    manifest: manifest,
    directory: pack.directory.path,
    previousVersion: null,
  );
}
