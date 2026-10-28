import 'package:flutter/foundation.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/domain/models/install_job.dart';
import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/utils/result.dart';

/// A [PackInstallRepository] in memory, for view-model tests. A test sets
/// [installed] and [jobs], which notify listeners, and the answers of
/// [install], [rollback] and [delete]; every call is logged in [calls] as
/// `(method, packId)`.
final class FakePackInstallRepository extends ChangeNotifier
    implements PackInstallRepository {
  FakePackInstallRepository({
    this._installed = const [],
    this._jobs = const [],
  });

  List<InstalledPack> _installed;
  List<InstallJob> _jobs;

  Result<void> startedWith = const Ok(null);

  /// Answers [install]; by default the request is refused as queued.
  Result<InstalledPack> Function(InstallRequest request) installs = (request) =>
      Failure(AlreadyQueued(request.packId));

  /// Answers [rollback]; by default there is no previous version.
  Result<InstalledPack> Function(String packId) rollbacks = (packId) =>
      Failure(NoPreviousVersion(packId));

  /// Answers [delete]; by default it succeeds.
  Result<void> Function(String packId) deletes = (_) => const Ok(null);

  final List<(String, String)> calls = [];

  /// How many listeners are attached now.
  int listenerCount = 0;

  @override
  void addListener(VoidCallback listener) {
    listenerCount++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listenerCount--;
    super.removeListener(listener);
  }

  @override
  Future<Result<void>> get started async => startedWith;

  @override
  List<InstalledPack> get installed => _installed;

  set installed(List<InstalledPack> value) {
    _installed = value;
    notifyListeners();
  }

  @override
  List<InstallJob> get jobs => _jobs;

  set jobs(List<InstallJob> value) {
    _jobs = value;
    notifyListeners();
  }

  @override
  Future<Result<InstalledPack>> install(InstallRequest request) async {
    calls.add(('install', request.packId));
    return installs(request);
  }

  @override
  Future<void> pause(String packId) async => calls.add(('pause', packId));

  @override
  Future<void> resume(String packId) async => calls.add(('resume', packId));

  @override
  Future<void> cancel(String packId) async => calls.add(('cancel', packId));

  @override
  Future<Result<InstalledPack>> rollback(String packId) async {
    calls.add(('rollback', packId));
    return rollbacks(packId);
  }

  @override
  Future<Result<void>> delete(String packId) async {
    calls.add(('delete', packId));
    return deletes(packId);
  }
}
