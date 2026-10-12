import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/install_job.dart';
import '../../utils/result.dart';

/// An installed pack as the store records it: its active version, the one
/// kept for a rollback, and the directory of the active one.
typedef StoredPack = ({String id, int active, int? previous, String directory});

typedef _Versions = ({int active, int? previous});

/// Installed packs under the application-support directory (D-107):
///
/// ```
/// packs/<id>/<version>/         verified versions, never written again
/// packs/<id>/active.json        {"active": 2, "previous": 1}
/// pack-staging/<id>/<version>/  downloads in progress
/// pack-staging/.removed/        packs being removed
/// ```
///
/// Staging is on the same volume, so a verified version moves in by one
/// atomic rename, and its path ends in `<id>/<version>` as verification
/// requires. `active.json` is replaced by renaming `active.json.tmp` over
/// it. A pack is removed by first renaming its folder into
/// `pack-staging/.removed/`, so that a removal cut short leaves no half pack.
/// A folder under `packs/` with neither file is not the store's and is never
/// touched.
final class InstalledPacksStore {
  InstalledPacksStore(this._support);

  static Future<InstalledPacksStore> openInApplicationSupport() async =>
      InstalledPacksStore(await getApplicationSupportDirectory());

  static final _id = RegExp(r'^[a-z0-9][a-z0-9-]*$');
  static const _packs = 'packs';
  static const _staging = 'pack-staging';
  static const _active = 'active.json';
  static const _activeTemp = 'active.json.tmp';
  static const _removed = '$_staging/.removed';

  final Directory _support;

  /// Whether [id] can name a pack: it becomes a directory name.
  static bool isValidId(String id) => _id.hasMatch(id);

  /// The staging directory of [id] and [version], relative to the
  /// application-support directory.
  static String stagingRelativePath(String id, int version) =>
      '$_staging/$id/$version';

  String stagingPath(String id, int version) =>
      '${_support.path}/${stagingRelativePath(id, version)}';

  String versionPath(String id, int version) => '${_packPath(id)}/$version';

  String _packPath(String id) => '${_support.path}/$_packs/$id';

  /// Makes the staging directory of [id] and [version] and returns its path.
  /// Files an earlier attempt left there are kept, so that it can resume.
  Future<String> prepareStaging(String id, int version) async {
    _checkId(id);
    return (await Directory(
      stagingPath(id, version),
    ).create(recursive: true)).path;
  }

  Future<void> discardStaging(String id, int version) async {
    _checkId(id);
    await _remove(Directory(stagingPath(id, version)));
  }

  /// Removes [name] from the staging directory of [id] and [version].
  Future<void> discardStagedFile(String id, int version, String name) async {
    _checkId(id);
    await _remove(File('${stagingPath(id, version)}/$name'));
  }

  /// The packs that have an `active.json`, by id.
  Future<List<StoredPack>> readAll() async {
    final found = <StoredPack>[];
    for (final id in await _packIds()) {
      if (await _read(File('${_packPath(id)}/$_active')) case final versions?) {
        found.add(_stored(id, versions));
      }
    }
    return found..sort((a, b) => a.id.compareTo(b.id));
  }

  /// Moves the staged [version] of [id] into `packs/` and makes it active.
  /// The version that was active becomes the previous one; any older one is
  /// removed. A version already in `packs/` is never replaced.
  Future<Result<StoredPack>> activate(String id, int version) async {
    if (!isValidId(id)) return Failure(InvalidPackId(id));
    final staging = Directory(stagingPath(id, version));
    final target = versionPath(id, version);
    try {
      if (!await staging.exists()) {
        return Failure(StoreFailed(id, 'nothing staged for version $version'));
      }
      if (await FileSystemEntity.type(target) !=
          FileSystemEntityType.notFound) {
        return Failure(AlreadyInstalled(id, version));
      }
      final before = await _read(File('${_packPath(id)}/$_active'));
      final pack = Directory(_packPath(id));
      if (before == null &&
          await pack.exists() &&
          await pack.list().any((entity) => _nameOf(entity) != _activeTemp)) {
        return Failure(StoreFailed(id, 'packs/$id holds files of its own'));
      }
      final versions = (active: version, previous: before?.active);
      await pack.create(recursive: true);
      // The temporary file names the new version before it moves in, so
      // that recover() can finish an activation cut short after the move.
      final temp = await _writeTemp(id, versions);
      await staging.rename(target);
      await temp.rename('${_packPath(id)}/$_active');
      await _prune(id, versions);
      return Ok(_stored(id, versions));
    } on FileSystemException catch (e) {
      return Failure(StoreFailed(id, e.message));
    }
  }

  /// Makes the previous version of [id] active again. The version rolled
  /// back from becomes the previous one, so a rollback can be undone.
  Future<Result<StoredPack>> rollback(String id) async {
    if (!isValidId(id)) return Failure(InvalidPackId(id));
    try {
      final versions = await _read(File('${_packPath(id)}/$_active'));
      final previous = versions?.previous;
      if (versions == null ||
          previous == null ||
          !await Directory(versionPath(id, previous)).exists()) {
        return Failure(NoPreviousVersion(id));
      }
      final swapped = (active: previous, previous: versions.active);
      await (await _writeTemp(id, swapped)).rename('${_packPath(id)}/$_active');
      return Ok(_stored(id, swapped));
    } on FileSystemException catch (e) {
      return Failure(StoreFailed(id, e.message));
    }
  }

