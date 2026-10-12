import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/catalogue.dart';
import '../../domain/models/catalogue_entry.dart';
import '../../domain/models/installed_pack.dart';
import '../../domain/models/pack_failure.dart';
import '../../domain/models/pack_integrity.dart';
import '../../domain/models/pack_manifest.dart';
import '../../domain/models/quran_address.dart';
import '../../domain/models/recitation.dart';
import '../../domain/models/recitation_file.dart';
import '../../domain/models/verified_pack.dart';
import '../../utils/result.dart';
import '../models/pack_manifest_json.dart';
import '../services/pack_file_service.dart';
import '../services/recitation_pack_index.dart';
import 'pack_integrity_repository.dart' show PackCheck;

/// The audio of a surah or ayah: [uri] is a `file:` URI when the file is on
/// the device ([local]), and otherwise where it is streamed from.
final class RecitationAudio {
  const RecitationAudio({
    required this.file,
    required this.uri,
    required this.local,
  });

  final RecitationFile file;
  final Uri uri;
  final bool local;
}

/// Why a recitation's audio was not found.
sealed class RecitationFailure implements Exception {
  const RecitationFailure(this.recitationId);

  final String recitationId;
}

/// The catalogue does not list the recitation, or lists it without a
/// complete rights record (`AU-01`).
final class RecitationNotListed extends RecitationFailure {
  const RecitationNotListed(super.recitationId);

  @override
  String toString() => 'RecitationNotListed($recitationId)';
}

final class RecitationPackNotInstalled extends RecitationFailure {
  const RecitationPackNotInstalled(super.recitationId, this.packId);

  final String packId;

  @override
  String toString() => 'RecitationPackNotInstalled($recitationId): $packId';
}

/// The pack has no file for this surah or ayah at this quality.
final class RecitationFileNotInPack extends RecitationFailure {
  const RecitationFileNotInPack(
    super.recitationId, {
    required this.qualityKbps,
    required this.surah,
    required this.ayah,
  });

  final int qualityKbps;
  final int surah;
  final int? ayah;

  @override
  String toString() =>
      'RecitationFileNotInPack($recitationId): $qualityKbps kbps, '
      'surah $surah${ayah == null ? '' : ', ayah $ayah'}';
}

/// The installed pack is not the one the catalogue describes: another
/// kind or riwaya or, at the catalogue's version, another unit or other
/// qualities. The pack itself may be sound, so its integrity is not touched.
final class RecitationDiffersFromCatalogue extends RecitationFailure {
  const RecitationDiffersFromCatalogue(super.recitationId, this.reason);

  final String reason;

  @override
  String toString() => 'RecitationDiffersFromCatalogue($recitationId): $reason';
}

/// The recitations that may be listed and played, and their audio
/// (`AU-01`). Listeners hear when the catalogue or the installed packs
/// change.
abstract interface class RecitationRepository implements Listenable {
  /// The recitations of the catalogue whose rights record is complete, in
  /// its order, and nothing else.
  List<CatalogueRecitation> get recitations;

  /// The file of [surah] at [qualityKbps], for a recitation by surah.
  Future<Result<RecitationAudio>> surahFile(
    String recitationId,
    int surah, {
    required int qualityKbps,
  });

  /// The file of the ayah at [address] at [qualityKbps], for a recitation by
  /// ayah. An address of another riwaya is [AddressNotInPack].
  Future<Result<RecitationAudio>> ayahFile(
    String recitationId,
    QuranAddress address, {
    required int qualityKbps,
  });
}

/// Reports a pack's integrity in this session: its id, state and version.
typedef IntegrityReport =
    void Function(String pack, PackIntegrity state, int version);

/// [RecitationRepository] over the recitation packs on the device
/// (docs/PACK_CATALOGUE.md, "A recitation at playback"). On its first use in
/// the session a pack directory is verified in full, its file count and
/// rows are checked, and the outcome is given to [_report]; a pack that
/// fails, or that [_integrityOf] says failed, serves nothing. A file is
/// local when `<audio directory>/<pack id>/<sha256><extension>` has the size
/// the pack states.
final class PackRecitationRepository implements RecitationRepository {
  PackRecitationRepository({
    required this._catalogue,
    required this._installed,
    required this._changes,
    required this._verify,
    required this._integrityOf,
    required this._report,
    required this._files,
    required this._audioDirectory,
  });

  final Catalogue? Function() _catalogue;
  final List<InstalledPack> Function() _installed;
  final Listenable _changes;
  final PackCheck _verify;
  final PackIntegrity Function(String pack) _integrityOf;
  final IntegrityReport _report;
  final PackFileService _files;
  final Future<String> Function() _audioDirectory;

  /// Each pack directory checked in this session.
  final _checked = <String, Future<Result<_PackFiles>>>{};
  String? _audioRoot;

  @override
  void addListener(VoidCallback listener) => _changes.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _changes.removeListener(listener);

  @override
  List<CatalogueRecitation> get recitations =>
      _catalogue()?.listedRecitations ?? const [];

  @override
  Future<Result<RecitationAudio>> surahFile(
    String recitationId,
    int surah, {
    required int qualityKbps,
  }) => _audio(recitationId, (
    qualityKbps,
    RecitationFilePart.surah,
    surah,
    null,
  ));

  @override
  Future<Result<RecitationAudio>> ayahFile(
    String recitationId,
    QuranAddress address, {
    required int qualityKbps,
  }) => _audio(recitationId, (
    qualityKbps,
    RecitationFilePart.ayah,
    address.surah,
    address.ayah,
  ), address: address);

