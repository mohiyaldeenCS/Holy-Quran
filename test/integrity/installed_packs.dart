import 'dart:convert';
import 'dart:io';

/// Where the packs the app bundles are (D-067).
const installedPacksRoot = 'assets/packs';

/// Every directory under [installedPacksRoot] that holds a `manifest.json`,
/// sorted.
List<String> installedPackDirectories() {
  final root = Directory(installedPacksRoot);
  if (!root.existsSync()) return const [];
  return [
    for (final file in root.listSync(recursive: true).whereType<File>())
      if (file.uri.pathSegments.last == 'manifest.json')
        file.parent.path.replaceAll(r'\', '/'),
  ]..sort();
}

/// The `kind` the manifest of [directory] names; null when it names none or
/// cannot be read.
String? packManifestKind(String directory) {
  try {
    return switch (jsonDecode(
      File('$directory/manifest.json').readAsStringSync(),
    )) {
      {'kind': final String kind} => kind,
      _ => null,
    };
  } on Exception {
    return null;
  }
}

/// The pack directories that hold Quran text: those under
/// [installedPacksRoot] whose manifest names no tafsir or recitation kind.
List<String> installedTextPackDirectories() => [
  for (final directory in installedPackDirectories())
    if (!const {'tafsir', 'recitation'}.contains(packManifestKind(directory)))
      directory,
];
