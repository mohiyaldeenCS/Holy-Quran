import 'package:flutter_test/flutter_test.dart';

import '../lib/android_colors_writer.dart';
import '../lib/generator_error.dart';
import '../lib/tokens_reader.dart';
import 'synthetic_sources.dart';

Matcher throwsGeneratorError(String fragment) => throwsA(
  isA<GeneratorError>().having((e) => e.message, 'message', contains(fragment)),
);

void main() {
  test('writes each brand ramp as an Android colour, in the fixed order', () {
    final xml = writeAndroidColors(readTokens(encode(syntheticTokens())));
    expect(
      RegExp(
        r'<color name="(\w+)">#([0-9A-F]{6})</color>',
      ).allMatches(xml).map((m) => (m[1], m[2])),
      [
        ('brand_emerald_700', '0E5A52'),
        ('brand_gold_400', 'D9AE5A'),
        ('brand_paper_100', 'F8F2E4'),
      ],
    );
    expect(xml, startsWith('<?xml version="1.0" encoding="utf-8"?>\n<!--'));
  });

  test('a missing brand token stops the generator', () {
    final json = syntheticTokens();
    colorTokens(json).removeWhere((t) => (t! as Map)['name'] == 'gold-400');
    expect(
      () => writeAndroidColors(readTokens(encode(json))),
      throwsGeneratorError('gold-400'),
    );
  });

  test('a brand token that is not #RRGGBB stops the generator', () {
    final json = syntheticTokens();
    final token =
        colorTokens(json).firstWhere((t) => (t! as Map)['name'] == 'paper-100')!
            as Map<String, Object?>;
    token['value'] = 'rgba(248,242,228,0.5)';
    expect(
      () => writeAndroidColors(readTokens(encode(json))),
      throwsGeneratorError('paper-100'),
    );
  });
}