  /// Removes `packs/<id>/` and `pack-staging/<id>/`, nothing else. A pack
  /// without `active.json` is not the store's, and this does nothing.
  Future<Result<void>> delete(String id) async {
    if (!isValidId(id)) return Failure(InvalidPackId(id));
    try {
      if (!await File('${_packPath(id)}/$_active').exists()) {
        return const Ok(null);
      }
      await _discardPack(id);
      await _remove(Directory('${_support.path}/$_staging/$id'));
      return const Ok(null);
    } on FileSystemException catch (e) {
      return Failure(StoreFailed(id, e.message));
    }
  }

  /// Run before the store is used: finishes a removal cut short; finishes or
  /// drops a cut-short `active.json` replacement; falls back to the previous
  /// version when the active one is missing, and drops a missing previous
  /// version; removes a pack with no version left or an unreadable
  /// `active.json`, versions that are neither active nor previous, and
  /// staging at or below the active version. Newer staging is kept, so that
  /// its download resumes.
  Future<void> recover() async {
    await _remove(Directory('${_support.path}/$_removed'));
    for (final id in await _packIds()) {
      final temp = File('${_packPath(id)}/$_activeTemp');
      if (await temp.exists()) {
        final pending = await _read(temp);
        if (pending != null &&
            await Directory(versionPath(id, pending.active)).exists()) {
          await temp.rename('${_packPath(id)}/$_active');
        } else {
          await temp.delete();
        }
      }
      final active = File('${_packPath(id)}/$_active');
      if (!await active.exists()) continue;
      final versions = await _recovered(id, await _read(active));
      if (versions == null) {
        await _discardPack(id);
        continue;
      }
      await _prune(id, versions);
      await _pruneStaging(id, versions.active);
    }
  }

  /// [versions] with missing versions dropped, written back when changed;
  /// null when no version is left.
  Future<_Versions?> _recovered(String id, _Versions? versions) async {
    if (versions == null) return null;
    Future<int?> present(int? version) async =>
        version != null && await Directory(versionPath(id, version)).exists()
        ? version
        : null;
    final active = await present(versions.active);
    final previous = await present(versions.previous);
    final kept = switch ((active, previous)) {
      (final a?, final p) => (active: a, previous: p),
      (null, final p?) => (active: p, previous: null),
      (null, null) => null,
    };
    if (kept != null && kept != versions) {
      await (await _writeTemp(id, kept)).rename('${_packPath(id)}/$_active');
    }
    return kept;
  }

  /// Renames `packs/<id>/` out of `packs/` in one step, then removes it.
  Future<void> _discardPack(String id) async {
    final removed = await Directory(
      '${_support.path}/$_removed',
    ).create(recursive: true);
    final moved = await Directory(
      _packPath(id),
    ).rename('${removed.path}/$id-${DateTime.now().microsecondsSinceEpoch}');
    await moved.delete(recursive: true);
  }

  Future<void> _pruneStaging(String id, int active) async {
    final staging = Directory('${_support.path}/$_staging/$id');
    if (!await staging.exists()) return;
    await for (final entity in staging.list()) {
      final version = int.tryParse(_nameOf(entity));
      if (entity is Directory && version != null && version <= active) {
        await entity.delete(recursive: true);
      }
    }
  }

  Future<void> _prune(String id, _Versions keep) async {
    await for (final entity in Directory(_packPath(id)).list()) {
      final version = int.tryParse(_nameOf(entity));
      if (entity is Directory &&
          version != null &&
          version != keep.active &&
          version != keep.previous) {
        await entity.delete(recursive: true);
      }
    }
  }

  /// The ids under `packs/` that have an `active.json` or its temporary file.
  Future<List<String>> _packIds() async {
    final packs = Directory('${_support.path}/$_packs');
    if (!await packs.exists()) return const [];
    return [
      await for (final entity in packs.list())
        if (entity is Directory &&
            isValidId(_nameOf(entity)) &&
            (await File('${entity.path}/$_active').exists() ||
                await File('${entity.path}/$_activeTemp').exists()))
          _nameOf(entity),
    ];
  }

  Future<File> _writeTemp(String id, _Versions versions) =>
      File('${_packPath(id)}/$_activeTemp').writeAsString(
        jsonEncode({'active': versions.active, 'previous': versions.previous}),
        flush: true,
      );

  StoredPack _stored(String id, _Versions versions) => (
    id: id,
    active: versions.active,
    previous: versions.previous,
    directory: versionPath(id, versions.active),
  );

  static Future<_Versions?> _read(File file) async {
    try {
      return switch (jsonDecode(await file.readAsString())) {
        {'active': final int active, 'previous': final int? previous}
            when active > 0 &&
                (previous == null || previous > 0 && previous != active) =>
          (active: active, previous: previous),
        _ => null,
      };
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  static Future<void> _remove(FileSystemEntity entity) async {
    if (await entity.exists()) await entity.delete(recursive: true);
  }

  static String _nameOf(FileSystemEntity entity) =>
      entity.uri.pathSegments.lastWhere((segment) => segment.isNotEmpty);

  static void _checkId(String id) {
    if (!isValidId(id)) throw ArgumentError.value(id, 'id', 'not a pack id');
  }
}
