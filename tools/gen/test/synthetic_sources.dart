import 'dart:convert';

/// A small, obviously synthetic `tokens.json` in the identity's shape. Tests
/// change it before encoding it with [encode].
Map<String, Object?> syntheticTokens() => {
  'name': 'Synthetic',
  'version': 1,
  'color': {
    'themes': [
      {'id': 'light', 'name': 'Light'},
      {'id': 'dark', 'name': 'Dark'},
    ],
    'tokens': <Object?>[
      {'name': 'base-100', 'value': '#F0F0F0', 'usage': 'USAGE_MARKER'},
      {'name': 'base-900', 'value': '#101010'},
      {
        'name': 'ground',
        'value': {'light': '{base-100}', 'dark': '#000000'},
      },
      {
        'name': 'ink',
        'value': {'light': '{base-900}', 'dark': 'rgba(255,255,255,0.87)'},
      },
      {'name': 'text-ink', 'value': '{ink}'},
    ],
  },
  'type': {
    'fonts': [
      {'family': 'Text Face', 'file': 'fonts/a.woff2', 'weight': '400'},
      {'family': 'Title Face', 'file': 'fonts/b.woff2', 'weight': '400 700'},
    ],
    'families': {
      'quran': '"Text Face", serif',
      'kufi': '"Title Face", "Text Face", sans-serif',
    },
    'groups': [
      {
        'name': 'Group A',
        'family': 'quran',
        'styles': [
          {
            'name': 'page-text',
            'fontSize': '20px',
            'lineHeight': 2.0,
            'fontWeight': 400,
            'sample': 'SAMPLE_MARKER',
            'usage': 'USAGE_MARKER',
          },
        ],
      },
      {
        'name': 'Group B',
        'family': 'kufi',
        'styles': [
          {
            'name': 'big-title',
            'fontSize': '30px',
            'lineHeight': 1.25,
            'fontWeight': 700,
          },
        ],
      },
    ],
  },
  'spacing': {
    'tokens': [
      {'name': 'space-1', 'value': '4px'},
    ],
  },
  'radius': {
    'tokens': [
      {'name': 'radius-full', 'value': '9999px'},
    ],
  },
  'shadow': {
    'tokens': [
      {
        'name': 'shadow-card',
        'value': {'light': '0 2px 8px rgba(0,0,0,0.10)', 'dark': 'none'},
      },
    ],
  },
  'size': {
    'tokens': [
      {'name': 'icon-stroke', 'value': '1.75px'},
    ],
  },
};

String encode(Map<String, Object?> tokens) => jsonEncode(tokens);

/// The colour token list of [tokens], for tests that change it.
List<Object?> colorTokens(Map<String, Object?> tokens) =>
    (tokens['color']! as Map<String, Object?>)['tokens']! as List<Object?>;

/// A components file with the three declarations the generator reads.
String syntheticComponents({
  String icons =
      "  square: '<path d=\"M4 4h16v16H4z\"/>',\n"
      "  ring: '<circle cx=\"12\" cy=\"12\" r=\"8\"/>',\n"
      "  index: '<rect x=\"4\" y=\"4\" width=\"16\" height=\"8\" rx=\"2\"/>',\n",
  String filled = 'square: 1',
  String book = 'M10 10L20 10L20 20z',
}) =>
    'const React = window.React;\n'
    'const ICONS = {\n'
    '$icons'
    '};\n'
    'const FILLED = { $filled };\n'
    "const BOOK = '$book';\n";

String syntheticTypes({String names = "'square' | 'ring' | 'index'"}) =>
    'export type IconName = $names;\n';
