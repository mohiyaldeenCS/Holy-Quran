import 'package:flutter_test/flutter_test.dart';

import '../lib/color_value.dart';
import '../lib/generator_error.dart';
import '../lib/shadow_value.dart';

void main() {
  group('ColorValue.parse', () {
    test('#RRGGBB becomes an opaque Color, upper-cased', () {
      expect(ColorValue.parse('#0e5a52').toDart(), 'Color(0xFF0E5A52)');
    });

    test('rgba keeps the exact alpha and writes channels over 255', () {
      expect(
        ColorValue.parse('rgba(184,134,43,0.24)').toDart(),
        'Color.from(alpha: 0.24, red: 184 / 255, green: 134 / 255, '
        'blue: 43 / 255)',
      );
      expect(
        ColorValue.parse('rgba(0, 0, 0, 0.40)').toDart(),
        'Color.from(alpha: 0.4, red: 0 / 255, green: 0 / 255, blue: 0 / 255)',
      );
    });

    for (final source in [
      '#FFF',
      '#FF00FF80',
      'rgb(1,2,3)',
      'hsl(0,0%,0%)',
      'red',
      'rgba(256,0,0,0.5)',
      'rgba(0,0,0,1.5)',
      '{alias}',
    ]) {
      test('rejects "$source"', () {
        expect(() => ColorValue.parse(source), throwsA(isA<GeneratorError>()));
      });
    }
  });

  group('ShadowValue.parseList', () {
    test('none is no shadow', () {
      expect(ShadowValue.parseList('none'), isEmpty);
    });

    test('converts the CSS blur to the same Gaussian in Flutter', () {
      final [shadow] = ShadowValue.parseList('0 -12px 32px rgba(0,0,0,0.40)');
      expect(
        shadow.toDart(),
        'BoxShadow(color: Color.from(alpha: 0.4, red: 0 / 255, '
        'green: 0 / 255, blue: 0 / 255), offset: Offset(0, -12), '
        'blurRadius: (32 / 2 - 0.5) / 0.57735)',
      );
      // Flutter's sigma for that radius equals the CSS sigma, blur / 2.
      const blurRadius = (32 / 2 - 0.5) / 0.57735;
      expect(blurRadius * 0.57735 + 0.5, closeTo(16, 1e-9));
    });

    for (final source in [
      '0 2px rgba(0,0,0,0.1)',
      '0 2px 8px 2px rgba(0,0,0,0.1)',
      '0 2 8px rgba(0,0,0,0.1)',
      '0 2px 8em rgba(0,0,0,0.1)',
      '0 2px 0.5px rgba(0,0,0,0.1)',
      'inset 0 2px 8px rgba(0,0,0,0.1)',
      '0 2px 8px rgba(0,0,0,0.1), 0 1px 2px rgba(0,0,0,0.1)',
    ]) {
      test('rejects "$source"', () {
        expect(
          () => ShadowValue.parseList(source),
          throwsA(isA<GeneratorError>()),
        );
      });
    }
  });
}
