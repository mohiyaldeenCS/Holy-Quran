import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/android_colors_writer.dart';

const _logos = 'design/design-system/assets/Logos';
const _res = 'android/app/src/main/res';

/// A shape of a logo, as the SVG states it and as the vector drawable must
/// state it. A colour is a token name (`gold-400`), never a hex.
typedef _Shape = ({
  String pathData,
  String? fill,
  String? fillAlpha,
  String? stroke,
  String? strokeWidth,
  String? strokeLineJoin,
});

String _read(String path) => File(path).readAsStringSync();

/// Whether [xml] writes a colour as a quoted attribute value or as element
/// text.
bool _hasColourLiteral(String xml) =>
    RegExp(r'''["'>]\s*#[0-9A-Fa-f]{3,8}\s*["'<]''').hasMatch(xml);

/// Whether [xml] takes a colour from the platform (`@android:color/white`)
/// instead of from the brand resource.
bool _hasSystemColour(String xml) => RegExp(r'@android:color/').hasMatch(xml);

Map<String, String> _attributes(String element) => {
  for (final match in RegExp(
    r'([\w:-]+)="([^"]*)"',
  ).allMatches(element.replaceFirst(RegExp(r'^<\w+'), '')))
    match[1]!: match[2]!,
};

/// File name → SHA-256 from the logo table of `design/README.md`.
Map<String, String> _pinnedLogoHashes() => {
  for (final match in RegExp(
    r'\| `([\w-]+\.svg)` \| `[0-9a-f]{32}` \| `([0-9a-f]{64})` \|',
  ).allMatches(_read('design/README.md')))
    match[1]!: match[2]!,
};

/// Colour name (`brand_gold_400`) → hex, from the generated resource.
Map<String, String> _brandColors() => {
  for (final match in RegExp(
    r'<color name="(\w+)">#([0-9A-F]{6})</color>',
  ).allMatches(_read('$_res/values/brand_colors.xml')))
    match[1]!: match[2]!,
};

/// Ramp token name → hex, from `tokens.json`.
Map<String, String> _ramps() {
  final tokens = jsonDecode(
    _read('design/design-system/tokens.json'),
  ) as Map<String, Object?>;
  final list =
      (tokens['color']! as Map<String, Object?>)['tokens']! as List<Object?>;
  return {
    for (final token in list.cast<Map<String, Object?>>())
      if (token['value'] case final String value
          when RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value))
        token['name'] as String: value.substring(1).toUpperCase(),
  };
}

String _number(double value) =>
    double.parse(value.toStringAsFixed(4))
        .toString()
        .replaceFirst(RegExp(r'\.0$'), '');

String _hexToToken(String hex) => _ramps().entries
    .singleWhere((entry) => entry.value == hex.substring(1).toUpperCase())
    .key;

/// The shapes of a logo's mark, in drawing order, from its SVG; a tile
/// rectangle is not a shape of the mark.
List<_Shape> _svgShapes(String svg) {
  final shapes = <_Shape>[];
  final body = svg.replaceAll(RegExp(r'<title>.*?</title>'), '');
  for (final match in RegExp(r'<(rect|path|circle)\b[^>]*>').allMatches(body)) {
    final a = _attributes(match[0]!);
    // The star is drawn in a group whose paint the rects inherit.
    final group = RegExp(
      r'<g fill="([^"]+)"( fill-opacity="([^"]+)")? stroke="([^"]+)" '
      r'stroke-width="([^"]+)" stroke-linejoin="([^"]+)"',
    ).allMatches(body.substring(0, match.start)).lastOrNull;
    final inStar = a.containsKey('x');
    if (a.containsKey('width') && !inStar) continue;
    if (match[1] == 'path' && a.containsKey('transform')) continue;
    if (match[1] == 'path' && !a.containsKey('fill')) continue;
    final fill = group?[1] == 'none' ? null : group?[1];
    shapes.add(switch (match[1]) {
      'rect' => (
        pathData:
            'M${a['x']} ${a['y']}h${a['width']}v${a['height']}'
            'h-${a['width']}z',
        fill: fill == null ? null : _hexToToken(fill),
        fillAlpha: group?[3],
        stroke: _hexToToken(group![4]!),
        strokeWidth: group[5],
        strokeLineJoin: group[6],
      ),
      'circle' => (
        pathData: _circle(
          double.parse(a['cx']!),
          double.parse(a['cy']!),
          double.parse(a['r']!),
        ),
        fill: _hexToToken(a['fill']!),
        fillAlpha: null,
        stroke: null,
        strokeWidth: null,
        strokeLineJoin: null,
      ),
      _ => (
        pathData: a['d']!,
        fill: _hexToToken(a['fill']!),
        fillAlpha: null,
        stroke: null,
        strokeWidth: null,
        strokeLineJoin: null,
      ),
    });
  }
  return shapes;
}

