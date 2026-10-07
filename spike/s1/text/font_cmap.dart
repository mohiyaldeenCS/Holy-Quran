import 'dart:typed_data';

/// The code points a TrueType or OpenType font maps to a glyph other than
/// `.notdef`, from every Unicode `cmap` subtable of format 4 or 12
/// (platform 0, or platform 3 with encoding 1 or 10). Throws a
/// [FormatException] when the font has no such subtable or is truncated.
Set<int> cmapCodePoints(Uint8List ttf) {
  try {
    return _codePoints(ByteData.sublistView(ttf));
  } on RangeError {
    throw const FormatException('font: a table lies outside the file');
  }
}

const _sfntVersions = {0x00010000, 0x4F54544F, 0x74727565};
const _cmapTag = 0x636D6170;

Set<int> _codePoints(ByteData font) {
  if (!_sfntVersions.contains(font.getUint32(0))) {
    throw const FormatException('font: not a TrueType or OpenType file');
  }
  int? cmap;
  for (var i = 0; i < font.getUint16(4); i++) {
    final record = 12 + 16 * i;
    if (font.getUint32(record) == _cmapTag) cmap = font.getUint32(record + 8);
  }
  if (cmap == null) throw const FormatException('font: no cmap table');

  final codePoints = <int>{};
  final read = <int>{};
  for (var i = 0; i < font.getUint16(cmap + 2); i++) {
    final record = cmap + 4 + 8 * i;
    final platform = font.getUint16(record);
    final encoding = font.getUint16(record + 2);
    final unicode =
        platform == 0 || (platform == 3 && (encoding == 1 || encoding == 10));
    final subtable = cmap + font.getUint32(record + 4);
    if (!unicode || !read.add(subtable)) continue;
    switch (font.getUint16(subtable)) {
      case 4:
        _format4(font, subtable, codePoints);
      case 12:
        _format12(font, subtable, codePoints);
      default:
        read.remove(subtable);
    }
  }
  if (read.isEmpty) {
    throw const FormatException('font: no Unicode cmap of format 4 or 12');
  }
  return codePoints;
}

void _format4(ByteData font, int at, Set<int> out) {
  final segments = font.getUint16(at + 6) ~/ 2;
  final ends = at + 14;
  final starts = ends + 2 * segments + 2;
  final deltas = starts + 2 * segments;
  final rangeOffsets = deltas + 2 * segments;
  for (var s = 0; s < segments; s++) {
    final end = font.getUint16(ends + 2 * s);
    final start = font.getUint16(starts + 2 * s);
    final delta = font.getUint16(deltas + 2 * s);
    final rangeOffsetAt = rangeOffsets + 2 * s;
    final rangeOffset = font.getUint16(rangeOffsetAt);
    for (var c = start; c <= end && c != 0xFFFF; c++) {
      var glyph = rangeOffset == 0
          ? c
          : font.getUint16(rangeOffsetAt + rangeOffset + 2 * (c - start));
      if (rangeOffset != 0 && glyph == 0) continue;
      glyph = (glyph + delta) & 0xFFFF;
      if (glyph != 0) out.add(c);
    }
  }
}

void _format12(ByteData font, int at, Set<int> out) {
  final groups = font.getUint32(at + 12);
  for (var g = 0; g < groups; g++) {
    final group = at + 16 + 12 * g;
    final start = font.getUint32(group);
    final end = font.getUint32(group + 4);
    final glyph = font.getUint32(group + 8);
    if (start > end || end > 0x10FFFF) {
      throw const FormatException('font: a format 12 group is out of range');
    }
    for (var c = start; c <= end; c++) {
      if (glyph + (c - start) != 0) out.add(c);
    }
  }
}
