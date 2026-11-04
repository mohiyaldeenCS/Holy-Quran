import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'dart_source.dart';

// NF-14 and D-001: no analytics, crash reporting, advertising, purchase or
// tracking code, and nothing the user wrote or read leaves the device. The
// rules live here, not in the allow-list folder: a change to one is a change
// of the privacy promise and is reviewed as one.

const _services = 'lib/data/services/';

/// Packages that collect, attribute, advertise or sell. Matched against the
/// names in `pubspec.yaml` and, for what they pull in, `pubspec.lock`.
final _forbiddenPackages = RegExp(
  r'^(?:'
  // Analytics, crash reporting, attribution, session recording.
  r'firebase.*|cloud_firestore.*|sentry.*|bugsnag.*|datadog.*|instabug.*|'
  r'appcenter.*|amplitude.*|mixpanel.*|posthog.*|segment_analytics.*|'
  r'flutter_segment.*|appsflyer.*|'
  r'adjust_sdk|branch_sdk|flutter_branch_sdk|singular.*|kochava.*|matomo.*|'
  r'countly.*|smartlook.*|clarity_flutter|flutter_facebook.*|'
  r'facebook_app_events|'
  r'onesignal.*|usercentrics.*|google_analytics.*|amplify_analytics.*|'
  r'braze.*|clevertap.*|moengage.*|webengage.*|(?:flutter_)?uxcam|'
  r'logrocket.*|fullstory.*|(?:flutter_)?bugfender|rollbar.*|flutter_rollbar|'
  r'raygun.*|newrelic.*|flutter_sentry|'
  // Advertising.
  r'google_mobile_ads|admob.*|applovin.*|unity_ads.*|ironsource.*|'
  r'facebook_audience_network|(?:stack_)?appodeal.*|startapp.*|pangle.*|'
  r'mintegral.*|'
  // Purchases and subscriptions.
  r'in_app_purchase.*|flutter_inapp_purchase|purchases_.*|adapty.*|'
  r'qonversion.*|flutter_stripe|stripe_.*|apphud|superwall.*|'
  // Tracking identifiers.
  r'app_tracking_transparency|advertising_id|flutter_advertising_id'
  r')$',
);

const _pubspecSections = {
  'dependencies',
  'dev_dependencies',
  'dependency_overrides',
};

/// The package names a `pubspec.yaml` declares.
Set<String> _declaredPackages(String pubspec) {
  final names = <String>{};
  String? section;
  for (final line in pubspec.split('\n')) {
    final top = RegExp(r'^(\w+):\s*$').firstMatch(line);
    if (top != null) section = top[1];
    final entry = RegExp(r'^  ([a-z][a-z0-9_]*):').firstMatch(line);
    if (entry != null && _pubspecSections.contains(section)) {
      names.add(entry[1]!);
    }
  }
  return names;
}

/// Every package a `pubspec.lock` resolves, direct or transitive.
Set<String> _lockedPackages(String lock) => {
  for (final match in RegExp(
    r'^  ([a-z][a-z0-9_]*):\s*$',
    multiLine: true,
  ).allMatches(lock))
    match[1]!,
};

/// A way for data to leave the app, and the only files that may use it. An
/// entry ending in `/` is a folder.
typedef _Surface = ({
  String name,
  RegExp? importUri,
  RegExp? code,
  List<String> allowed,
});

const _catalogue = '${_services}catalogue_service.dart';
const _download = '${_services}download_service.dart';
const _audioEngine = '${_services}audio_engine_service.dart';
const _audioHandler = '${_services}audio_handler.dart';
const _link = '${_services}link_service.dart';
const _share = '${_services}share_service.dart';

