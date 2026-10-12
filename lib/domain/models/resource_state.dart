import 'catalogue.dart';
import 'catalogue_entry.dart';
import 'install_job.dart';
import 'installed_pack.dart';

/// Where a pack the catalogue offers stands on this device (`OF-02`,
/// `TF-01`).
sealed class ResourceState {
  const ResourceState();
}

/// Not installed.
final class ResourceAvailable extends ResourceState {
  const ResourceAvailable();

  @override
  bool operator ==(Object other) => other is ResourceAvailable;

  @override
  int get hashCode => (ResourceAvailable).hashCode;

  @override
  String toString() => 'available';
}

/// An install job for the pack is in the queue; [job] says how it stands.
final class ResourceDownloading extends ResourceState {
  const ResourceDownloading(this.job);

  final InstallState job;

  /// From 0 to 100 while the job fetches or is paused with a known size;
  /// null otherwise.
  int? get percent => switch (job) {
    InstallDownloading(:final progress) ||
    InstallPaused(:final progress) => switch (progress.fraction) {
      final fraction? => (fraction * 100).floor(),
      null => null,
    },
    _ => null,
  };

  @override
  String toString() => 'downloading $percent';
}

/// The catalogue's version, or a newer one, is installed.
final class ResourceDownloaded extends ResourceState {
  const ResourceDownloaded(this.version);

  final int version;

  @override
  bool operator ==(Object other) =>
      other is ResourceDownloaded && other.version == version;

  @override
  int get hashCode => version.hashCode;

  @override
  String toString() => 'downloaded $version';
}

/// An older version than the catalogue's is installed; the entry's
/// `changes` says what the new one changes (`OF-06`).
final class ResourceUpdateAvailable extends ResourceState {
  const ResourceUpdateAvailable({
    required this.installedVersion,
    required this.version,
  });

  final int installedVersion;
  final int version;

  @override
  bool operator ==(Object other) =>
      other is ResourceUpdateAvailable &&
      other.installedVersion == installedVersion &&
      other.version == version;

  @override
  int get hashCode => Object.hash(installedVersion, version);

  @override
  String toString() => 'newer $version over $installedVersion';
}

/// A pack the catalogue offers, its state, and the failure of its last
/// install job while that is listed.
final class Resource {
  const Resource({
    required this.entry,
    required this.state,
    required this.failure,
  });

  final CatalogueEntry entry;
  final ResourceState state;
  final InstallFailure? failure;
}

/// Every pack [catalogue] offers, in its order, joined with the [installed]
/// packs and the install [jobs] (docs/PACK_CATALOGUE.md, "Joining with the
/// installed packs").
List<Resource> resourcesOf(
  Catalogue catalogue, {
  required List<InstalledPack> installed,
  required List<InstallJob> jobs,
}) => [
  for (final entry in catalogue.offeredPacks)
    resourceOf(
      entry,
      installed: installed.where((pack) => pack.id == entry.id).firstOrNull,
      job: jobs.where((job) => job.request.packId == entry.id).firstOrNull,
    ),
];

/// [entry] joined with its [installed] pack and its install [job], each
/// null when there is none.
Resource resourceOf(
  CatalogueEntry entry, {
  required InstalledPack? installed,
  required InstallJob? job,
}) {
  final failure = switch (job?.state) {
    InstallFailed(:final failure) => failure,
    _ => null,
  };
  final ResourceState state = switch ((job?.state, installed?.version)) {
    (final InstallState running?, _) when running is! InstallFailed =>
      ResourceDownloading(running),
    (_, null) => const ResourceAvailable(),
    (_, final version?) when version < entry.version => ResourceUpdateAvailable(
      installedVersion: version,
      version: entry.version,
    ),
    (_, final version?) => ResourceDownloaded(version),
  };
  return Resource(entry: entry, state: state, failure: failure);
}

/// The [installed] packs [catalogue] does not offer: they can still be
/// deleted, and are not offered for download.
List<InstalledPack> installedNotOffered(
  Catalogue catalogue,
  List<InstalledPack> installed,
) {
  final offered = {for (final entry in catalogue.offeredPacks) entry.id};
  return [
    for (final pack in installed)
      if (!offered.contains(pack.id)) pack,
  ];
}
