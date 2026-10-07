import 'dart_literals.dart';
import 'generated_header.dart';
import 'generator_error.dart';
import 'names.dart';
import 'tokens_reader.dart';

const tokensSourcePath = 'design/design-system/tokens.json';

/// The source of `tokens.g.dart`, before formatting.
String writeTokens(TokenSet tokens) {
  final out = StringBuffer(generatedHeader([tokensSourcePath]))
    ..writeln("import 'package:flutter/material.dart';")
    ..writeln();
  _writeColors(out, tokens);
  _writeShadows(out, tokens);
  _writeFonts(out, tokens);
  _writeStyles(out, tokens);
  _writeDimensions(out, 'AppSpacing', tokens.spacing);
  _writeDimensions(out, 'AppRadius', tokens.radius);
  _writeDimensions(out, 'AppSizes', tokens.sizes);
  return out.toString();
}

void _writeColors(StringBuffer out, TokenSet tokens) {
  final fields = [for (final c in tokens.colors) camelCase(c.name)];
  _checkFields(fields, tokens.themeIds, 'AppColors');
  out.writeln('/// Semantic colours, one instance per reading theme.');
  _writeExtension(
    out,
    className: 'AppColors',
    fieldType: 'Color',
    fields: fields,
    themeIds: tokens.themeIds,
    valueOf: (field, theme) =>
        tokens.colors[fields.indexOf(field)].byTheme[theme]!.toDart(),
    lerpOf: (field) => 'Color.lerp($field, other.$field, t)!',
  );
}

void _writeShadows(StringBuffer out, TokenSet tokens) {
  final fields = [for (final s in tokens.shadows) camelCase(s.name)];
  _checkFields(fields, tokens.themeIds, 'AppShadows');
  out
    ..writeln('/// Elevation shadows, one instance per reading theme.')
    ..writeln('///')
    ..writeln('/// CSS draws a blur of B as a Gaussian with sigma B / 2;')
    ..writeln("/// Flutter's BoxShadow turns blurRadius r into sigma")
    ..writeln('/// r * 0.57735 + 0.5. Each blurRadius is therefore')
    ..writeln(
      '/// (B / 2 - 0.5) / 0.57735, so the shadows match the identity.',
    );
  _writeExtension(
    out,
    className: 'AppShadows',
    fieldType: 'List<BoxShadow>',
    fields: fields,
    themeIds: tokens.themeIds,
    valueOf: (field, theme) {
      final shadows = tokens.shadows[fields.indexOf(field)].byTheme[theme]!;
      return '[${shadows.map((s) => s.toDart()).join(', ')}]';
    },
    lerpOf: (field) => 'BoxShadow.lerpList($field, other.$field, t)!',
  );
}

void _writeExtension(
  StringBuffer out, {
  required String className,
  required String fieldType,
  required List<String> fields,
  required List<String> themeIds,
  required String Function(String field, String theme) valueOf,
  required String Function(String field) lerpOf,
}) {
  out
    ..writeln('final class $className extends ThemeExtension<$className> {')
    ..writeln('const $className({')
    ..writeAll([for (final f in fields) 'required this.$f,'], '\n')
    ..writeln('});')
    ..writeln();
  for (final theme in themeIds) {
    out.writeln('static const $className $theme = $className(');
    for (final field in fields) {
      out.writeln('$field: ${valueOf(field, theme)},');
    }
    out
      ..writeln(');')
      ..writeln();
  }
  out
    ..writeln('/// The instances keyed by theme id.')
    ..writeln('static const Map<String, $className> byId = {')
    ..writeAll([for (final t in themeIds) '${stringLiteral(t)}: $t,'], '\n')
    ..writeln('};')
    ..writeln();
  for (final field in fields) {
    out.writeln('final $fieldType $field;');
  }
  out
    ..writeln()
    ..writeln('@override')
    ..writeln('$className copyWith({')
    ..writeAll([for (final f in fields) '$fieldType? $f,'], '\n')
    ..writeln('}) => $className(')
    ..writeAll([for (final f in fields) '$f: $f ?? this.$f,'], '\n')
    ..writeln(');')
    ..writeln()
    ..writeln('@override')
    ..writeln('$className lerp(ThemeExtension<$className>? other, double t) {')
    ..writeln('if (other is! $className) return this;')
    ..writeln('return $className(')
    ..writeAll([for (final f in fields) '$f: ${lerpOf(f)},'], '\n')
    ..writeln(');')
    ..writeln('}')
    ..writeln('}')
    ..writeln();
}

void _writeFonts(StringBuffer out, TokenSet tokens) {
  out
    ..writeln('/// Font families as registered in pubspec.yaml.')
    ..writeln('abstract final class AppFonts {');
  for (final family in tokens.families) {
    out.writeln(
      'static const String ${family.key} = ${stringLiteral(family.name)};',
    );
  }
  out
    ..writeln('}')
    ..writeln();
}

void _writeStyles(StringBuffer out, TokenSet tokens) {
  final names = [for (final s in tokens.styles) camelCase(s.name)];
  requireUnique(names, 'type styles');
  out
    ..writeln('/// The named type styles. They carry no colour.')
    ..writeln('abstract final class AppTextStyles {');
  for (final (i, style) in tokens.styles.indexed) {
    final family = tokens.families.firstWhere((f) => f.key == style.familyKey);
    final fallbacks = [for (final k in family.fallbackKeys) 'AppFonts.$k'];
    out
      ..writeln('static const TextStyle ${names[i]} = TextStyle(')
      ..writeln('fontFamily: AppFonts.${family.key},');
    if (fallbacks.isNotEmpty) {
      out.writeln('fontFamilyFallback: [${fallbacks.join(', ')}],');
    }
    out
      ..writeln('fontSize: ${numberLiteral(style.fontSize)},')
      ..writeln('height: ${numberLiteral(style.lineHeight)},')
      ..writeln('fontWeight: FontWeight.w${style.fontWeight},')
      ..writeln('letterSpacing: 0,')
      ..writeln('leadingDistribution: TextLeadingDistribution.even,')
      ..writeln(');')
      ..writeln();
  }
  out
    ..writeln('}')
    ..writeln();
}

void _writeDimensions(
  StringBuffer out,
  String className,
  List<Dimension> dimensions,
) {
  final names = [for (final d in dimensions) camelCase(d.name)];
  requireUnique(names, className);
  out
    ..writeln('/// Logical pixels; one CSS px is one logical pixel.')
    ..writeln('abstract final class $className {');
  for (final (i, dimension) in dimensions.indexed) {
    out.writeln(
      'static const double ${names[i]} = ${numberLiteral(dimension.value)};',
    );
  }
  out
    ..writeln('}')
    ..writeln();
}

/// Members every extension declares besides its fields.
const _extensionMembers = {
  'byId',
  'copyWith',
  'lerp',
  'type',
  'hashCode',
  'runtimeType',
  'toString',
  'noSuchMethod',
};

void _checkFields(List<String> fields, List<String> themeIds, String where) {
  if (fields.isEmpty) throw GeneratorError('$where has no tokens.');
  requireUnique(fields, where);
  requireUnique(themeIds, 'the theme ids');
  for (final theme in themeIds) {
    if (_extensionMembers.contains(theme)) {
      throw GeneratorError(
        'Theme id "$theme" clashes with a member of $where.',
      );
    }
  }
  for (final field in fields) {
    if (_extensionMembers.contains(field) || themeIds.contains(field)) {
      throw GeneratorError(
        'Token "$field" in $where clashes with a member of the class.',
      );
    }
  }
}
