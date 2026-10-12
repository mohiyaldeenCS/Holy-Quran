import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../domain/models/pack_failure.dart';
import '../../domain/models/pack_integrity.dart';
import '../../domain/models/verified_pack.dart';
import '../../utils/result.dart';
import '../models/pack_manifest_json.dart';
import '../services/base_pack_service.dart';

/// The integrity of each pack in this session. Repositories that read a
/// pack report what their checks find; screens listen and show the
/// integrity alert (PRD section 9.5).
abstract interface class PackIntegrityRepository implements Listenable {
  /// The state of pack [pack], by id; [IntegrityMissing] for a pack nothing
  /// has reported.
  PackIntegrity stateOf(String pack);

  /// Each change of state, from the start of the session. It has one
  /// listener, the integrity log; changes made before it listens are kept
  /// for it.
  Stream<PackIntegrityEvent> get events;

  /// Records [state] for [pack], notifying and adding an event when it
  /// differs from the state before. Every failure is recorded.
  void report(String pack, PackIntegrity state, {int? version});
}

/// Checks a pack in a directory.
typedef PackCheck = Future<Result<VerifiedPack>> Function(String directory);

final class LocalPackIntegrityRepository extends ChangeNotifier
    implements PackIntegrityRepository {
  /// [verify] checks every file in full; [verifySizes] skips hashing, for a
  /// copy that passed [verify] at an earlier start.
  LocalPackIntegrityRepository({
    required this._basePack,
    required this._verify,
    required this._verifySizes,
    this._clock = DateTime.now,
  });

  static const _manifest = 'manifest.json';
  static const _signature = 'manifest.json.sig';

  final BasePackService _basePack;
  final PackCheck _verify;
  final PackCheck _verifySizes;
  final DateTime Function() _clock;
  final _states = <String, PackIntegrity>{};
  final _events = StreamController<PackIntegrityEvent>();

  @override
  PackIntegrity stateOf(String pack) =>
      _states[pack] ?? const IntegrityMissing();

  @override
  Stream<PackIntegrityEvent> get events => _events.stream;

  @override
  void report(String pack, PackIntegrity state, {int? version}) {
    final before = _states[pack];
    if (state is! IntegrityFailed && before.runtimeType == state.runtimeType) {
      return;
    }
    _states[pack] = state;
    _events.add(
      PackIntegrityEvent(
        pack: pack,
        version: version,
        state: state,
        at: _clock(),
      ),
    );
    notifyListeners();
  }

  /// Copies the bundled base pack to the support directory and checks it in
  /// full, once per bundled manifest: later starts check the copy's
  /// manifest, signature and sizes, and each surah is checked on its first
  /// read. A copy that fails is copied once more; if that fails too, the
  /// pack is [IntegrityFailed]. Returns the verified pack, or null when it
  /// is missing or failed; [stateOf] says which.
  Future<VerifiedPack?> verifyBasePack() async {
    final id = _basePack.id;
    final version = _basePack.version;
    final manifest = await _basePack.readBundled(_manifest);
    if (manifest == null) {
      report(id, const IntegrityMissing(), version: version);
      return null;
    }
    final List<String> names;
    switch (parsePackManifest(manifest, pack: id)) {
      case Ok(:final value):
        names = [
          _manifest,
          _signature,
          for (final file in value.files) file.name,
        ];
      case Failure(:final error):
        report(id, IntegrityFailed(_named(id, error)), version: version);
        return null;
    }
    final directory = await _basePack.directory();

    if (await _basePack.remembers(manifest)) {
      if (await _verifySizes(directory) case Ok(:final value)) {
        report(id, const IntegrityOk(), version: version);
        return value;
      }
      report(id, const IntegrityRepairing(), version: version);
    }
    for (var attempt = 1; ; attempt++) {
      switch (await _copyAndVerify(names, directory)) {
        case Ok(:final value):
          await _remember(manifest);
          report(id, const IntegrityOk(), version: version);
          return value;
        case Failure(:final error) when attempt == 2:
          report(id, IntegrityFailed(_named(id, error)), version: version);
          return null;
        case Failure():
          report(id, const IntegrityRepairing(), version: version);
      }
    }
  }

  Future<Result<VerifiedPack>> _copyAndVerify(
    List<String> names,
    String directory,
  ) async {
    try {
      await _basePack.forget();
      await _basePack.extract(names);
    } on FileSystemException catch (error) {
      return Failure(
        ManifestUnreadable(directory, 'could not be copied: ${error.message}'),
      );
    }
    return _verify(directory);
  }

  Future<void> _remember(Uint8List manifest) async {
    try {
      await _basePack.remember(manifest);
    } on FileSystemException {
      // Unremembered, the copy is checked in full again at the next start.
    }
  }

  static PackFailure _named(String pack, Exception error) => switch (error) {
    PackFailure() => error,
    _ => ManifestUnreadable(pack, '$error'),
  };

  /// Forgets that the base pack passed its full check, so that the next
  /// start copies and checks it again, after a check while reading failed.
  Future<void> forgetBasePackCheck() async {
    try {
      await _basePack.forget();
    } on FileSystemException {
      // The first read of each surah still checks it.
    }
  }

  @override
  void dispose() {
    unawaited(_events.close());
    super.dispose();
  }
}
