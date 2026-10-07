import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Reads the files of a pack. It opens files for reading only.
class PackFileService {
  const PackFileService();

  /// The bytes of the file at [path], or null when there is none.
  Future<Uint8List?> readIfExists(String path) async {
    try {
      return await File(path).readAsBytes();
    } on PathNotFoundException {
      return null;
    }
  }

  /// The size in bytes of the file at [path], or null when there is none.
  Future<int?> sizeOf(String path) async {
    try {
      return await File(path).length();
    } on PathNotFoundException {
      return null;
    }
  }

  /// The lowercase hex SHA-256 of the file at [path], or null when there is
  /// none. The file is streamed in a separate isolate.
  Future<String?> sha256Of(String path) => Isolate.run(() => _sha256Of(path));
}

Future<String?> _sha256Of(String path) async {
  try {
    return (await sha256.bind(File(path).openRead()).single).toString();
  } on PathNotFoundException {
    return null;
  }
}
