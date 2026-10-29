import 'dart:convert';
import 'dart:io';

import 'package:holyquran/data/models/pack_manifest_json.dart';
import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../testing/packs/synthetic_pack.dart';

/// A synthetic text pack installed under [id], whose first source is named
/// [name] with the licence [licenceText] and [notice], and whose other
/// sources stay as the synthetic pack makes them.
Future<InstalledPack> installedWithSource(
  Directory root, {
  String id = 'synthetic-text',
  String name = 'Synthetic source name',
  String url = 'https://example.invalid/synthetic/source',
  String publisher = 'Synthetic publisher',
  String version = '1',
  String? licenceText = 'Synthetic licence text',
  String? notice = 'Synthetic credit notice',
}) async {
  final pack = await buildSyntheticPack(root, id: id);
  final sources = pack.manifest['sources']! as List<Object?>;
  final first = sources.first! as Map<String, Object?>;
  first
    ..['name'] = name
    ..['url'] = url
    ..['publisher'] = publisher
    ..['version'] = version
    ..['licence'] = {
      'text': licenceText,
      'permission_ref': 'Synthetic permission 1',
      'notice': notice,
      'allows_export': true,
    };
  final manifest = switch (parsePackManifest(
    utf8.encode(jsonEncode(pack.manifest)),
    pack: id,
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
