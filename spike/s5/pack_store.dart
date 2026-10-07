import 'dart:convert';
import 'dart:io';

import 'package:holyquran/utils/result.dart';

/// Why the store refused a change.
sealed class StoreFailure implements Exception {
  const StoreFailure(this.id);

  final String id;
}

final class VersionExists extends StoreFailure {
  const VersionExists(super.id, this.version);

  final int version;

  @override
  String toString() => 'VersionExists($id/$version)';
}

final class StagingMissing extends StoreFailure {
  const StagingMissing(super.id, this.version);

  final int version;

  @override
  String toString() => 'StagingMissing($id/$version)';
}

final class NoPreviousVersion extends StoreFailure {
  const NoPreviousVersion(super.id);

  @override
  String toString() => 'NoPreviousVersion($id)';
}

final class StoreIoFailed extends StoreFailure {
  const StoreIoFailed(super.id, this.reason);

  final String reason;

  @override
  String toString() => 'StoreIoFailed($id): $reason';
}

/// The versions a pack's `current` file names: the active one and the one
/// before it, kept for a rollback.
typedef PackVersions = ({int active, int? previous});

/// Packs on disk under [root]:
///
/// ```
/// staging/<id>/<version>/   downloads in progress
/// packs/<id>/<version>/     verified versions, never written again
/// packs/<id>/current        "<active>\n" or "<active>\n<previous>\n"
/// ```
///
/// Every move is a rename inside [root], so it stays on one filesystem and
/// is atomic. `current` is replaced by writing `current.tmp` and renaming it
/// over `current`, so a reader sees the old or the new file, never a mix.
/// At most two versions are kept: the active one and the previous one.
final class PackStore {
  PackStore(this.root);

  final Directory root;

  static const _current = 'current';
  static const _currentTemp = 'current.tmp';

  Directory get _staging => Directory('${root.path}/staging');
  Directory get _packs => Directory('${root.path}/packs');
  Directory _packDir(String id) => Directory('${_packs.path}/$id');

  Directory directoryOf(String id, int version) =>
      Directory('${_packDir(id).path}/$version');

  /// An empty staging directory for [id] and [version]; what an earlier
  /// attempt left there is deleted first.
  Future<Directory> stagingFor(String id, int version) async {
    final directory = Directory('${_staging.path}/$id/$version');
    if (await directory.exists()) await directory.delete(recursive: true);
    return directory.create(recursive: true);
  }

  Future<void> discardStaging(String id, int version) async {
    final directory = Directory('${_staging.path}/$id/$version');
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<PackVersions?> versionsOf(String id) async {
    try {
      return _parse(
        await File('${_packDir(id).path}/$_current').readAsString(),
      );
    } on FileSystemException {
      return null;
    }
  }

  Future<int?> currentVersion(String id) async =>
      (await versionsOf(id))?.active;

  Future<bool> hasVersion(String id, int version) =>
      directoryOf(id, version).exists();

  /// Moves staging into `packs/<id>/<version>/` and makes it active; the
  /// version that was active becomes the previous one and any older version
  /// is deleted. A version that is already in `packs/` is never replaced.
  Future<Result<PackVersions>> activate(String id, int version) async {
    final staging = Directory('${_staging.path}/$id/$version');
    final target = directoryOf(id, version);
    try {
      if (!await staging.exists()) {
        return Failure(StagingMissing(id, version));
      }
      if (await FileSystemEntity.type(target.path) !=
          FileSystemEntityType.notFound) {
        return Failure(VersionExists(id, version));
      }
      await _packDir(id).create(recursive: true);
      await staging.rename(target.path);
      final before = (await versionsOf(id))?.active;
      final versions = (
        active: version,
        previous: before == version ? null : before,
      );
      await _writeCurrent(id, versions);
      await _prune(id, versions);
      return Ok(versions);
    } on FileSystemException catch (e) {
      return Failure(StoreIoFailed(id, e.message));
    }
  }

  /// Makes the previous version active again. The version rolled back from
  /// stays as the previous one, so the rollback can be undone.
  Future<Result<PackVersions>> rollback(String id) async {
    try {
      final versions = await versionsOf(id);
      final previous = versions?.previous;
      if (versions == null ||
          previous == null ||
          !await hasVersion(id, previous)) {
        return Failure(NoPreviousVersion(id));
      }
      final swapped = (active: previous, previous: versions.active);
      await _writeCurrent(id, swapped);
      return Ok(swapped);
    } on FileSystemException catch (e) {
      return Failure(StoreIoFailed(id, e.message));
    }
  }

  /// Run at start-up: deletes every staging directory and `current.tmp`
  /// file, falls back to the previous version when `current` names a
  /// missing directory, and deletes versions that are neither active nor
  /// previous. Returns one line per action.
  Future<List<String>> recover() async {
    final actions = <String>[];
    if (await _staging.exists()) {
      final files = await _staging
          .list(recursive: true)
          .where((entity) => entity is File)
          .length;
      await _staging.delete(recursive: true);
      if (files > 0) actions.add('deleted staging ($files files)');
    }
    if (!await _packs.exists()) return actions;
    await for (final entity in _packs.list()) {
      if (entity is! Directory) continue;
      final id = _nameOf(entity);
      final temp = File('${entity.path}/$_currentTemp');
      if (await temp.exists()) {
        await temp.delete();
        actions.add('$id: deleted $_currentTemp');
      }
      final current = File('${entity.path}/$_current');
      if (!await current.exists()) continue;
      var versions = _parse(await current.readAsString());
      if (versions == null) {
        await current.delete();
        actions.add('$id: deleted unreadable $_current');
        continue;
      }
      if (!await hasVersion(id, versions.active)) {
        final previous = versions.previous;
        if (previous != null && await hasVersion(id, previous)) {
          actions.add('$id: ${versions.active} missing, back to $previous');
          versions = (active: previous, previous: null);
          await _writeCurrent(id, versions);
        } else {
          await current.delete();
          actions.add('$id: no installed version left');
          continue;
        }
      }
      actions.addAll(await _prune(id, versions));
    }
    return actions;
  }

  Future<void> _writeCurrent(String id, PackVersions versions) async {
    final temp = File('${_packDir(id).path}/$_currentTemp');
    await temp.writeAsString(
      [versions.active, ?versions.previous].map((v) => '$v\n').join(),
      flush: true,
    );
    await temp.rename('${_packDir(id).path}/$_current');
  }

  Future<List<String>> _prune(String id, PackVersions keep) async {
    final deleted = <String>[];
    await for (final entity in _packDir(id).list()) {
      if (entity is! Directory) continue;
      final version = int.tryParse(_nameOf(entity));
      if (version == keep.active || version == keep.previous) continue;
      await entity.delete(recursive: true);
      deleted.add('$id: deleted ${_nameOf(entity)}');
    }
    return deleted;
  }

  static String _nameOf(Directory directory) =>
      directory.uri.pathSegments.lastWhere((segment) => segment.isNotEmpty);

  static PackVersions? _parse(String text) {
    final lines = const LineSplitter().convert(text);
    final versions = [for (final line in lines) int.tryParse(line)];
    return switch (versions) {
      [final active?] => (active: active, previous: null),
      [final active?, final previous?] when previous != active => (
        active: active,
        previous: previous,
      ),
      _ => null,
    };
  }
}
