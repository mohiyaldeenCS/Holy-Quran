import 'package:holyquran/domain/models/catalogue_entry.dart';
import 'package:holyquran/domain/models/install_job.dart';
import 'package:holyquran/domain/models/resource_state.dart';

/// The alert a row shows beside its state.
enum PackRowAlert {
  /// The pack failed a check, at install or at run time (PRD §9.5).
  integrity,

  /// A file of the last install job did not arrive.
  connection,
}

/// One pack of the resource manager: the catalogue's entry joined with the
/// installer, and whether its installed copy failed its run-time check.
final class PackRowState {
  const PackRowState(this.resource, {required this.integrityFailed});

  final Resource resource;
  final bool integrityFailed;

  CatalogueEntry get entry => resource.entry;

  ResourceState get state => resource.state;

  /// From 0 to 1 while downloading, 0 while the size is not known, and 1
  /// once every file has arrived and is being verified.
  double get progress => switch (state) {
    ResourceDownloading(
      job: InstallDownloading(:final progress) ||
          InstallPaused(:final progress),
    ) =>
      progress.fraction ?? 0,
    ResourceDownloading(job: InstallVerifying()) => 1,
    _ => 0,
  };

  PackRowAlert? get alert => integrityFailed
      ? PackRowAlert.integrity
      : switch (resource.failure) {
          ManifestRejected() ||
          FileRejected() ||
          VerificationFailed() ||
          SignatureNotChecked() => PackRowAlert.integrity,
          DownloadFailed() => PackRowAlert.connection,
          _ => null,
        };
}
