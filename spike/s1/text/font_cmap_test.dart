import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../../testing/packs/synthetic_pack.dart' show amiriQuranFontPath;
import 'font_cmap.dart';
import 'gibberish.dart';

/// A font file holding only a `cmap` table with [subtables], each given as
/// (platform, encoding, bytes).
Uint8List _font(List<(int, int, Uint8List)> subtables) {
  final cmapHeader = 4 + 8 * subtables.length;
  final cmap = BytesBuilder()..add(_u16s([0, subtables.length]));
  var offset = cmapHeader;
  for (final (platform, encoding, bytes) in subtables) {
    cmap
      ..add(_u16s([platform, encoding]))
      ..add(_u32s([offset]));
    offset += bytes.length;
  }
  for (final (_, _, bytes) in subtables) {
    cmap.add(bytes);
  }
  return (BytesBuilder()
        ..add(_u32s([0x00010000]))
        ..add(_u16s([1, 0, 0, 0]))
        ..add(_u32s([0x636D6170, 0, 28, cmap.length]))
        ..add(cmap.takeBytes()))
      .takeBytes();
}

Uint8List _u16s(List<int> values) {
  final data = ByteData(2 * values.length);
  for (final (i, v) in values.indexed) {
    data.setUint16(2 * i, v & 0xFFFF);
  }
  return data.buffer.asUint8List();
}

Uint8List _u32s(List<int> values) {
  final data = ByteData(4 * values.length);
  for (final (i, v) in values.indexed) {
    data.setUint32(4 * i, v);
  }
  return data.buffer.asUint8List();
}

/// Format 4 with segments (start, end, delta, glyphs or null for delta only)
/// and the closing 0xFFFF segment.
Uint8List _format4(List<(int, int, int, List<int>?)> segments) {
  final all = [...segments, (0xFFFF, 0xFFFF, 1, null)];
  final n = all.length;
  final glyphArrays = <int>[];
  final rangeOffsets = <int>[];
  for (final (i, (_, _, _, glyphs)) in all.indexed) {
    if (glyphs == null) {
      rangeOffsets.add(0);
    } else {
      rangeOffsets.add(2 * (n - i) + 2 * glyphArrays.length);
      glyphArrays.addAll(glyphs);
    }
  }
  final body = [
    ...all.map((s) => s.$2),
    0,
    ...all.map((s) => s.$1),
    ...all.map((s) => s.$3),
    ...rangeOffsets,
    ...glyphArrays,
  ];
  return _u16s([4, 14 + 2 * body.length, 0, 2 * n, 0, 0, 0, ...body]);
}

Uint8List _format12(List<(int, int, int)> groups) =>
    (BytesBuilder()
          ..add(_u16s([12, 0]))
          ..add(_u32s([16 + 12 * groups.length, 0, groups.length]))
          ..add(
            _u32s([
              for (final (s, e, g) in groups) ...[s, e, g],
            ]),
          ))
        .takeBytes();

void main() {
  group('cmapCodePoints', () {
    test('reads format 4 by delta and by glyph array, skipping .notdef', () {
      final font = _font([
        (
          3,
          1,
          _format4([
            (0x41, 0x43, 5, null),
            (0x0627, 0x0629, 0, [7, 0, 9]),
            (0x30, 0x30, -0x30, null),
          ]),
        ),
      ]);
      expect(cmapCodePoints(font), {0x41, 0x42, 0x43, 0x0627, 0x0629});
    });

    test('reads format 12 beyond the BMP', () {
      final font = _font([
        (3, 10, _format12([(0x1F600, 0x1F602, 3), (0x20, 0x21, 0)])),
      ]);
      expect(cmapCodePoints(font), {0x1F600, 0x1F601, 0x1F602, 0x21});
    });

    test('joins every Unicode subtable and ignores the others', () {
      final font = _font([
        (1, 0, _format4([(0x61, 0x61, 1, null)])),
        (0, 3, _format4([(0x62, 0x62, 1, null)])),
        (3, 10, _format12([(0x63, 0x63, 1)])),
      ]);
      expect(cmapCodePoints(font), {0x62, 0x63});
    });

    test('refuses a font with no Unicode subtable of format 4 or 12', () {
      expect(
        () => cmapCodePoints(
          _font([
            (1, 0, _format4([(0x61, 0x61, 1, null)])),
          ]),
        ),
        throwsFormatException,
      );
      expect(
        () => cmapCodePoints(Uint8List.fromList([0, 1, 0, 0, 0])),
        throwsFormatException,
      );
      expect(
        () => cmapCodePoints(Uint8List.fromList([1, 2, 3, 4, 0, 0])),
        throwsFormatException,
      );
    });
  });

  group('the pinned Amiri Quran font', () {
    final codePoints = cmapCodePoints(
      File(amiriQuranFontPath).readAsBytesSync(),
    );

    test('maps the basic Arabic letters, marks and U+0020', () {
      expect(
        codePoints,
        containsAll([
          0x0020,
          0x0627,
          0x0628,
          0x062A,
          0x0644,
          0x0645,
          0x0646,
          0x064A,
          0x064E,
          0x064F,
          0x0650,
          0x0651,
          0x0652,
          0x0670,
        ]),
      );
    });

    test('maps every code point of the synthetic Arabic-script generator', () {
      expect(SyntheticArabicScript.codePoints.difference(codePoints), isEmpty);
    });

    test('does not map a CJK ideograph', () {
      expect(codePoints, isNot(contains(0x4E00)));
    });
  });
}
