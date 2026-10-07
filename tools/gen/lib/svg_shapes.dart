import 'package:path_parsing/path_parsing.dart';

import 'dart_literals.dart';
import 'generator_error.dart';

/// One call on a Flutter `Path`.
sealed class PathOp {
  const PathOp();

  /// The call as a cascade section, such as `..lineTo(4, 11.5)`.
  String toDart();
}

final class MoveTo extends PathOp {
  const MoveTo(this.x, this.y);

  final double x;
  final double y;

  @override
  String toDart() => '..moveTo(${_n([x, y])})';
}

final class LineTo extends PathOp {
  const LineTo(this.x, this.y);

  final double x;
  final double y;

  @override
  String toDart() => '..lineTo(${_n([x, y])})';
}

final class CubicTo extends PathOp {
  const CubicTo(this.x1, this.y1, this.x2, this.y2, this.x3, this.y3);

  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double x3;
  final double y3;

  @override
  String toDart() => '..cubicTo(${_n([x1, y1, x2, y2, x3, y3])})';
}

final class Close extends PathOp {
  const Close();

  @override
  String toDart() => '..close()';
}

final class AddRRect extends PathOp {
  const AddRRect(this.x, this.y, this.width, this.height, this.radius);

  final double x;
  final double y;
  final double width;
  final double height;
  final double radius;

  @override
  String toDart() =>
      '..addRRect(RRect.fromRectAndRadius('
      'Rect.fromLTWH(${_n([x, y, width, height])}), '
      'Radius.circular(${_coordinate(radius)})))';
}

final class AddOval extends PathOp {
  const AddOval(this.cx, this.cy, this.r);

  final double cx;
  final double cy;
  final double r;

  @override
  String toDart() =>
      '..addOval(Rect.fromCircle('
      'center: Offset(${_n([cx, cy])}), radius: ${_coordinate(r)}))';
}

String _n(List<double> values) => values.map(_coordinate).join(', ');

/// Coordinates are rounded to four decimals. package:path_parsing turns
/// arcs into cubics in single precision (vector_math's Matrix4) through sin
/// and cos, so the last digits are noise of about 1e-6 that also differs
/// between platforms' maths libraries; the output must be the same bytes
/// everywhere. 1e-4 of a grid unit is far below a device pixel.
String _coordinate(double value) {
  final rounded = (value * 1e4).roundToDouble() / 1e4;
  return numberLiteral(rounded == 0 ? 0 : rounded);
}

final _element = RegExp(
  r'<([a-zA-Z][a-zA-Z0-9]*)((?:\s+[a-zA-Z][a-zA-Z0-9-]*="[^"]*")*)\s*/>',
);
final _attribute = RegExp(r'([a-zA-Z][a-zA-Z0-9-]*)="([^"]*)"');
final _number = RegExp(r'^-?(?:\d+\.?\d*|\.\d+)$');

/// The path operations for SVG [markup] made of self-closing `path`, `rect`
/// (with `rx`) and `circle` elements. Anything else stops the generator.
List<PathOp> shapesToPathOps(String markup, String where) {
  final ops = <PathOp>[];
  var position = 0;
  while (position < markup.length) {
    if (markup[position].trim().isEmpty) {
      position++;
      continue;
    }
    final match = _element.matchAsPrefix(markup, position);
    if (match == null) {
      throw GeneratorError(
        '$where: cannot read SVG markup at "${markup.substring(position)}".',
      );
    }
    ops.addAll(_elementOps(match.group(1)!, match.group(2)!, where));
    position = match.end;
  }
  if (ops.isEmpty) throw GeneratorError('$where has no shapes.');
  return ops;
}

List<PathOp> _elementOps(String tag, String attributeText, String where) {
  final attributes = <String, String>{};
  for (final match in _attribute.allMatches(attributeText)) {
    if (attributes.containsKey(match.group(1))) {
      throw GeneratorError('$where: <$tag> repeats "${match.group(1)}".');
    }
    attributes[match.group(1)!] = match.group(2)!;
  }
  switch (tag) {
    case 'path':
      _requireExactly(attributes, {'d'}, tag, where);
      return pathDataToOps(attributes['d']!, where);
    case 'rect':
      _requireExactly(
        attributes,
        {'x', 'y', 'width', 'height', 'rx'},
        tag,
        where,
      );
      final [x, y, width, height, rx] = [
        for (final name in ['x', 'y', 'width', 'height', 'rx'])
          _parseNumber(attributes[name]!, name, where),
      ];
      if (width <= 0 ||
          height <= 0 ||
          rx < 0 ||
          rx > width / 2 ||
          rx > height / 2) {
        throw GeneratorError('$where: <rect> has a size or rx out of range.');
      }
      return [AddRRect(x, y, width, height, rx)];
    case 'circle':
      _requireExactly(attributes, {'cx', 'cy', 'r'}, tag, where);
      final [cx, cy, r] = [
        for (final name in ['cx', 'cy', 'r'])
          _parseNumber(attributes[name]!, name, where),
      ];
      if (r <= 0) throw GeneratorError('$where: <circle> has radius $r.');
      return [AddOval(cx, cy, r)];
    default:
      throw GeneratorError('$where: unknown SVG element <$tag>.');
  }
}

/// SVG path data converted with package:path_parsing, which turns arcs,
/// quadratic and smooth curves into cubics and relative into absolute.
List<PathOp> pathDataToOps(String data, String where) {
  final recorder = _Recorder();
  try {
    writeSvgPathDataToPath(data, recorder);
  } on StateError catch (e) {
    throw GeneratorError('$where: path data "$data" is invalid: ${e.message}');
  }
  if (recorder.ops.isEmpty) {
    throw GeneratorError('$where: path data "$data" draws nothing.');
  }
  return recorder.ops;
}

void _requireExactly(
  Map<String, String> attributes,
  Set<String> names,
  String tag,
  String where,
) {
  for (final name in attributes.keys) {
    if (!names.contains(name)) {
      throw GeneratorError('$where: <$tag> has unsupported attribute "$name".');
    }
  }
  for (final name in names) {
    if (!attributes.containsKey(name)) {
      throw GeneratorError('$where: <$tag> has no "$name".');
    }
  }
}

double _parseNumber(String text, String name, String where) {
  if (!_number.hasMatch(text)) {
    throw GeneratorError('$where: "$name" is "$text", not a plain number.');
  }
  return double.parse(text);
}

final class _Recorder extends PathProxy {
  final ops = <PathOp>[];

  @override
  void moveTo(double x, double y) => ops.add(MoveTo(x, y));

  @override
  void lineTo(double x, double y) => ops.add(LineTo(x, y));

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => ops.add(CubicTo(x1, y1, x2, y2, x3, y3));

  @override
  void close() => ops.add(const Close());
}
