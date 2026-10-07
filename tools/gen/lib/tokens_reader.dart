import 'dart:convert';

import 'color_value.dart';
import 'generator_error.dart';
import 'shadow_value.dart';

/// Everything the generator takes from `tokens.json`.
///
/// Only names, values, theme maps, type metrics, families and fonts are read.
/// The `sample` and `usage` fields are accepted as known keys and never read:
/// `sample` holds illustrative Quran text.
final class TokenSet {
  const TokenSet({
    required this.themeIds,
    required this.colors,
    required this.ramps,
    required this.families,
    required this.styles,
    required this.spacing,
    required this.radius,
    required this.sizes,
    required this.shadows,
  });

  final List<String> themeIds;
  final List<ThemedColor> colors;
  final List<RampColor> ramps;
  final List<FontFamily> families;
  final List<TypeStyle> styles;
  final List<Dimension> spacing;
  final List<Dimension> radius;
  final List<Dimension> sizes;
  final List<ThemedShadow> shadows;
}

/// A colour with one resolved value per theme id.
final class ThemedColor {
  const ThemedColor(this.name, this.byTheme);

  final String name;
  final Map<String, ColorValue> byTheme;
}

/// A colour literal that does not vary by theme.
final class RampColor {
  const RampColor(this.name, this.value);

  final String name;
  final ColorValue value;
}

/// A family key (`quran`) with its first named font and the keys of the
/// families named after it in the stack.
final class FontFamily {
  const FontFamily(this.key, this.name, this.fallbackKeys);

  final String key;
  final String name;
  final List<String> fallbackKeys;
}

final class TypeStyle {
  const TypeStyle({
    required this.name,
    required this.familyKey,
    required this.fontSize,
    required this.lineHeight,
    required this.fontWeight,
  });

  final String name;
  final String familyKey;
  final double fontSize;
  final double lineHeight;
  final int fontWeight;
}

/// A length in logical pixels (CSS px map one to one).
final class Dimension {
  const Dimension(this.name, this.value);

  final String name;
  final double value;
}

final class ThemedShadow {
  const ThemedShadow(this.name, this.byTheme);

  final String name;
  final Map<String, List<ShadowValue>> byTheme;
}

const _ignored = {'sample', 'usage'};

/// Generic CSS families have no Flutter counterpart; they are dropped from
/// a stack. Any other unquoted name stops the generator.
const _genericFamilies = {'serif', 'sans-serif', 'system-ui'};

/// The Quran font is paired with its text; nothing may stand in for it.
const _quranFamilyKey = 'quran';

final _alias = RegExp(r'^\{([^{}]+)\}$');
final _px = RegExp(r'^(\d+(?:\.\d+)?)px$');
final _quoted = RegExp(r'^"([^"]+)"$');
final _weightRange = RegExp(r'^(\d{3})(?: (\d{3}))?$');

TokenSet readTokens(String jsonSource) {
  final Object? decoded;
  try {
    decoded = jsonDecode(jsonSource);
  } on FormatException catch (e) {
    throw GeneratorError('tokens.json is not valid JSON: ${e.message}');
  }
  final root = _map(decoded, 'tokens.json');
  _keys(root, 'tokens.json', {
    'name',
    'version',
    'color',
    'type',
    'spacing',
    'radius',
    'shadow',
    'size',
  });
  if (root['version'] != 1) {
    throw GeneratorError(
      'tokens.json has version ${root['version']}; the generator reads 1.',
    );
  }

  final color = _map(root['color'], 'color');
  _keys(color, 'color', {'themes', 'tokens'});
  final themeIds = _readThemeIds(color['themes']);
  final (colors, ramps) = _readColors(color['tokens'], themeIds);

  final type = _map(root['type'], 'type');
  _keys(type, 'type', {'fonts', 'families', 'groups'});
  final fontWeights = _readFonts(type['fonts']);
  final families = _readFamilies(type['families'], fontWeights.keys.toSet());
  final styles = _readStyles(type['groups'], families, fontWeights);

  return TokenSet(
    themeIds: themeIds,
    colors: colors,
    ramps: ramps,
    families: families,
    styles: styles,
    spacing: _readDimensions(root['spacing'], 'spacing'),
    radius: _readDimensions(root['radius'], 'radius'),
    sizes: _readDimensions(root['size'], 'size'),
    shadows: _readShadows(root['shadow'], themeIds),
  );
}

List<String> _readThemeIds(Object? json) {
  final ids = <String>[];
  for (final (i, entry) in _list(json, 'color.themes').indexed) {
    final theme = _map(entry, 'color.themes[$i]');
    _keys(theme, 'color.themes[$i]', {'id', 'name'});
    final id = _string(theme['id'], 'color.themes[$i].id');
    if (!RegExp(r'^[a-z][a-zA-Z0-9]*$').hasMatch(id)) {
      throw GeneratorError('Theme id "$id" is not a Dart identifier.');
    }
    if (ids.contains(id)) {
      throw GeneratorError('Theme id "$id" appears twice.');
    }
    ids.add(id);
  }
  if (ids.isEmpty) throw GeneratorError('color.themes is empty.');
  return ids;
}

