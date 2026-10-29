import 'color_value.dart';
import 'generator_error.dart';
import 'tokens_reader.dart';
import 'tokens_writer.dart' show tokensSourcePath;

/// Where the Android resource lands: native files cannot read the Dart theme,
/// so their colours come from the same tokens through this output (D-117).
const androidColorsOutputPath =
    'android/app/src/main/res/values/brand_colors.xml';

/// The ramp tokens the launcher icon and the launch screen draw with. They
/// are the colours of `app-icon.svg`, `app-icon-mono.svg` and
/// `lockup-horizontal-emerald.svg`; a native file names a colour here, never
/// by its hex.
const androidBrandRamps = ['emerald-700', 'gold-400', 'paper-100'];

/// `emerald-700` → `brand_emerald_700`.
String androidColorName(String token) => 'brand_${token.replaceAll('-', '_')}';

/// The source of `brand_colors.xml`.
String writeAndroidColors(TokenSet tokens) {
  final byName = {for (final ramp in tokens.ramps) ramp.name: ramp.value};
  final out = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="utf-8"?>')
    ..writeln('<!-- GENERATED CODE. DO NOT EDIT BY HAND.')
    ..writeln('     Generated from $tokensSourcePath')
    ..writeln(
      '     by `dart run tools/gen/bin/generate.dart` '
      '(see tools/gen/README.md). -->',
    )
    ..writeln('<resources>');
  for (final token in androidBrandRamps) {
    final value = byName[token];
    if (value is! HexColor) {
      throw GeneratorError(
        'The Android brand colour "$token" is not a #RRGGBB ramp token.',
      );
    }
    out.writeln(
      '    <color name="${androidColorName(token)}">#${value.rrggbb}</color>',
    );
  }
  out.writeln('</resources>');
  return out.toString();
}
