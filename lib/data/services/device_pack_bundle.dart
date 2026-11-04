import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// The packs an unapproved test copy reads from the phone's own files
/// (D-163) in place of the app's assets: the key
/// `assets/packs/<id>/<version>/<name>` is the file
/// `<root>/<id>/<version>/<name>`. It only reads. Any other key, a missing
/// file or a missing root fails with a [FlutterError], as the root bundle
/// does for a file it does not hold.
final class DevicePackBundle extends AssetBundle {
  DevicePackBundle(this._root);

  final Future<Directory?> Function() _root;

  static const _prefix = 'assets/packs/';

  /// `<external files>/test_copy`, where `adb push` puts a test copy. The
  /// only call of `getExternalStorageDirectory`. Null where the platform has
  /// no such folder, as on iOS, so that the pack reads as missing.
  static Future<Directory?> testCopyRoot() async {
    try {
      final files = await getExternalStorageDirectory();
      return files == null ? null : Directory('${files.path}/test_copy');
    } on UnsupportedError {
      return null;
    }
  }

  @override
  Future<ByteData> load(String key) async {
    final relative = _relativeOf(key);
    final root = await _root();
    if (relative == null || root == null) throw _missing(key);
    try {
      final bytes = await File('${root.path}/$relative').readAsBytes();
      return ByteData.sublistView(bytes);
    } on FileSystemException {
      throw _missing(key);
    }
  }

  // Exactly <id>/<version>/<name>, each one plain path segment.
  String? _relativeOf(String key) {
    if (!key.startsWith(_prefix)) return null;
    final parts = key.substring(_prefix.length).split('/');
    final plain = parts.every(
      (part) =>
          part.isNotEmpty &&
          part != '.' &&
          part != '..' &&
          !part.contains(r'\') &&
          !part.contains(':'),
    );
    return parts.length == 3 && plain ? parts.join('/') : null;
  }

  FlutterError _missing(String key) =>
      FlutterError('Unable to load asset: "$key".');
}
