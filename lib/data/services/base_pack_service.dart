import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// The base pack the app bundles under `assets/packs/<id>/<version>/`
/// (D-030), and its copy in the application-support directory under
/// `packs/<id>/<version>/` (D-107), from which it is verified and read
/// (D-061). It copies files and remembers which bundled manifest
/// passed a full check; checking is the caller's.
class BasePackService {
  BasePackService({
    required this.id,
    required this.version,
    AssetBundle? bundle,
    Future<Directory> Function()? supportDirectory,
  }) : _bundle = bundle ?? rootBundle,
       _support = supportDirectory ?? getApplicationSupportDirectory;

  final String id;
  final int version;
  final AssetBundle _bundle;
  final Future<Directory> Function() _support;

  String get _assets => 'assets/packs/$id/$version';

  /// The directory the pack is copied to.
  Future<String> directory() async =>
      '${(await _support()).path}/packs/$id/$version';

  Future<File> get _stamp async =>
      File('${(await _support()).path}/base_pack.verified');

  /// The bytes of the bundled file [name], or null when the app bundles none.
  Future<Uint8List?> readBundled(String name) async {
    final ByteData data;
    try {
      data = await _bundle.load('$_assets/$name');
    } on FlutterError {
      return null;
    }
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  /// Replaces the copy with the bundled files [names], bare file names; a
  /// name the app does not bundle is left out. Throws a
  /// [FileSystemException] when the copy cannot be written.
  Future<void> extract(List<String> names) async {
    final target = Directory(await directory());
    if (await target.exists()) await target.delete(recursive: true);
    await target.create(recursive: true);
    for (final name in names) {
      final bytes = await readBundled(name);
      if (bytes != null) {
        await File('${target.path}/$name').writeAsBytes(bytes, flush: true);
      }
    }
  }

  /// Whether [remember] was last given these bytes of `manifest.json`.
  Future<bool> remembers(Uint8List manifest) async {
    try {
      return await (await _stamp).readAsString() == _stampOf(manifest);
    } on FileSystemException {
      return false;
    }
  }

  /// Remembers that the copy made from the bundled [manifest] passed a full
  /// check. Throws a [FileSystemException] when it cannot be written.
  Future<void> remember(Uint8List manifest) async =>
      (await _stamp).writeAsString(_stampOf(manifest), flush: true);

  Future<void> forget() async {
    final stamp = await _stamp;
    if (await stamp.exists()) await stamp.delete();
  }

  String _stampOf(Uint8List manifest) =>
      '$id/$version ${sha256.convert(manifest)}';
}