String _circle(double cx, double cy, double r) =>
    'M${_number(cx - r)} ${_number(cy)}'
    'a${_number(r)} ${_number(r)} 0 1 0 ${_number(2 * r)} 0'
    'a${_number(r)} ${_number(r)} 0 1 0 -${_number(2 * r)} 0z';

/// The paths of a vector drawable, in document order, groups flattened.
List<_Shape> _drawableShapes(String xml) {
  final colors = _brandColors();
  final ramps = _ramps();
  String? token(String? reference) {
    if (reference == null) return null;
    final name = reference.replaceFirst('@color/', '');
    return ramps.entries.singleWhere((e) => e.value == colors[name]).key;
  }

  return [
    for (final match in RegExp(r'<path\b[^>]*>').allMatches(xml))
      if (_attributes(match[0]!) case final a)
        (
          pathData: a['android:pathData']!,
          fill: token(a['android:fillColor']),
          fillAlpha: a['android:fillAlpha'],
          stroke: token(a['android:strokeColor']),
          strokeWidth: a['android:strokeWidth'],
          strokeLineJoin: a['android:strokeLineJoin'],
        ),
  ];
}

/// The attributes of every `<group>` of a drawable, in document order.
List<Map<String, String>> _groups(String xml) => [
  for (final match in RegExp(r'<group\b[^>]*>').allMatches(xml))
    _attributes(match[0]!),
];

/// Asserts that the star's second square is the only path inside a group
/// rotated 45 degrees about the logo's centre, as the SVGs draw it.
void _expectRotatedSquare(String xml) {
  final rotated = RegExp(
    r'<group\b[^>]*android:rotation="45"[^>]*>(.*?)</group>',
    dotAll: true,
  ).firstMatch(xml);
  expect(rotated, isNotNull);
  final group = _attributes(
    RegExp(r'<group\b[^>]*>').firstMatch(rotated![0]!)![0]!,
  );
  expect(group['android:pivotX'], '60');
  expect(group['android:pivotY'], '60');
  expect(
    [for (final path in _drawableShapes(rotated[1]!)) path.pathData],
    ['M32 32h56v56h-56z'],
  );
}

/// The shapes of the app icon without its background rectangle.
List<_Shape> _iconShapes(String svg) =>
    _svgShapes(svg.replaceFirst(RegExp(r'<rect width="120"[^>]*>'), ''));