  Future<Result<RecitationAudio>> _audio(
    String recitationId,
    _FileKey key, {
    QuranAddress? address,
  }) async {
    final listed = recitations.where((r) => r.id == recitationId).firstOrNull;
    if (listed == null) return Failure(RecitationNotListed(recitationId));
    final packId = listed.packId;
    if (address != null && address.riwaya != listed.recitation.riwaya) {
      return Failure(AddressNotInPack(packId, address));
    }
    final pack = _installed().where((p) => p.id == packId).firstOrNull;
    if (pack == null) {
      return Failure(RecitationPackNotInstalled(recitationId, packId));
    }
    if (pack.manifest.kind != PackKind.recitation) {
      return Failure(
        RecitationDiffersFromCatalogue(
          recitationId,
          '$packId is a ${pack.manifest.kind.name} pack',
        ),
      );
    }
    final _PackFiles files;
    switch (await (_checked[pack.directory] ??= _check(pack))) {
      case Ok(:final value):
        files = value;
      case Failure(:final error):
        return Failure(error);
    }
    if (_integrityOf(packId) is IntegrityFailed) {
      return Failure(PackDisabled(packId));
    }
    if (_difference(listed, pack, files) case final reason?) {
      return Failure(RecitationDiffersFromCatalogue(recitationId, reason));
    }
    final file = files.byKey[key];
    if (file == null) {
      final (quality, _, surah, ayah) = key;
      return Failure(
        RecitationFileNotInPack(
          recitationId,
          qualityKbps: quality,
          surah: surah!,
          ayah: ayah,
        ),
      );
    }
    final path = await _localPath(packId, file);
    return Ok(
      path == null
          ? RecitationAudio(
              file: file,
              uri: files.baseUrl.resolve(file.path),
              local: false,
            )
          : RecitationAudio(file: file, uri: Uri.file(path), local: true),
    );
  }

  /// How [pack] differs from what the catalogue says of [listed]: its
  /// riwaya always, its unit and qualities only at the catalogue's version,
  /// since an older version may differ and still serve until it is
  /// replaced. Null when it does not.
  String? _difference(
    CatalogueRecitation listed,
    InstalledPack pack,
    _PackFiles files,
  ) {
    final recitation = listed.recitation;
    if (pack.manifest.riwaya != recitation.riwaya) {
      return 'riwaya ${pack.manifest.riwaya}, not ${recitation.riwaya}';
    }
    if (_catalogue()?.pack(pack.id)?.version != pack.version) return null;
    if (files.unit != recitation.unit) {
      return 'unit ${files.unit.name}, not ${recitation.unit.name}';
    }
    if (!listEquals(files.qualities, listed.qualities)) {
      return 'qualities ${files.qualities}, not ${listed.qualities}';
    }
    return null;
  }

  /// Where [file] is on the device, when it is there whole by its size.
  /// A device that cannot say leaves it to be streamed.
  Future<String?> _localPath(String packId, RecitationFile file) async {
    try {
      final root = _audioRoot ??= await _audioDirectory();
      final name = file.path.split('/').last;
      final dot = name.lastIndexOf('.');
      final path =
          '$root/$packId/${file.sha256}${dot < 0 ? '' : name.substring(dot)}';
      return await _files.sizeOf(path) == file.bytes ? path : null;
    } on Exception {
      return null;
    }
  }

  Future<Result<_PackFiles>> _check(InstalledPack pack) async {
    final result = switch (await _verify(pack.directory)) {
      Ok(:final value) => _read(value),
      Failure(:final error) => Failure<_PackFiles>(error),
    };
    _report(pack.id, switch (result) {
      Ok() => const IntegrityOk(),
      Failure(error: final PackFailure failure) => IntegrityFailed(failure),
      Failure(:final error) => IntegrityFailed(
        PackInconsistent(pack.directory, '$error'),
      ),
    }, pack.version);
    return result;
  }

  /// The files of [pack], once its file count is `counts.files` and every
  /// row is well formed.
  static Result<_PackFiles> _read(VerifiedPack pack) {
    final directory = pack.directory;
    final manifest = pack.manifest;
    final count = switch (manifest.kindCounts) {
      RecitationCounts(:final files) => files,
      _ => null,
    };
    if (count == null) {
      return Failure(PackInconsistent(directory, 'is not a recitation pack'));
    }
    RecitationPackIndex? index;
    try {
      index = RecitationPackIndex.open(
        '$directory/$recitationPackFileName',
        formatVersion: manifest.formatVersion,
      );
      final facts = index.recitation();
      if (index.fileCount() case final stored when stored != count) {
        return Failure(
          PackInconsistent(
            directory,
            'holds $stored files, counts.files is $count',
          ),
        );
      }
      final qualities = index.qualities();
      return Ok(
        _PackFiles(
          unit: facts.unit,
          qualities: qualities,
          baseUrl: facts.baseUrl,
          byKey: {
            for (final quality in qualities)
              for (final file in index.files(quality))
                (file.qualityKbps, file.part, file.surah, file.ayah): file,
          },
        ),
      );
    } on PackFailure catch (failure) {
      return Failure(failure);
    } on Exception catch (error) {
      return Failure(PackInconsistent(directory, '$error'));
    } finally {
      index?.close();
    }
  }
}

typedef _FileKey = (
  int quality,
  RecitationFilePart part,
  int? surah,
  int? ayah,
);

final class _PackFiles {
  const _PackFiles({
    required this.unit,
    required this.qualities,
    required this.baseUrl,
    required this.byKey,
  });

  final RecitationUnit unit;
  final List<int> qualities;
  final Uri baseUrl;
  final Map<_FileKey, RecitationFile> byKey;
}
