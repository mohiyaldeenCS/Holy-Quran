import 'dart:io';

import 'package:disk_space_2/disk_space_2.dart';

/// Space a pack install leaves free, so that the system and the user's own
/// data still have room after it.
const int packSpaceReserveBytes = 100 << 20;

abstract interface class FreeSpaceService {
  /// The free bytes on the volume of [directory], or null when unknown.
  Future<int?> freeBytesAt(String directory);
}

/// Free space from `disk_space_2` (D-124). An unknown answer is null, never
/// zero, so that it cannot stop the download queue by mistake.
final class DiskFreeSpaceService implements FreeSpaceService {
  const DiskFreeSpaceService();

  static const _bytesPerMebibyte = 1 << 20;

  @override
  Future<int?> freeBytesAt(String directory) async {
    try {
      await Directory(directory).create(recursive: true);
      final mebibytes = await DiskSpace.getFreeDiskSpaceForPath(directory);
      if (mebibytes == null || !mebibytes.isFinite || mebibytes <= 0) {
        return null;
      }
      return (mebibytes * _bytesPerMebibyte).floor();
    } on Exception {
      return null;
    }
  }
}