void main() {
  group('the logo files', () {
    final pinned = _pinnedLogoHashes();

    test('the README pins all thirteen', () {
      expect(pinned, hasLength(13));
    });

    for (final MapEntry(key: name, value: hash) in pinned.entries) {
      test('$name equals its pinned SHA-256', () {
        final bytes = File('$_logos/$name').readAsBytesSync();
        expect(sha256.convert(bytes).toString(), hash);
      });
    }
  });

  group('colours', () {
    test('the generated resource holds the brand ramps and nothing else', () {
      expect(_brandColors().keys, [
        for (final token in androidBrandRamps) androidColorName(token),
      ]);
    });

    test('no resource except the generated one writes a colour literal', () {
      final offenders = [
        for (final file in Directory(_res).listSync(recursive: true))
          if (file is File &&
              file.path.endsWith('.xml') &&
              !file.path.replaceAll(r'\', '/').endsWith('brand_colors.xml') &&
              _hasColourLiteral(file.readAsStringSync()))
            file.path,
      ];
      expect(offenders, isEmpty);
    });

    test('no resource takes a colour from the platform', () {
      final offenders = [
        for (final file in Directory(_res).listSync(recursive: true))
          if (file is File &&
              file.path.endsWith('.xml') &&
              _hasSystemColour(file.readAsStringSync()))
            file.path,
      ];
      expect(offenders, isEmpty);
    });

    test('the system-colour scan sees every way to name one', () {
      const system = [
        '<vector android:fillColor="@android:color/white"/>',
        '<item name="android:statusBarColor">@android:color/black</item>',
        '<item name="android:windowBackground">@android:color/black</item>',
      ];
      for (final xml in system) {
        expect(_hasSystemColour(xml), isTrue, reason: xml);
      }
      const clean = [
        '<item name="android:statusBarColor">@color/brand_emerald_700</item>',
        '<item name="android:windowBackground">@drawable/launch</item>',
        '<item name="android:windowBackground">@android:drawable/x</item>',
      ];
      for (final xml in clean) {
        expect(_hasSystemColour(xml), isFalse, reason: xml);
      }
    });

    test('the literal scan sees attribute values and element text', () {
      const literals = [
        '<vector android:fillColor="#FFFFFF"/>',
        "<vector android:fillColor='#123'/>",
        '<item name="android:statusBarColor">#FFFFFF</item>',
        '<color name="x">#123456</color>',
        '<color name="x">\n  #12345678\n</color>',
      ];
      for (final xml in literals) {
        expect(_hasColourLiteral(xml), isTrue, reason: xml);
      }
      const clean = [
        '<item name="android:statusBarColor">@color/brand_emerald_700</item>',
        '<string name="app_name">Title #1</string>',
        '<!-- see issue #123 -->',
      ];
      for (final xml in clean) {
        expect(_hasColourLiteral(xml), isFalse, reason: xml);
      }
    });

    test('every colour a resource references is a brand colour', () {
      final known = _brandColors().keys.toSet();
      final used = {
        for (final file in Directory(_res).listSync(recursive: true))
          if (file is File && file.path.endsWith('.xml'))
            for (final match in RegExp(
              r'@color/(\w+)',
            ).allMatches(file.readAsStringSync()))
              match[1]!,
      };
      expect(used, isNotEmpty);
      expect(known.containsAll(used), isTrue, reason: '$used');
    });
  });

  group('the launcher icon', () {
    test('is an adaptive icon over the emerald background', () {
      final icon = _read('$_res/mipmap-anydpi/ic_launcher.xml');
      expect(icon, contains('<adaptive-icon'));
      expect(
        icon,
        contains('<background android:drawable="@color/brand_emerald_700"'),
      );
      expect(icon, contains('@drawable/ic_launcher_foreground'));
      expect(icon, contains('@drawable/ic_launcher_monochrome'));
    });

    test('the background colour is the one of app-icon-fullbleed.svg', () {
      final svg = _read('$_logos/app-icon-fullbleed.svg');
      final tile = RegExp(r'<rect width="120"[^>]*fill="(#\w+)"')
          .firstMatch(svg);
      expect(_hexToToken(tile![1]!), 'emerald-700');
    });

    test('the foreground has the shapes of app-icon-fullbleed.svg', () {
      final drawable = _read('$_res/drawable/ic_launcher_foreground.xml');
      expect(
        _drawableShapes(drawable),
        _iconShapes(_read('$_logos/app-icon-fullbleed.svg')),
      );
    });

    test('the monochrome layer has the shapes of app-icon-mono.svg', () {
      final drawable = _read('$_res/drawable/ic_launcher_monochrome.xml');
      expect(
        _drawableShapes(drawable),
        _iconShapes(_read('$_logos/app-icon-mono.svg')),
      );
    });

    for (final name in ['ic_launcher_foreground', 'ic_launcher_monochrome']) {
      test('$name keeps the star inside the 66 dp safe zone', () {
        final xml = _read('$_res/drawable/$name.xml');
        final vector = _attributes(
          RegExp(r'<vector\b[^>]*>').firstMatch(xml)![0]!,
        );
        final viewport = double.parse(vector['android:viewportWidth']!);
        final canvas = double.parse(
          vector['android:width']!.replaceAll('dp', ''),
        );
        final place = _groups(xml).first;
        expect(
          double.parse(place['android:translateX']!),
          (viewport - 120) / 2,
        );
        // The star's points: half the diagonal of the 56-unit square, plus
        // half the stroke at a round join.
        final reach = (56 * 1.41421356 / 2 + 2.4 / 2) * canvas / viewport;
        expect(reach, lessThanOrEqualTo(66 / 2));
        expect(
          double.parse(place['android:translateY']!),
          (viewport - 120) / 2,
        );
        _expectRotatedSquare(xml);
      });
    }

    test('no raster launcher icon is left', () {
      final rasters = [
        for (final file in Directory(_res).listSync(recursive: true))
          if (file is File &&
              RegExp(r'\.(png|jpe?g|webp)$').hasMatch(file.path))
            file.path,
      ];
      expect(rasters, isEmpty);
    });

    test('the manifest names the icon and the Arabic app name', () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
      expect(manifest, contains('android:label="@string/app_name"'));
    });

    test('the app name is the ARB file\'s appTitle', () {
      final title = (jsonDecode(
        _read('lib/l10n/app_ar.arb'),
      ) as Map<String, Object?>)['appTitle'];
      final name = RegExp(r'<string name="app_name">([^<]*)</string>')
          .firstMatch(_read('$_res/values/strings.xml'))![1];
      expect(name, title);
    });
  });

  group('the launch screen', () {
    const lockup = '$_logos/lockup-horizontal-emerald.svg';

    test('is the lockup on emerald-700, centred', () {
      final screen = _read('$_res/drawable/launch_background.xml');
      expect(screen, contains('android:drawable="@color/brand_emerald_700"'));
      expect(screen, contains('android:drawable="@drawable/launch_lockup"'));
      expect(screen, contains('android:gravity="center"'));
    });

    test('the lockup drawable has the shapes and frame of the SVG', () {
      final svg = _read(lockup);
      final xml = _read('$_res/drawable/launch_lockup.xml');
      final box = RegExp(r'viewBox="0 0 ([\d.]+) ([\d.]+)"').firstMatch(svg)!;
      final vector = _attributes(
        RegExp(r'<vector\b[^>]*>').firstMatch(xml)![0]!,
      );
      expect(vector['android:viewportWidth'], box[1]);
      expect(vector['android:viewportHeight'], box[2]);

      final name = RegExp(
        r'<path transform="translate\(([-\d.]+),([-\d.]+)\)" fill="(#\w+)" d="([^"]*)"',
      ).firstMatch(svg)!;
      final shapes = _svgShapes(svg);
      final drawn = _drawableShapes(xml);
      expect(drawn.take(drawn.length - 1), shapes);
      _expectRotatedSquare(xml);
      expect(drawn.last.pathData, name[4]);
      expect(drawn.last.fill, _hexToToken(name[3]!));

      final groups = _groups(xml);
      final mark = RegExp(
        r'<g transform="translate\(([-\d.]+),[-\d.]+\) scale\(([\d.]+)\)"',
      ).firstMatch(svg)!;
      expect(
        double.parse(groups[0]['android:translateX']!),
        double.parse(mark[1]!),
      );
      expect(groups[0]['android:scaleX'], mark[2]);
      expect(groups[0]['android:scaleY'], mark[2]);
      expect(groups[0]['android:translateY'], isNull);
      expect(groups[0]['android:pivotX'], isNull);
      expect(groups[0]['android:pivotY'], isNull);
      final text = groups.last;
      expect(double.parse(text['android:translateX']!), double.parse(name[1]!));
      expect(double.parse(text['android:translateY']!), double.parse(name[2]!));
    });

    test('the lockup is drawn at the board\'s 64 dp mark', () {
      final xml = _read('$_res/drawable/launch_lockup.xml');
      final vector = _attributes(
        RegExp(r'<vector\b[^>]*>').firstMatch(xml)![0]!,
      );
      final height = double.parse(
        vector['android:height']!.replaceAll('dp', ''),
      );
      final width = double.parse(vector['android:width']!.replaceAll('dp', ''));
      expect(height, 64);
      expect(width / height, closeTo(702 / 187.2, 0.01));
    });

    test('the system bars are emerald-700 until the first frame', () {
      for (final folder in [
        'values',
        'values-night',
        'values-v31',
        'values-night-v31',
      ]) {
        final styles = _read('$_res/$folder/styles.xml');
        for (final bar in ['statusBarColor', 'navigationBarColor']) {
          expect(
            styles,
            contains('android:$bar">@color/brand_emerald_700'),
            reason: '$folder $bar',
          );
        }
      }
    });

    test('Android 12 and later show the mark on emerald-700, day and night', () {
      for (final folder in ['values-v31', 'values-night-v31']) {
        final styles = _read('$_res/$folder/styles.xml');
        expect(
          styles,
          contains('windowSplashScreenBackground">@color/brand_emerald_700'),
        );
        expect(
          styles,
          contains(
            'windowSplashScreenAnimatedIcon">@drawable/ic_launcher_foreground',
          ),
        );
      }
    });
  });
}