(List<ThemedColor>, List<RampColor>) _readColors(
  Object? json,
  List<String> themeIds,
) {
  final raw = <String, Object>{};
  for (final (i, entry) in _list(json, 'color.tokens').indexed) {
    final where = 'color.tokens[$i]';
    final token = _map(entry, where);
    _keys(token, where, {'name', 'value', ..._ignored});
    final name = _string(token['name'], '$where.name');
    if (raw.containsKey(name)) {
      throw GeneratorError('Colour token "$name" appears twice.');
    }
    final value = token['value'];
    if (value is String) {
      raw[name] = value;
    } else {
      raw[name] = _themeMap(value, '$where.value', themeIds);
    }
  }

  ColorValue resolve(String name, String theme, List<String> chain) {
    if (chain.contains(name)) {
      throw GeneratorError(
        'Colour aliases form a cycle: ${[...chain, name].join(' -> ')}.',
      );
    }
    final value = raw[name];
    if (value == null) {
      throw GeneratorError(
        'Colour "${chain.lastOrNull}" refers to unknown token "{$name}".',
      );
    }
    final text = value is Map<String, String> ? value[theme]! : value as String;
    final alias = _alias.firstMatch(text);
    if (alias != null) return resolve(alias.group(1)!, theme, [...chain, name]);
    if (text.contains('{') || text.contains('}')) {
      throw GeneratorError('Colour "$name" has a malformed alias "$text".');
    }
    return ColorValue.parse(text);
  }

  final colors = <ThemedColor>[];
  final ramps = <RampColor>[];
  for (final MapEntry(key: name, :value) in raw.entries) {
    final isLiteral = value is String && !_alias.hasMatch(value);
    if (isLiteral) {
      ramps.add(RampColor(name, resolve(name, themeIds.first, const [])));
    } else {
      colors.add(
        ThemedColor(name, {
          for (final theme in themeIds) theme: resolve(name, theme, const []),
        }),
      );
    }
  }
  return (colors, ramps);
}

/// Family name → the weights its font files cover.
Map<String, Set<int>> _readFonts(Object? json) {
  final weights = <String, Set<int>>{};
  for (final (i, entry) in _list(json, 'type.fonts').indexed) {
    final where = 'type.fonts[$i]';
    final font = _map(entry, where);
    _keys(font, where, {'family', 'file', 'weight'});
    final family = _string(font['family'], '$where.family');
    final weight = _string(font['weight'], '$where.weight');
    final match = _weightRange.firstMatch(weight);
    if (match == null) {
      throw GeneratorError(
        '$where.weight "$weight" is not "400" or "400 700".',
      );
    }
    final low = int.parse(match.group(1)!);
    final high = int.parse(match.group(2) ?? match.group(1)!);
    weights.putIfAbsent(family, () => {}).addAll([
      for (var w = low; w <= high; w += 100) w,
    ]);
  }
  return weights;
}

List<FontFamily> _readFamilies(Object? json, Set<String> fontNames) {
  final families = _map(json, 'type.families');
  final primaries = <String, String>{};
  final stacks = <String, List<String>>{};
  for (final MapEntry(:key, :value) in families.entries) {
    if (!RegExp(r'^[a-z][a-zA-Z0-9]*$').hasMatch(key)) {
      throw GeneratorError('Family key "$key" is not a Dart identifier.');
    }
    final stack = _string(
      value,
      'type.families.$key',
    ).split(',').map((s) => s.trim()).toList();
    final first = _quoted.firstMatch(stack.first);
    if (first == null) {
      throw GeneratorError('Family "$key" does not start with a quoted name.');
    }
    final name = first.group(1)!;
    if (!fontNames.contains(name)) {
      throw GeneratorError(
        'Family "$key" names "$name", which has no font file.',
      );
    }
    primaries[key] = name;
    stacks[key] = stack.skip(1).toList();
  }

  return [
    for (final key in primaries.keys)
      FontFamily(key, primaries[key]!, [
        for (final item in stacks[key]!)
          if (!_genericFamilies.contains(item))
            _fallbackKey(key, item, primaries),
      ]),
  ].map(_checkQuranHasNoFallback).toList();
}

String _fallbackKey(String key, String item, Map<String, String> primaries) {
  final quoted = _quoted.firstMatch(item);
  if (quoted == null) {
    throw GeneratorError('Family "$key" has an unknown entry "$item".');
  }
  for (final MapEntry(key: other, value: name) in primaries.entries) {
    if (name == quoted.group(1)) return other;
  }
  throw GeneratorError(
    'Family "$key" falls back to "${quoted.group(1)}", which is not a family.',
  );
}