final _surfaces = <_Surface>[
  (
    name: 'a socket or HTTP call',
    importUri: null,
    code: RegExp(
      r'\b(?:HttpClient|HttpServer|HttpOverrides|WebSocket|Socket|'
      r'RawSocket|SecureSocket|ServerSocket|RawDatagramSocket)\b|'
      r'\bInternetAddress\.lookup\b',
    ),
    allowed: [_catalogue, _download],
  ),
  (
    name: 'a network image or asset bundle',
    importUri: null,
    code: RegExp(
      r'\b(?:Image\.network|NetworkImage|NetworkAssetBundle|'
      r'FadeInImage\.network)\b',
    ),
    allowed: [],
  ),
  (
    name: 'a child process',
    importUri: null,
    code: RegExp(r'\bProcess\.(?:run|runSync|start)\b'),
    allowed: [],
  ),
  (
    name: 'a platform channel',
    importUri: null,
    code: RegExp(
      r'\b(?:MethodChannel|EventChannel|BasicMessageChannel|DynamicLibrary|'
      r'defaultBinaryMessenger)\b',
    ),
    allowed: [_audioEngine],
  ),
  (
    name: 'a package that makes HTTP, socket or web-view calls',
    importUri: RegExp(
      r'^package:(?:http|dio|web_socket_channel|web_socket|webview_\w+|'
      r'flutter_inappwebview\w*|cronet_http|cupertino_http|chopper|retrofit|'
      r'grpc|graphql\w*|socket_io_client|cached_network_image|'
      r'flutter_cache_manager|extended_image|mailer|mqtt_client|'
      r'supabase\w*|appwrite|pocketbase|amplify_\w+)/',
    ),
    code: null,
    allowed: [],
  ),
  (
    name: 'the downloader',
    importUri: RegExp(r'^package:background_downloader/'),
    code: null,
    allowed: [_download],
  ),
  (
    name: 'audio streaming',
    importUri: RegExp(r'^package:just_audio'),
    code: null,
    allowed: [_audioEngine, _audioHandler],
  ),
  (
    name: 'opening a link',
    importUri: RegExp(r'^package:url_launcher'),
    code: null,
    allowed: [_link],
  ),
  (
    name: 'the share sheet',
    importUri: RegExp(r'^package:share_plus/'),
    code: null,
    allowed: [_share],
  ),
];

/// The services that reach the network or open a link. Nothing a user wrote or
/// read may be in the import closure of one of them.
const _networkServices = [
  _catalogue,
  _download,
  _audioEngine,
  _audioHandler,
  _link,
  _share,
];

/// The user's database, its access objects, the repositories over it and the
/// models of what the user wrote or read. An entry ending in `/` is a folder.
const _userData = [
  '${_services}user_database.dart',
  '${_services}user_database.g.dart',
  '${_services}user_tables.dart',
  '${_services}settings_store.dart',
  '${_services}daos/',
  'lib/data/repositories/app_settings_repository.dart',
  'lib/data/repositories/bookmark_repository.dart',
  'lib/data/repositories/category_repository.dart',
  'lib/data/repositories/in_memory_app_settings_repository.dart',
  'lib/data/repositories/integrity_log_repository.dart',
  'lib/data/repositories/listening_position_repository.dart',
  'lib/data/repositories/note_repository.dart',
  'lib/data/repositories/reading_position_repository.dart',
  'lib/data/repositories/search_history_repository.dart',
  'lib/data/repositories/tag_repository.dart',
  'lib/domain/models/bookmark.dart',
  'lib/domain/models/category.dart',
  'lib/domain/models/listening_position.dart',
  'lib/domain/models/note.dart',
  'lib/domain/models/user_tag.dart',
];

bool _covers(String entry, String path) =>
    entry.endsWith('/') ? path.startsWith(entry) : path == entry;

final _directive = RegExp(
  r'^\s*(?:import|export|part)\s+([^;]+);',
  multiLine: true,
);
final _quoted = RegExp('''['"]([^'"]+)['"]''');

/// The URIs a source imports or exports, as written.
List<String> _uris(String source) => [
  for (final directive in _directive.allMatches(source))
    for (final uri in _quoted.allMatches(directive[1]!)) uri[1]!,
];

/// The file in the app that [uri], written in [from], names; null for a
/// platform library or another package.
String? _resolve(String from, String uri) {
  const own = 'package:holyquran/';
  if (uri.startsWith(own)) return 'lib/${uri.substring(own.length)}';
  if (uri.contains(':')) return null;
  return Uri(path: '/$from').resolve(uri).path.substring(1);
}

