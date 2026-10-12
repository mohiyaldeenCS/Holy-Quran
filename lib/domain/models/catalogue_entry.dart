import 'install_job.dart';
import 'pack_manifest.dart';
import 'recitation.dart';

/// What a pack is for, beyond its kind (docs/PACK_CATALOGUE.md).
enum CatalogueRole {
  /// The one short tafsir fetched at the first use of tafsir (`TF-06`).
  firstUseTafsir,
}

/// One pack the catalogue offers, at one version. [files] is keyed by the
/// file names the manifest lists.
final class CatalogueEntry {
  CatalogueEntry({
    required this.id,
    required this.kind,
    required this.version,
    required this.title,
    required this.manifest,
    required this.signature,
    required Map<String, RemoteFile> files,
    required this.source,
    required this.changes,
    required this.role,
  }) : files = Map.unmodifiable(files) {
    if (!idPattern.hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'is not a pack id');
    }
    if (version < 1) {
      throw ArgumentError.value(version, 'version', 'is not positive');
    }
    if (files.isEmpty) throw ArgumentError.value(files, 'files', 'is empty');
    for (final MapEntry(key: name, value: file) in files.entries) {
      if (name.isEmpty ||
          name.contains('/') ||
          name.contains(r'\') ||
          name.contains('..')) {
        throw ArgumentError.value(
          name,
          'files',
          'holds a name that is not bare',
        );
      }
      if (file.bytes < 1) {
        throw ArgumentError.value(file.bytes, 'files[$name]', 'is empty');
      }
    }
    for (final (name, value) in [
      ('title', title),
      ('source', source),
      ('changes', changes),
    ]) {
      if (value.isEmpty) throw ArgumentError.value(value, name, 'is empty');
    }
    if (role == CatalogueRole.firstUseTafsir && kind != PackKind.tafsir) {
      throw ArgumentError.value(role, 'role', 'is not a role of a $kind');
    }
  }

  /// The form of a pack or recitation id: it becomes a directory name.
  static final idPattern = RegExp(r'^[a-z0-9][a-z0-9-]*$');

  final String id;
  final PackKind kind;
  final int version;
  final String title;
  final RemoteFile manifest;

  /// Where `manifest.json.sig` is; null when the pack has none.
  final Uri? signature;
  final Map<String, RemoteFile> files;

  /// The summary of the pack's sources, for the badge.
  final String source;

  /// What this version changes, shown with an update (`OF-06`).
  final String changes;
  final CatalogueRole? role;

  /// The size shown before a download: the sum of [files].
  int get bytes => files.values.fold(0, (sum, file) => sum + file.bytes);

  /// Every URL the entry names.
  Iterable<Uri> get urls => [
    manifest.url,
    ?signature,
    for (final file in files.values) file.url,
  ];

  InstallRequest installRequest({required bool wifiOnly}) => InstallRequest(
    packId: id,
    version: version,
    manifest: manifest,
    signature: signature,
    files: {
      for (final MapEntry(key: name, value: file) in files.entries)
        name: file.url,
    },
    wifiOnly: wifiOnly,
  );
}

/// A recitation the catalogue lists, with the qualities its pack offers and
/// the id of that pack.
final class CatalogueRecitation {
  CatalogueRecitation({
    required this.recitation,
    required List<int> qualities,
    required this.packId,
  }) : qualities = List.unmodifiable(qualities) {
    if (!CatalogueEntry.idPattern.hasMatch(recitation.id)) {
      throw ArgumentError.value(recitation.id, 'id', 'is not a recitation id');
    }
    if (qualities.isEmpty) {
      throw ArgumentError.value(qualities, 'qualities', 'is empty');
    }
    for (final (index, quality) in qualities.indexed) {
      if (quality < 1 || (index > 0 && quality <= qualities[index - 1])) {
        throw ArgumentError.value(
          qualities,
          'qualities',
          'is not rising positive bit rates',
        );
      }
    }
    for (final (name, value) in [
      ('reciter', recitation.reciter),
      ('style', recitation.style),
    ]) {
      if (value.isEmpty) throw ArgumentError.value(value, name, 'is empty');
    }
  }

  final Recitation recitation;

  /// In kbit/s, lowest first.
  final List<int> qualities;
  final String packId;

  String get id => recitation.id;
}
