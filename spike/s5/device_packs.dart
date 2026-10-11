import 'dart:io';
import 'dart:typed_data';

import '../../testing/packs/synthetic_pack.dart';
import 'filler_pack.dart';

/// Builds versions 1 and 2 of pack [id] under [served] unless both are
/// there. testing/packs/synthetic_pack.dart reads the font from a path
/// relative to the working directory, which on a device is `/`; so [font]
/// (the bundled font's bytes) is written under [work], and [work] is the
/// working directory while the packs are built. Returns one line per
/// action.
Future<List<String>> buildDevicePacks({
  required Directory served,
  required Directory work,
  required Uint8List font,
  required String id,
  required int bytes,
}) async {
  if (await File('${served.path}/$id/2/$manifestFileName').exists()) {
    return const [];
  }
  if (await served.exists()) await served.delete(recursive: true);
  final fontFile = File('${work.path}/$amiriQuranFontPath');
  await fontFile.parent.create(recursive: true);
  await fontFile.writeAsBytes(font, flush: true);
  final previous = Directory.current;
  Directory.current = work;
  try {
    for (final version in [1, 2]) {
      await buildSyntheticPack(
        served,
        id: id,
        version: version,
        surahs: fillerSurahs(bytes: bytes, tag: 'v$version'),
      );
    }
  } finally {
    Directory.current = previous;
  }
  final lines = <String>[];
  for (final version in [1, 2]) {
    final size = await File(
      '${served.path}/$id/$version/$textFileName',
    ).length();
    lines.add('built $id/$version: $textFileName $size bytes');
  }
  return lines;
}
