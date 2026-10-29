import 'dart:io';

import '../../domain/models/recitation_file.dart';
import 'download_service.dart';
import 'pack_file_service.dart';

/// Where a recitation's audio lives on the device and how a file gets its
/// final name (docs/PACK_CATALOGUE.md, "A recitation at playback"):
/// `<audio directory>/<pack id>/<sha256><extension>`. A file is fetched under
/// `<pack id>/staging/`, each attempt into a file of its own. The copy that
/// is to be checked is first renamed to a name no downloader writes to, and
/// only that file is hashed and, if it matches, given the final name, so a
/// final name is never given to bytes that were not checked.
class RecitationFileStore {
  RecitationFileStore({
    required this._audioDirectory,
    this._files = const PackFileService(),
  });

  /// The directory under application support that holds the audio, which
  /// the downloader's relative paths start with.
  static const directoryName = 'recitations';

  final Future<String> Function() _audioDirectory;
  final PackFileService _files;

  /// The extension of [file]'s path, with its dot; empty when it has none.
  static String _extension(RecitationFile file) {
    final name = file.path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot);
  }

  static String _name(RecitationFile file) =>
      '${file.sha256}${_extension(file)}';

  /// Where the downloader puts the first attempt at [file] while it is
  /// fetched, relative to application support; a later attempt lands beside
  /// it ([FileOrder.pathAt]).
  static String stagingRelativePath(String packId, RecitationFile file) =>
      '$directoryName/$packId/staging/${_name(file)}';

  /// Where [file] of [packId] is on the device once it is whole, under the
  /// audio directory [root]. The player looks here too.
  static String finalPath(String root, String packId, RecitationFile file) =>
      '$root/$packId/${_name(file)}';

  Future<String> _finalPath(String packId, RecitationFile file) async =>
      finalPath(await _audioDirectory(), packId, file);

  Future<String> _stagingDirectory(String packId) async =>
      '${await _audioDirectory()}/$packId/staging';

  /// The name a copy is given while it is checked.
  Future<String> _claimedPath(String packId, RecitationFile file) async {
    final name = _name(file);
    final dot = name.lastIndexOf('.');
    final claimed = dot < 0
        ? '$name.claimed'
        : '${name.substring(0, dot)}.claimed${name.substring(dot)}';
    return '${await _stagingDirectory(packId)}/$claimed';
  }

  /// Whether [file] is on the device with the size its pack states.
  Future<bool> isPresent(String packId, RecitationFile file) async =>
      await _files.sizeOf(await _finalPath(packId, file)) == file.bytes;

  /// Whether any audio of the pack is on the device: a file with its final
  /// name, not one still in staging.
  Future<bool> hasAudio(String packId) async {
    final directory = Directory('${await _audioDirectory()}/$packId');
    if (!await directory.exists()) return false;
    return directory.list().any((entity) => entity is File);
  }

  /// Takes a whole copy of [file] out of staging, under a name no
  /// downloader writes to, and tells whether there is one. The copies are the
  /// one the downloader left for [attempt], or, without it, those of every
  /// attempt; each is renamed first and then checked for its size and
  /// SHA-256, so a task that writes after the check cannot change the bytes
  /// that were checked. A copy that is not whole is deleted.
  Future<bool> claimWhole(
    String packId,
    RecitationFile file, {
    int? attempt,
  }) async {
    final claimed = await _claimedPath(packId, file);
    if (await _isWhole(claimed, file)) return true;
    await _delete(claimed);
    for (final copy in await _copies(packId, file, attempt)) {
      try {
        await File(copy).rename(claimed);
      } on PathNotFoundException {
        continue;
      }
      if (await _isWhole(claimed, file)) return true;
      await _delete(claimed);
    }
    return false;
  }

  Future<bool> _isWhole(String path, RecitationFile file) async =>
      await _files.sizeOf(path) == file.bytes &&
      await _files.sha256Of(path) == file.sha256;

  /// The copies of [file] in staging: one attempt's, or every attempt's.
  Future<List<String>> _copies(
    String packId,
    RecitationFile file,
    int? attempt,
  ) async {
    final directory = await _stagingDirectory(packId);
    final name = _name(file);
    if (attempt != null) {
      return ['$directory/${FileOrder.pathAt(name, attempt)}'];
    }
    final dot = name.lastIndexOf('.');
    final stem = dot < 0 ? name : name.substring(0, dot);
    final extension = dot < 0 ? '' : name.substring(dot);
    final copy = RegExp(
      '^${RegExp.escape(stem)}(\\.a\\d+)?${RegExp.escape(extension)}\$',
    );
    final staging = Directory(directory);
    if (!await staging.exists()) return const [];
    return [
      await for (final entity in staging.list())
        if (entity is File && copy.hasMatch(entity.uri.pathSegments.last))
          entity.path,
    ];
  }

  /// Gives the claimed copy of [file] its final name, and removes what is
  /// left of it in staging: the copies of other attempts.
  Future<void> activate(String packId, RecitationFile file) async {
    final target = await _finalPath(packId, file);
    await Directory(File(target).parent.path).create(recursive: true);
    await File(await _claimedPath(packId, file)).rename(target);
    await discardStaged(packId, file);
  }

  /// Removes every copy of [file] from staging, the claimed one too.
  Future<void> discardStaged(String packId, RecitationFile file) async {
    for (final copy in await _copies(packId, file, null)) {
      await _delete(copy);
    }
    await _delete(await _claimedPath(packId, file));
  }

  Future<void> delete(String packId, RecitationFile file) async =>
      _delete(await _finalPath(packId, file));

  /// The bytes of the audio of [packId] on the device, at every quality; a
  /// file still in staging is not counted.
  Future<int> bytesOnDevice(String packId) async {
    final directory = Directory('${await _audioDirectory()}/$packId');
    if (!await directory.exists()) return 0;
    var bytes = 0;
    await for (final entity in directory.list()) {
      if (entity is File) bytes += await entity.length();
    }
    return bytes;
  }

  /// Removes everything of [packId]: its audio and what is left in staging.
  Future<void> deleteAll(String packId) async {
    try {
      await Directory(
        '${await _audioDirectory()}/$packId',
      ).delete(recursive: true);
    } on PathNotFoundException {
      return;
    }
  }

  /// The directory the audio of every recitation is under.
  Future<String> directory() => _audioDirectory();

  Future<void> _delete(String path) async {
    try {
      await File(path).delete();
    } on PathNotFoundException {
      return;
    }
  }
}
