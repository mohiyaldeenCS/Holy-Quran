import 'pack_manifest.dart';

/// The active version of an installed pack. [previousVersion] is kept on the
/// device for a rollback; null when there is none.
final class InstalledPack {
  const InstalledPack({
    required this.manifest,
    required this.directory,
    required this.previousVersion,
  });

  final PackManifest manifest;
  final String directory;
  final int? previousVersion;

  String get id => manifest.id;
  int get version => manifest.version;
}