/// Every file of [sources] reachable from [start] through imports and exports.
Set<String> _closure(String start, Map<String, String> sources) {
  final seen = <String>{};
  final pending = [start];
  while (pending.isNotEmpty) {
    final path = pending.removeLast();
    final source = sources[path];
    if (source == null || !seen.add(path)) continue;
    for (final uri in _uris(source)) {
      if (_resolve(path, uri) case final target?) pending.add(target);
    }
  }
  return seen;
}

/// Each way a source of `lib/` breaks the rules, as `path: what`.
List<String> _networkViolations(Map<String, String> sources) {
  final found = <String>[];
  for (final MapEntry(key: path, value: source) in sources.entries) {
    final code = ScannedSource(source).code;
    final uris = _uris(source);
    for (final surface in _surfaces) {
      if (surface.allowed.any((entry) => _covers(entry, path))) continue;
      final hit =
          surface.code?.hasMatch(code) ?? uris.any(surface.importUri!.hasMatch);
      if (hit) found.add('$path: ${surface.name}');
    }
  }
  return found;
}

/// The network services whose import closure reaches the user's data, as
/// `service -> file`.
List<String> _userDataReach(Map<String, String> sources) => [
  for (final service in _networkServices)
    for (final file in _closure(service, sources))
      if (file != service && _userData.any((entry) => _covers(entry, file)))
        '$service -> $file',
];

/// The user-data files whose import closure reaches a network service, as
/// `file -> service`: user data must not pass through one as a primitive
/// either.
List<String> _userDataReachesOut(Map<String, String> sources) => [
  for (final path in sources.keys)
    if (_userData.any((entry) => _covers(entry, path)))
      for (final file in _closure(path, sources))
        if (_networkServices.contains(file)) '$path -> $file',
];

final _userModelName = RegExp(
  r'bookmark|note|categor|tag_|history|khatma|goal|memoris|highlight|'
  r'collection|streak|statistic|reading_position|listening_position',
);

/// Files that read the user's database for settings only (the chosen tafsir
/// book, the Wi-Fi-only choice, the preferred quality) and hold nothing the
/// user wrote or read; they may sit beside the installer. D-158 (4) names them.
const _settingsOnly = [
  'lib/data/repositories/tafsir_repository.dart',
  'lib/data/repositories/download_settings_repository.dart',
  'lib/data/repositories/recitation_locator.dart',
];

/// The only user-data files a [_settingsOnly] file may reach.
const _settingsAccess = [
  '${_services}daos/settings_dao.dart',
  '${_services}settings_store.dart',
];

/// Every file of [sources] reachable from [start] without going through one
/// of [stops]; a stop is in the result but its imports are not followed.
Set<String> _closureStoppingAt(
  String start,
  Map<String, String> sources,
  List<String> stops,
) {
  final seen = <String>{};
  final pending = [start];
  while (pending.isNotEmpty) {
    final path = pending.removeLast();
    final source = sources[path];
    if (source == null || !seen.add(path) || stops.contains(path)) continue;
    for (final uri in _uris(source)) {
      if (_resolve(path, uri) case final target?) pending.add(target);
    }
  }
  return seen;
}

/// The user-data files that a [_settingsOnly] file reaches other than through
/// the settings DAO and store, as `file -> reached`.
List<String> _settingsOnlyOverreach(
  Map<String, String> sources,
  List<String> settingsOnly,
) => [
  for (final path in settingsOnly)
    for (final file in _closureStoppingAt(path, sources, _settingsAccess))
      if (file != path &&
          !_settingsAccess.contains(file) &&
          _userData.any((entry) => _covers(entry, file)))
        '$path -> $file',
];

