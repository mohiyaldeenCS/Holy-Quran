import 'package:flutter/services.dart';

// S4 approach B, measured only (D-094): the same synthetic text laid out by a
// native Android TextView with the Quran font, to compare with Flutter's
// layout. Nothing here is Quran text.

/// The synthetic samples, from plain letters to a paragraph that wraps.
enum ShapingSample { plain, vowelled, marks, long }

/// A laid-out paragraph in logical pixels: the width of its longest line,
/// its height, and where each line starts, in UTF-16 code units.
typedef ShapingMeasure = ({
  double width,
  double height,
  int lineCount,
  List<int> lineStarts,
  List<double> lineWidths,
});

abstract interface class ShapingProbe {
  /// [sample] laid out natively at [fontSize] logical pixels, at most
  /// [maxWidth] wide, with the SHA-256 of the font file it used.
  Future<({ShapingMeasure measure, String fontSha256})> measure(
    ShapingSample sample, {
    required double fontSize,
    required double maxWidth,
  });
}

/// «نص تجريبي».
const String _phrase =
    '\u{646}\u{635} \u{62A}\u{62C}\u{631}\u{64A}\u{628}\u{64A}';

/// The same phrase with harakat and shadda.
const String _vowelled =
    '\u{646}\u{64E}\u{635}\u{651}\u{64C} '
    '\u{62A}\u{64E}\u{62C}\u{652}\u{631}\u{650}\u{64A}\u{628}\u{650}'
    '\u{64A}\u{651}\u{64C}';

/// The pause-mark code points U+06D6 to U+06DC, each a token of its own.
const List<String> _marks = [
  '\u{6D6}',
  '\u{6D7}',
  '\u{6D8}',
  '\u{6D9}',
  '\u{6DA}',
  '\u{6DB}',
  '\u{6DC}',
];

/// The text of [sample]: synthetic, built here and nowhere else.
String shapingSampleText(ShapingSample sample) => switch (sample) {
  ShapingSample.plain => _phrase,
  ShapingSample.vowelled => _vowelled,
  ShapingSample.marks => [
    for (final mark in _marks) '$_phrase $mark',
  ].join(' '),
  ShapingSample.long => List.filled(12, _vowelled).join(' '),
};

/// The channel ShapingProbe.kt answers, its one method and its fields.
abstract final class ShapingChannel {
  static const name = 'holyquran.spike/shaping_probe';
  static const measure = 'measure';
  static const text = 'text';
  static const fontSize = 'fontSize';
  static const maxWidth = 'maxWidth';
  static const width = 'width';
  static const height = 'height';
  static const lineCount = 'lineCount';
  static const lineStarts = 'lineStarts';
  static const lineWidths = 'lineWidths';
  static const fontSha256 = 'fontSha256';
}

/// [ShapingProbe] over ShapingProbe.kt.
final class MethodChannelShapingProbe implements ShapingProbe {
  const MethodChannelShapingProbe([
    this._channel = const MethodChannel(ShapingChannel.name),
  ]);

  final MethodChannel _channel;

  /// Throws a [FormatException] for an answer that is not a whole measure.
  @override
  Future<({ShapingMeasure measure, String fontSha256})> measure(
    ShapingSample sample, {
    required double fontSize,
    required double maxWidth,
  }) async {
    final answer = await _channel
        .invokeMethod<Object?>(ShapingChannel.measure, {
          ShapingChannel.text: shapingSampleText(sample),
          ShapingChannel.fontSize: fontSize,
          ShapingChannel.maxWidth: maxWidth,
        });
    return parseShapingAnswer(answer) ??
        (throw FormatException('Not a shaping measure', '$answer'));
  }
}

/// [answer] as a measure, or null unless every field is there, the line
/// lists match the count, and the starts rise from 0.
({ShapingMeasure measure, String fontSha256})? parseShapingAnswer(
  Object? answer,
) {
  if (answer case {
    ShapingChannel.width: final num width,
    ShapingChannel.height: final num height,
    ShapingChannel.lineCount: final int lineCount,
    ShapingChannel.lineStarts: final List<Object?> starts,
    ShapingChannel.lineWidths: final List<Object?> widths,
    ShapingChannel.fontSha256: final String fontSha256,
  }) {
    final lineStarts = [
      for (final start in starts)
        if (start is int) start,
    ];
    final lineWidths = [
      for (final width in widths)
        if (width is num) width.toDouble(),
    ];
    final rising = [
      for (var i = 1; i < lineStarts.length; i++)
        lineStarts[i] > lineStarts[i - 1],
    ].every((up) => up);
    if (lineCount < 1 ||
        lineStarts.length != starts.length ||
        lineWidths.length != widths.length ||
        lineStarts.length != lineCount ||
        lineWidths.length != lineCount ||
        lineStarts.first != 0 ||
        !rising ||
        !width.isFinite ||
        !height.isFinite ||
        width < 0 ||
        height <= 0 ||
        !_sha256.hasMatch(fontSha256)) {
      return null;
    }
    return (
      measure: (
        width: width.toDouble(),
        height: height.toDouble(),
        lineCount: lineCount,
        lineStarts: lineStarts,
        lineWidths: lineWidths,
      ),
      fontSha256: fontSha256,
    );
  }
  return null;
}

final _sha256 = RegExp(r'^[0-9a-f]{64}$');
