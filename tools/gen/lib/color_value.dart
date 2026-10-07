import 'dart_literals.dart';
import 'generator_error.dart';

final _hex = RegExp(r'^#([0-9A-Fa-f]{6})$');
final _rgba = RegExp(
  r'^rgba\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d*\.?\d+)\s*\)$',
);

/// A colour literal from `tokens.json`: `#RRGGBB` or `rgba(r,g,b,a)`.
sealed class ColorValue {
  const ColorValue();

  factory ColorValue.parse(String source) {
    final hex = _hex.firstMatch(source);
    if (hex != null) {
      return HexColor(hex.group(1)!.toUpperCase());
    }
    final rgba = _rgba.firstMatch(source);
    if (rgba != null) {
      final channels = [for (var i = 1; i <= 3; i++) int.parse(rgba.group(i)!)];
      final alpha = double.parse(rgba.group(4)!);
      if (channels.any((c) => c > 255) || alpha > 1) {
        throw GeneratorError('Colour "$source" has a channel out of range.');
      }
      return RgbaColor(channels[0], channels[1], channels[2], alpha);
    }
    throw GeneratorError(
      'Colour "$source" is neither #RRGGBB nor rgba(r,g,b,a).',
    );
  }

  /// A constant Dart expression of type `Color`.
  String toDart();
}

final class HexColor extends ColorValue {
  const HexColor(this.rrggbb);

  final String rrggbb;

  @override
  String toDart() => 'Color(0xFF$rrggbb)';

  @override
  bool operator ==(Object other) => other is HexColor && other.rrggbb == rrggbb;

  @override
  int get hashCode => rrggbb.hashCode;
}

/// Written with `Color.from` so the alpha keeps its exact decimal value
/// instead of being rounded to eight bits.
final class RgbaColor extends ColorValue {
  const RgbaColor(this.red, this.green, this.blue, this.alpha);

  final int red;
  final int green;
  final int blue;
  final double alpha;

  @override
  String toDart() =>
      'Color.from(alpha: ${numberLiteral(alpha)}, red: $red / 255, '
      'green: $green / 255, blue: $blue / 255)';

  @override
  bool operator ==(Object other) =>
      other is RgbaColor &&
      other.red == red &&
      other.green == green &&
      other.blue == blue &&
      other.alpha == alpha;

  @override
  int get hashCode => Object.hash(red, green, blue, alpha);
}