FontFamily _checkQuranHasNoFallback(FontFamily family) {
  if (family.key == _quranFamilyKey && family.fallbackKeys.isNotEmpty) {
    throw GeneratorError('The Quran family must have no fallback font.');
  }
  return family;
}

List<TypeStyle> _readStyles(
  Object? json,
  List<FontFamily> families,
  Map<String, Set<int>> fontWeights,
) {
  final styles = <TypeStyle>[];
  for (final (g, entry) in _list(json, 'type.groups').indexed) {
    final where = 'type.groups[$g]';
    final group = _map(entry, where);
    _keys(group, where, {'name', 'family', 'styles'});
    final familyKey = _string(group['family'], '$where.family');
    final family = families.where((f) => f.key == familyKey).firstOrNull;
    if (family == null) {
      throw GeneratorError('$where names unknown family "$familyKey".');
    }
    for (final (s, styleEntry) in _list(
      group['styles'],
      '$where.styles',
    ).indexed) {
      final at = '$where.styles[$s]';
      final style = _map(styleEntry, at);
      _keys(style, at, {
        'name',
        'fontSize',
        'lineHeight',
        'fontWeight',
        ..._ignored,
      });
      final name = _string(style['name'], '$at.name');
      final weight = style['fontWeight'];
      if (weight is! int || !fontWeights[family.name]!.contains(weight)) {
        throw GeneratorError(
          'Style "$name" has weight $weight, which ${family.name} does not cover.',
        );
      }
      final lineHeight = style['lineHeight'];
      if (lineHeight is! num || lineHeight <= 0) {
        throw GeneratorError('Style "$name" has line height "$lineHeight".');
      }
      styles.add(
        TypeStyle(
          name: name,
          familyKey: familyKey,
          fontSize: _parsePx(style['fontSize'], '$name.fontSize'),
          lineHeight: lineHeight.toDouble(),
          fontWeight: weight,
        ),
      );
    }
  }
  return styles;
}

List<Dimension> _readDimensions(Object? json, String group) {
  final map = _map(json, group);
  _keys(map, group, {'tokens'});
  return [
    for (final (i, entry) in _list(map['tokens'], '$group.tokens').indexed)
      _readDimension(entry, '$group.tokens[$i]'),
  ];
}

Dimension _readDimension(Object? entry, String where) {
  final token = _map(entry, where);
  _keys(token, where, {'name', 'value', ..._ignored});
  final name = _string(token['name'], '$where.name');
  return Dimension(name, _parsePx(token['value'], name));
}

List<ThemedShadow> _readShadows(Object? json, List<String> themeIds) {
  final map = _map(json, 'shadow');
  _keys(map, 'shadow', {'tokens'});
  return [
    for (final (i, entry) in _list(map['tokens'], 'shadow.tokens').indexed)
      _readShadow(entry, 'shadow.tokens[$i]', themeIds),
  ];
}

ThemedShadow _readShadow(Object? entry, String where, List<String> themeIds) {
  final token = _map(entry, where);
  _keys(token, where, {'name', 'value', ..._ignored});
  final name = _string(token['name'], '$where.name');
  final values = _themeMap(token['value'], '$where.value', themeIds);
  return ThemedShadow(name, {
    for (final theme in themeIds) theme: ShadowValue.parseList(values[theme]!),
  });
}

/// A value with exactly one string per theme id.
Map<String, String> _themeMap(
  Object? json,
  String where,
  List<String> themeIds,
) {
  final map = _map(json, where);
  for (final key in map.keys) {
    if (!themeIds.contains(key)) {
      throw GeneratorError('$where has unknown theme id "$key".');
    }
  }
  return {
    for (final theme in themeIds)
      theme: map.containsKey(theme)
          ? _string(map[theme], '$where.$theme')
          : throw GeneratorError('$where has no value for theme "$theme".'),
  };
}

double _parsePx(Object? json, String where) {
  final match = _px.firstMatch(_string(json, where));
  if (match == null) {
    throw GeneratorError('$where "$json" is not a length in px.');
  }
  return double.parse(match.group(1)!);
}

Map<String, Object?> _map(Object? json, String where) {
  if (json is Map<String, Object?>) return json;
  throw GeneratorError('$where is not an object.');
}

List<Object?> _list(Object? json, String where) {
  if (json is List<Object?>) return json;
  throw GeneratorError('$where is not a list.');
}

String _string(Object? json, String where) {
  if (json is String) return json;
  throw GeneratorError('$where is not a string.');
}

void _keys(Map<String, Object?> map, String where, Set<String> allowed) {
  for (final key in map.keys) {
    if (!allowed.contains(key)) {
      throw GeneratorError('$where has an unknown field "$key".');
    }
  }
}
