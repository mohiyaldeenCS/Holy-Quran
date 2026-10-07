import 'color_value.dart';
import 'dart_literals.dart';
import 'generator_error.dart';

final _shadow = RegExp(
  r'^(\S+)\s+(\S+)\s+(\S+)\s+(#[0-9A-Fa-f]{6}|rgba\([^)]*\))$',
);
final _length = RegExp(r'^(-?(?:\d+\.?\d*|\.\d+))(px)?$');

/// One CSS box shadow `x y blur colour`, or none.
final class ShadowValue {
  const ShadowValue(this.x, this.y, this.blur, this.color);

  final double x;
  final double y;
  final double blur;
  final ColorValue color;

  /// `none` gives an empty list; anything but one `x y blur colour` shadow
  /// stops the generator.
  static List<ShadowValue> parseList(String source) {
    if (source == 'none') return const [];
    final match = _shadow.firstMatch(source.trim());
    if (match == null) {
      throw GeneratorError(
        'Shadow "$source" is not of the form "x y blur colour" or "none".',
      );
    }
    final blur = _parseLength(match.group(3)!, source);
    if (blur < 0 || (blur > 0 && blur < 1)) {
      // Below 1 px Flutter's blur radius would be negative and its sigma 0.
      throw GeneratorError('Shadow "$source" has a blur Flutter cannot match.');
    }
    return [
      ShadowValue(
        _parseLength(match.group(1)!, source),
        _parseLength(match.group(2)!, source),
        blur,
        ColorValue.parse(match.group(4)!),
      ),
    ];
  }

  static double _parseLength(String text, String source) {
    final match = _length.firstMatch(text);
    if (match == null) {
      throw GeneratorError('Shadow "$source" has a length "$text" not in px.');
    }
    final value = double.parse(match.group(1)!);
    if (match.group(2) == null && value != 0) {
      throw GeneratorError(
        'Shadow "$source" has a length "$text" with no unit.',
      );
    }
    return value;
  }

  /// CSS draws a blur of B as a Gaussian with sigma B / 2. Flutter's
  /// `BoxShadow` turns blurRadius r into sigma r * 0.57735 + 0.5, so the same
  /// Gaussian needs r = (B / 2 - 0.5) / 0.57735.
  /// A blur of 0 stays 0.
  String toDart() {
    final blurRadius = blur == 0
        ? ''
        : ', blurRadius: (${numberLiteral(blur)} / 2 - 0.5) / 0.57735';
    return 'BoxShadow(color: ${color.toDart()}, '
        'offset: Offset(${numberLiteral(x)}, ${numberLiteral(y)})$blurRadius)';
  }

  @override
  bool operator ==(Object other) =>
      other is ShadowValue &&
      other.x == x &&
      other.y == y &&
      other.blur == blur &&
      other.color == color;

  @override
  int get hashCode => Object.hash(x, y, blur, color);
}
