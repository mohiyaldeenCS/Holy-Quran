import 'package:flutter_test/flutter_test.dart';

import '../lib/color_value.dart';
import '../lib/generator_error.dart';
import '../lib/ramps_writer.dart';
import '../lib/tokens_reader.dart';
import '../lib/tokens_writer.dart';
import 'synthetic_sources.dart';

Matcher throwsGeneratorError(String fragment) => throwsA(
  isA<GeneratorError>().having((e) => e.message, 'message', contains(fragment)),
);

void main() {
  test('literal colours are ramps; theme maps and aliases are semantic', () {
    final tokens = readTokens(encode(syntheticTokens()));
    expect(tokens.ramps.map((r) => r.name), ['base-100', 'base-900']);
    expect(tokens.colors.map((c) => c.name), ['ground', 'ink', 'text-ink']);
  });

  test('aliases resolve per theme, through other aliases', () {
    final tokens = readTokens(encode(syntheticTokens()));
    final textInk = tokens.colors.singleWhere((c) => c.name == 'text-ink');
    expect(textInk.byTheme['light'], const HexColor('101010'));
    expect(textInk.byTheme['dark'], const RgbaColor(255, 255, 255, 0.87));
    final ground = tokens.colors.singleWhere((c) => c.name == 'ground');
    expect(ground.byTheme, {
      'light': const HexColor('F0F0F0'),
      'dark': const HexColor('000000'),
    });
  });

  test('an unknown alias stops the generator', () {
    final json = syntheticTokens();
    colorTokens(json).add({'name': 'stray', 'value': '{missing}'});
    expect(() => readTokens(encode(json)), throwsGeneratorError('{missing}'));
  });

  test('an alias cycle stops the generator', () {
    final json = syntheticTokens();
    colorTokens(json).addAll([
      {'name': 'a', 'value': '{b}'},
      {
        'name': 'b',
        'value': {'light': '{a}', 'dark': '#000000'},
      },
    ]);
    expect(() => readTokens(encode(json)), throwsGeneratorError('cycle'));
  });

  test('a theme map without one of the themes stops the generator', () {
    final json = syntheticTokens();
    colorTokens(json).add({
      'name': 'half',
      'value': {'light': '#000000'},
    });
    expect(
      () => readTokens(encode(json)),
      throwsGeneratorError('no value for theme "dark"'),
    );
  });

  test('a theme map with an unknown theme id stops the generator', () {
    final json = syntheticTokens();
    colorTokens(json).add({
      'name': 'extra',
      'value': {'light': '#000000', 'dark': '#000000', 'dusk': '#000000'},
    });
    expect(
      () => readTokens(encode(json)),
      throwsGeneratorError('unknown theme id "dusk"'),
    );
  });

  test('an unknown field stops the generator', () {
    final json = syntheticTokens();
    colorTokens(json).add({'name': 'odd', 'value': '#000000', 'note': 'x'});
    expect(() => readTokens(encode(json)), throwsGeneratorError('"note"'));
  });

  test('a partial alias inside a value stops the generator', () {
    final json = syntheticTokens();
    colorTokens(json).add({'name': 'odd', 'value': 'x{base-100}'});
    expect(() => readTokens(encode(json)), throwsGeneratorError('odd'));
  });

  test('sample and usage never reach the generated code', () {
    final tokens = readTokens(encode(syntheticTokens()));
    for (final output in [writeTokens(tokens), writeRamps(tokens)]) {
      expect(output, isNot(contains('SAMPLE_MARKER')));
      expect(output, isNot(contains('USAGE_MARKER')));
      expect(output, isNot(contains('Group A')));
      expect(output, isNot(contains('Light')));
    }
  });

  test('family stacks give the first name and the named fallbacks', () {
    final [quran, kufi] = readTokens(encode(syntheticTokens())).families;
    expect((quran.key, quran.name), ('quran', 'Text Face'));
    expect(quran.fallbackKeys, isEmpty);
    expect((kufi.key, kufi.name), ('kufi', 'Title Face'));
    expect(kufi.fallbackKeys, ['quran']);
  });

  test('a fallback for the Quran family stops the generator', () {
    final json = syntheticTokens();
    ((json['type']! as Map<String, Object?>)['families']!
            as Map<String, Object?>)['quran'] =
        '"Text Face", "Title Face", serif';
    expect(() => readTokens(encode(json)), throwsGeneratorError('Quran'));
  });

  test('a family without a font file stops the generator', () {
    final json = syntheticTokens();
    ((json['type']! as Map<String, Object?>)['families']!
            as Map<String, Object?>)['kufi'] =
        '"Nowhere", serif';
    expect(() => readTokens(encode(json)), throwsGeneratorError('Nowhere'));
  });

  test('a weight the family does not cover stops the generator', () {
    final json = syntheticTokens();
    final group =
        ((json['type']! as Map<String, Object?>)['groups']! as List<Object?>)
                .first
            as Map<String, Object?>;
    ((group['styles']! as List<Object?>).first
            as Map<String, Object?>)['fontWeight'] =
        700;
    expect(() => readTokens(encode(json)), throwsGeneratorError('weight 700'));
  });

  test('styles, dimensions and shadows are written as Flutter values', () {
    final output = writeTokens(readTokens(encode(syntheticTokens())));
    expect(output, contains('static const TextStyle pageText = TextStyle('));
    expect(output, contains('fontFamilyFallback: [AppFonts.quran],'));
    expect(output, contains('height: 1.25,'));
    expect(output, contains('letterSpacing: 0,'));
    expect(output, contains('TextLeadingDistribution.even'));
    expect(output, contains('static const double space1 = 4;'));
    expect(output, contains('static const double radiusFull = 9999;'));
    expect(output, contains('static const double iconStroke = 1.75;'));
    expect(output, contains('blurRadius: (8 / 2 - 0.5) / 0.57735'));
    expect(output, contains('shadowCard: [],'));
    final quranStyle = output.substring(
      output.indexOf('pageText ='),
      output.indexOf('bigTitle ='),
    );
    expect(quranStyle, isNot(contains('fontFamilyFallback')));
  });

  test('a token whose name clashes with a theme instance stops it', () {
    final json = syntheticTokens();
    colorTokens(json).add({
      'name': 'light',
      'value': {'light': '#000000', 'dark': '#000000'},
    });
    expect(
      () => writeTokens(readTokens(encode(json))),
      throwsGeneratorError('clashes'),
    );
  });
}
