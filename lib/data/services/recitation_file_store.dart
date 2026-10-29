import 'dart:io';

import '../../domain/models/recitation_file.dart';
import 'pack_file_service.dart';

/// Where a recitation's audio lives on the device and how a file gets its
/// final name (docs/PACK_CATALOGUE.md, "A recitation at playback"):
/// `<audio directory>/<pack id>/<sha256><extension>`. A file is fetched under
/// `<pack id>/staging/` and only renamed once its size and SHA-256 match, so
/// a final name is never given to a file that was not checked.
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

  /// Where the downloader puts [file] while it is fetched, relative to
  /// application support.
  static String stagingRelativePath(String packId, RecitationFile file) =>
      '$directoryName/$packId/staging/${_name(file)}';

  /// Where [file] of [packId] is on the device once it is whole, under the
  /// audio directory [root]. The player looks here too.
  static String finalPath(String root, String packId, RecitationFile file) =>
      '$root/$packId/${_name(file)}';

  Future<String> _finalPath(String packId, RecitationFile file) async =>
      finalPath(await _audioDirectory(), packId, file);

  Future<String> _stagingPath(String packId, RecitationFile file) async =>
      '${await _audioDirectory()}/$packId/staging/${_name(file)}';

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

  /// Whether what the downloader left of [file] is whole: its size and
  /// SHA-256 match.
  Future<bool> stagedIsWhole(String packId, RecitationFile file) async {
    final path = await _stagingPath(packId, file);
    return await _files.sizeOf(path) == file.bytes &&
        await _files.sha256Of(path) == file.sha256;
  }

  /// Gives the staged [file] its final name.
  Future<void> activate(String packId, RecitationFile file) async {
    final target = await _finalPath(packId, file);
    await Directory(File(target).parent.path).create(recursive: true);
    await File(await _stagingPath(packId, file)).rename(target);
  }

  Future<void> discardStaged(String packId, RecitationFile file) async =>
      _delete(await _stagingPath(packId, file));

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
