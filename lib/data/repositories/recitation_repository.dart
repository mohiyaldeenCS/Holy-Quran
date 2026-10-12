import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/catalogue.dart';
import '../../domain/models/catalogue_entry.dart';
import '../../domain/models/installed_pack.dart';
import '../../domain/models/pack_failure.dart';
import '../../domain/models/pack_integrity.dart';
import '../../domain/models/pack_manifest.dart';
import '../../domain/models/quran_address.dart';
import '../../domain/models/recitation_file.dart';
import '../../domain/models/verified_pack.dart';
import '../../utils/result.dart';
import '../models/pack_manifest_json.dart';
import '../services/pack_file_service.dart';
import '../services/recitation_pack_index.dart';
import 'pack_integrity_repository.dart';

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

/// [RecitationRepository] over the recitation packs on the device
/// (docs/PACK_CATALOGUE.md, "A recitation at playback"). On its first use in
/// the session a pack is verified in full and checked against the
/// catalogue, its rows are read, and the outcome is reported to
/// [_integrity]; a pack that fails, or that another reader reports failed,
/// serves nothing. A file is local when `<audio directory>/<pack id>/<path>`
/// has the size the pack states.
final class PackRecitationRepository implements RecitationRepository {
  PackRecitationRepository({
    required this._catalogue,
    required this._installed,
    required this._changes,
    required this._verify,
    required this._integrity,
    required this._files,
    required this._audioDirectory,
  });

  final Catalogue? Function() _catalogue;
  final List<InstalledPack> Function() _installed;
  final Listenable _changes;
  final PackCheck _verify;
  final PackIntegrityRepository _integrity;
  final PackFileService _files;
  final Future<String> Function() _audioDirectory;

  /// Each pack directory checked in this session.
  final _checked = <String, Future<Result<_PackFiles>>>{};
  Future<String>? _audioRoot;

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
    final _PackFiles files;
    switch (await (_checked[pack.directory] ??= _check(listed, pack))) {
      case Ok(:final value):
        files = value;
      case Failure(:final error):
        return Failure(error);
    }
    if (_integrity.stateOf(packId) is IntegrityFailed) {
      return Failure(PackDisabled(packId));
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
    final path =
        '${await (_audioRoot ??= _audioDirectory())}/$packId/'
        '${file.path}';
    final local = await _files.sizeOf(path) == file.bytes;
    return Ok(
      RecitationAudio(
        file: file,
        uri: local ? Uri.file(path) : files.baseUrl.resolve(file.path),
        local: local,
      ),
    );
  }

  Future<Result<_PackFiles>> _check(
    CatalogueRecitation listed,
    InstalledPack pack,
  ) async {
    final result = switch (await _verify(pack.directory)) {
      Ok(:final value) => _read(listed, value),
      Failure(:final error) => Failure<_PackFiles>(error),
    };
    _integrity.report(pack.id, switch (result) {
      Ok() => const IntegrityOk(),
      Failure(error: final PackFailure failure) => IntegrityFailed(failure),
      Failure(:final error) => IntegrityFailed(
        PackInconsistent(pack.directory, '$error'),
      ),
    }, version: pack.version);
    return result;
  }

  /// The files of [pack], once its kind, riwaya, unit, qualities and file
  /// count are the catalogue's and every row is well formed.
  static Result<_PackFiles> _read(
    CatalogueRecitation listed,
    VerifiedPack pack,
  ) {
    final directory = pack.directory;
    final manifest = pack.manifest;
    final recitation = listed.recitation;
    Failure<_PackFiles> inconsistent(String reason) =>
        Failure(PackInconsistent(directory, reason));
    final count = switch (manifest.kindCounts) {
      RecitationCounts(:final files) => files,
      _ => null,
    };
    if (count == null) return inconsistent('is not a recitation pack');
    if (manifest.riwaya != recitation.riwaya) {
      return inconsistent(
        'riwaya ${manifest.riwaya} is not the catalogue riwaya '
        '${recitation.riwaya}',
      );
    }
    RecitationPackIndex? index;
    try {
      index = RecitationPackIndex.open(
        '$directory/$recitationPackFileName',
        formatVersion: manifest.formatVersion,
      );
      final facts = index.recitation();
      if (facts.unit != recitation.unit) {
        return inconsistent(
          'unit ${facts.unit.name} is not the catalogue unit '
          '${recitation.unit.name}',
        );
      }
      if (index.fileCount() case final stored when stored != count) {
        return inconsistent('holds $stored files, counts.files is $count');
      }
      final qualities = index.qualities();
      if (!listEquals(qualities, listed.qualities)) {
        return inconsistent(
          'qualities $qualities are not the catalogue qualities '
          '${listed.qualities}',
        );
      }
      return Ok(
        _PackFiles(facts.baseUrl, {
          for (final quality in qualities)
            for (final file in index.files(quality))
              (file.qualityKbps, file.part, file.surah, file.ayah): file,
        }),
      );
    } on PackFailure catch (failure) {
      return Failure(failure);
    } on Exception catch (error) {
      return inconsistent('$error');
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
  const _PackFiles(this.baseUrl, this.byKey);

  final Uri baseUrl;
  final Map<_FileKey, RecitationFile> byKey;
}