/// Files that read the user's database, or whose name says they hold what the
/// user wrote or read, but that `_userData` does not list. A new one must be
/// listed, so that the network rules cover it.
List<String> _unlistedUserData(Map<String, String> sources) => [
  for (final path in sources.keys)
    if (!path.endsWith('.g.dart') &&
        !_settingsOnly.contains(path) &&
        !_userData.any((entry) => _covers(entry, path)))
      if (path.startsWith('lib/data/') &&
          _closure(path, sources).any(
            (file) =>
                file == '${_services}user_database.dart' ||
                file == '${_services}user_tables.dart',
          ))
        path
      else if (path.startsWith('lib/domain/models/') &&
          _userModelName.hasMatch(path.split('/').last))
        path,
];

/// The native build files of an app that carry an SDK of the forbidden kinds.
final _forbiddenNative = RegExp(
  r'google-services|firebase|crashlytics|play-services-(?:ads|analytics|'
  r'measurement)|gms\.ads|permission\.AD_ID|appsflyer|sentry|billingclient|'
  r'admob|NSUserTrackingUsageDescription|SKAdNetwork|GoogleAnalytics|'
  r'audience-network-sdk|hms:ads',
  caseSensitive: false,
);

bool _isNativeBuildFile(String path) =>
    RegExp(r'^android/(?!.*/build/)(?!\.gradle/).*\.(?:gradle|kts|properties)$')
        .hasMatch(path) ||
    RegExp(r'^android/app/src/\w+/AndroidManifest\.xml$').hasMatch(path) ||
    path == 'ios/Podfile' ||
    path == 'ios/Runner/Info.plist';

/// Each native build file of [files] (path to content) that names a forbidden
/// SDK.
List<String> _nativeViolations(Map<String, String> files) => [
  for (final MapEntry(key: path, value: content) in files.entries)
    if (_isNativeBuildFile(path) && _forbiddenNative.hasMatch(content)) path,
];

Map<String, String> _nativeFiles() => {
  for (final root in ['android', 'ios'])
    for (final file in Directory(root).listSync(recursive: true))
      if (file is File && _isNativeBuildFile(file.path.replaceAll(r'\', '/')))
        file.path.replaceAll(r'\', '/'): file.readAsStringSync(),
};

/// A forbidden package in either file, as `file: package`.
List<String> _packageViolations({
  required String pubspec,
  required String lock,
}) => [
  for (final name in _declaredPackages(pubspec))
    if (_forbiddenPackages.hasMatch(name)) 'pubspec.yaml: $name',
  for (final name in _lockedPackages(lock))
    if (_forbiddenPackages.hasMatch(name)) 'pubspec.lock: $name',
];

void main() {
  final lib = dartSources('lib');

  group('the app as it stands', () {
    test('pubspec.yaml and pubspec.lock list no analytics, crash, ad, '
        'purchase or tracking package', () {
      expect(
        _packageViolations(
          pubspec: File('pubspec.yaml').readAsStringSync(),
          lock: File('pubspec.lock').readAsStringSync(),
        ),
        isEmpty,
      );
    });

    test('the parsers read the packages the app does use', () {
      final declared = _declaredPackages(
        File('pubspec.yaml').readAsStringSync(),
      );
      final locked = _lockedPackages(File('pubspec.lock').readAsStringSync());
      expect(declared, containsAll(['flutter', 'url_launcher', 'just_audio']));
      expect(locked, containsAll(['url_launcher', 'just_audio', 'http']));
    });

    test('only the catalogue, download, audio and link services reach out', () {
      expect(_networkViolations(lib), isEmpty);
    });

    test('the services that reach out do, so the rules are not idle', () {
      for (final service in _networkServices) {
        expect(lib, contains(service));
      }
      final used = {
        for (final surface in _surfaces)
          for (final path in lib.keys)
            if (surface.allowed.contains(path) &&
                (surface.code?.hasMatch(ScannedSource(lib[path]!).code) ??
                    _uris(lib[path]!).any(surface.importUri!.hasMatch)))
              surface.name,
      };
      expect(used, contains('the share sheet'));
      expect(used, contains('a platform channel'));
      expect(used, contains('a socket or HTTP call'));
      expect(used, contains('the downloader'));
      expect(used, contains('audio streaming'));
      expect(used, contains('opening a link'));
    });

    test('no user-database type reaches a network service', () {
      expect(_userDataReach(lib), isEmpty);
    });

    test('no user-data file reaches a network service', () {
      expect(_userDataReachesOut(lib), isEmpty);
    });

    test('every file that holds user data is listed as such', () {
      expect(_unlistedUserData(lib), isEmpty);
    });

    test('no native build file carries an analytics, crash, ad or purchase '
        'SDK', () {
      final files = _nativeFiles();
      expect(files, isNotEmpty);
      expect(_nativeViolations(files), isEmpty);
    });

    test('a settings-only file reaches the user data only through the settings '
        'DAO and store', () {
      for (final path in _settingsOnly) {
        expect(lib, contains(path));
      }
      expect(_settingsOnlyOverreach(lib, _settingsOnly), isEmpty);
    });

    test('every user-data entry names a file or folder that exists', () {
      for (final entry in _userData) {
        expect(
          lib.keys.any((path) => _covers(entry, path)),
          isTrue,
          reason: entry,
        );
      }
    });
  });

  group('a violation is caught', () {
    final clean = {
      _catalogue: "import 'dart:io';\nfinal c = HttpClient();",
      _link: "import 'package:url_launcher/url_launcher.dart';",
      'lib/ui/features/home/home_view.dart':
          "import 'package:flutter/widgets.dart';",
    };

    test('the clean fixture passes', () {
      expect(_networkViolations(clean), isEmpty);
      expect(_userDataReach(clean), isEmpty);
    });

    test('an HTTP client in a view', () {
      final sources = {
        ...clean,
        'lib/ui/features/home/home_view.dart': 'final c = HttpClient();',
      };
      expect(_networkViolations(sources), [
        'lib/ui/features/home/home_view.dart: a socket or HTTP call',
      ]);
    });

    test('a socket in a repository', () {
      final sources = {
        ...clean,
        'lib/data/repositories/note_repository.dart': 'Socket.connect(a, 1);',
      };
      expect(_networkViolations(sources), hasLength(1));
    });

    test('a link opened outside the link service', () {
      final sources = {
        ...clean,
        'lib/ui/features/home/home_view.dart':
            "import 'package:url_launcher/url_launcher.dart';",
      };
      expect(_networkViolations(sources), [
        'lib/ui/features/home/home_view.dart: opening a link',
      ]);
    });

    test('a downloader, a player or a share sheet in the wrong file', () {
      final sources = {
        ...clean,
        'lib/a.dart': "import 'package:background_downloader/x.dart';",
        'lib/b.dart': "import 'package:just_audio/just_audio.dart';",
        'lib/c.dart': "import 'package:share_plus/share_plus.dart';",
      };
      expect(_networkViolations(sources), [
        'lib/a.dart: the downloader',
        'lib/b.dart: audio streaming',
        'lib/c.dart: the share sheet',
      ]);
    });

    test('an HTTP package, even in a service that may reach out', () {
      final sources = {
        ...clean,
        _catalogue: "import 'package:http/http.dart' as http;",
      };
      expect(_networkViolations(sources), [
        '$_catalogue: a package that makes HTTP, socket or web-view calls',
      ]);
    });

    test(
      'a network image, a child process, a channel outside the audio engine',
      () {
        final sources = {
          'lib/ui/a.dart': 'final i = Image.network(u);',
          'lib/ui/b.dart': "final p = Process.run('curl', []);",
          'lib/ui/c.dart': "const c = MethodChannel('x');",
          '${_services}d.dart': "const c = MethodChannel('x');",
        };
        expect(_networkViolations(sources), [
          'lib/ui/a.dart: a network image or asset bundle',
          'lib/ui/b.dart: a child process',
          'lib/ui/c.dart: a platform channel',
          '${_services}d.dart: a platform channel',
        ]);
      },
    );

    test('a comment or a string that only names a call is not a call', () {
      final sources = {
        'lib/ui/a.dart': "// HttpClient is not used here\nconst s = 'Socket';",
      };
      expect(_networkViolations(sources), isEmpty);
    });

    test('a network service importing the user database', () {
      final sources = {
        ...clean,
        _download: "import 'user_database.dart';",
        '${_services}user_database.dart': '',
      };
      expect(_userDataReach(sources), [
        '$_download -> ${_services}user_database.dart',
      ]);
    });

    test('a network service reaching a user type through a model', () {
      final sources = {
        ...clean,
        _audioEngine: "import 'package:holyquran/domain/models/plan.dart';",
        'lib/domain/models/plan.dart': "import 'note.dart';",
        'lib/domain/models/note.dart': 'class Note {}',
      };
      expect(_userDataReach(sources), [
        '$_audioEngine -> lib/domain/models/note.dart',
      ]);
    });

    test('a network service reaching a repository over the user database', () {
      final sources = {
        ...clean,
        _share: "import '../repositories/bookmark_repository.dart';",
        'lib/data/repositories/bookmark_repository.dart': '',
      };
      expect(_userDataReach(sources), [
        '$_share -> lib/data/repositories/bookmark_repository.dart',
      ]);
    });

    test('a user-data file importing a network service', () {
      final sources = {
        ...clean,
        'lib/data/repositories/note_repository.dart':
            "import '../services/catalogue_service.dart';",
      };
      expect(_userDataReachesOut(sources), [
        'lib/data/repositories/note_repository.dart -> $_catalogue',
      ]);
    });

    test('a new repository over the user database, or a new user model', () {
      final sources = {
        ...clean,
        '${_services}user_database.dart': '',
        'lib/data/repositories/khatma_repository.dart':
            "import '../services/user_database.dart';",
        'lib/domain/models/highlight.dart': '',
        'lib/domain/models/playback_plan.dart': '',
        'lib/data/repositories/note_repository.dart':
            "import '../services/user_database.dart';",
      };
      expect(_unlistedUserData(sources), [
        'lib/data/repositories/khatma_repository.dart',
        'lib/domain/models/highlight.dart',
      ]);
    });

    test('a service that holds the user database and shares it', () {
      final sources = {
        ...clean,
        '${_services}user_database.dart': '',
        _share: '',
        '${_services}notes_export_service.dart':
            "import 'user_database.dart';\nimport 'share_service.dart';",
      };
      expect(_unlistedUserData(sources), [
        '${_services}notes_export_service.dart',
      ]);
    });

    test('a settings-only file that reaches another DAO or a user model', () {
      const repository = 'lib/data/repositories/tafsir_repository.dart';
      final sources = {
        repository:
            "import '../services/daos/settings_dao.dart';\n"
            "import '../services/daos/note_dao.dart';\n"
            "import 'package:holyquran/domain/models/bookmark.dart';",
        '${_services}daos/settings_dao.dart': "import '../user_database.dart';",
        '${_services}daos/note_dao.dart': '',
        '${_services}user_database.dart': '',
        'lib/domain/models/bookmark.dart': '',
      };
      expect(
        _settingsOnlyOverreach(sources, [repository]),
        unorderedEquals([
          '$repository -> ${_services}daos/note_dao.dart',
          '$repository -> lib/domain/models/bookmark.dart',
        ]),
      );
    });

    test('a settings-only file that uses only the settings DAO and store', () {
      const repository = 'lib/data/repositories/tafsir_repository.dart';
      final sources = {
        repository:
            "import '../services/daos/settings_dao.dart';\n"
            "import '../services/settings_store.dart';",
        '${_services}daos/settings_dao.dart': "import '../user_database.dart';",
        '${_services}settings_store.dart': "import 'user_database.dart';",
        '${_services}user_database.dart': '',
      };
      expect(_settingsOnlyOverreach(sources, [repository]), isEmpty);
    });

    test('a part file that holds a user type', () {
      final sources = {
        ...clean,
        _download: "part 'download_service.part.dart';",
        '${_services}download_service.part.dart': "import 'user_tables.dart';",
        '${_services}user_tables.dart': '',
      };
      expect(_userDataReach(sources), [
        '$_download -> ${_services}user_tables.dart',
      ]);
    });

    test('a native SDK in a gradle file, a manifest or a Podfile', () {
      final files = {
        'android/app/build.gradle.kts': 'implementation("x.y:z:1")',
        'android/app/src/main/AndroidManifest.xml':
            '<meta-data android:name="com.google.android.gms.ads.APP_ID"/>',
        'android/build.gradle.kts':
            'classpath("com.google.gms:google-services")',
        'ios/Podfile': "pod 'Firebase/Analytics'",
        'android/app/build/generated/x.gradle': 'firebase',
        'android/app/src/main/res/values/styles.xml': 'firebase',
      };
      expect(_nativeViolations(files), [
        'android/app/src/main/AndroidManifest.xml',
        'android/build.gradle.kts',
        'ios/Podfile',
      ]);
    });

    test('the vendors\' real pub.dev names', () {
      const names = [
        'segment_analytics',
        'flutter_segment',
        'clarity_flutter',
        'flutter_uxcam',
        'uxcam',
        'fullstory_flutter',
        'fullstory',
        'flutter_bugfender',
        'bugfender',
        'rollbar_flutter',
        'rollbar_dart',
        'rollbar',
        'logrocket_flutter',
        'logrocket',
        'superwallkit_flutter',
        'superwall',
        'stack_appodeal_flutter',
        'appodeal_flutter',
        'appodeal',
      ];
      for (final name in names) {
        expect(_forbiddenPackages.hasMatch(name), isTrue, reason: name);
      }
    });

    test(
      'a widget package whose name only starts like a vendor is allowed',
      () {
        const names = [
          'segment_display',
          'segmented_button_slide',
          'segmented_progress_bar',
          'clarity_chart',
          'adjust_brightness',
        ];
        for (final name in names) {
          expect(_forbiddenPackages.hasMatch(name), isFalse, reason: name);
        }
      },
    );

    test('an ad SDK of Facebook or Huawei in a gradle file', () {
      final files = {
        'android/app/build.gradle.kts':
            'implementation("com.facebook.android:audience-network-sdk:6.0")',
        'android/build.gradle.kts': 'implementation("com.huawei.hms:ads:3.4")',
      };
      expect(_nativeViolations(files), [
        'android/app/build.gradle.kts',
        'android/build.gradle.kts',
      ]);
    });

    test('an analytics, crash, ad, purchase or tracking package', () {
      const names = [
        'firebase_analytics',
        'firebase_crashlytics',
        'sentry_flutter',
        'google_mobile_ads',
        'in_app_purchase',
        'purchases_flutter',
        'app_tracking_transparency',
        'mixpanel_flutter',
        'appsflyer_sdk',
      ];
      for (final name in names) {
        final pubspec =
            'dependencies:\n  flutter:\n    sdk: flutter\n  $name: ^1.0.0\n';
        expect(_packageViolations(pubspec: pubspec, lock: 'packages:\n'), [
          'pubspec.yaml: $name',
        ], reason: name);
      }
    });

    test('a forbidden package that only a dependency brings in', () {
      const lock = 'packages:\n  sentry:\n    dependency: transitive\n';
      expect(
        _packageViolations(pubspec: 'dependencies:\n  a: ^1.0.0\n', lock: lock),
        ['pubspec.lock: sentry'],
      );
    });

    test('a forbidden package in dev_dependencies or an override', () {
      const pubspec =
          'dev_dependencies:\n  sentry_dart_plugin: ^1.0.0\n'
          'dependency_overrides:\n  google_mobile_ads: any\n';
      expect(_packageViolations(pubspec: pubspec, lock: ''), [
        'pubspec.yaml: sentry_dart_plugin',
        'pubspec.yaml: google_mobile_ads',
      ]);
    });

    test('a package name in a comment or another section is not declared', () {
      const pubspec =
          'name: app\ndescription: firebase: not used\n'
          'dependencies:\n  # sentry_flutter: ^1.0.0\n  http_parser: ^4.0.0\n';
      expect(_packageViolations(pubspec: pubspec, lock: ''), isEmpty);
    });
  });
}
