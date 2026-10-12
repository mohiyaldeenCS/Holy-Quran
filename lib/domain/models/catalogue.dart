import 'catalogue_entry.dart';
import 'pack_manifest.dart';

/// The signed list of what the app can download (docs/PACK_CATALOGUE.md).
final class Catalogue {
  Catalogue({
    required this.date,
    required List<CatalogueEntry> packs,
    required List<CatalogueRecitation> recitations,
  }) : packs = List.unmodifiable(packs),
       recitations = List.unmodifiable(recitations) {
    final ids = <String>{};
    for (final pack in packs) {
      if (!ids.add(pack.id)) {
        throw ArgumentError.value(pack.id, 'packs', 'lists an id twice');
      }
    }
    if (packs.where((pack) => pack.role != null).length > 1) {
      throw ArgumentError.value(packs, 'packs', 'gives a role twice');
    }
    final recitationIds = <String>{};
    final recitationPacks = <String>{};
    for (final recitation in recitations) {
      if (!recitationIds.add(recitation.id)) {
        throw ArgumentError.value(recitation.id, 'recitations', 'twice');
      }
      if (pack(recitation.packId)?.kind != PackKind.recitation) {
        throw ArgumentError.value(
          recitation.packId,
          'recitations[${recitation.id}].pack',
          'is not a recitation pack of the catalogue',
        );
      }
      if (!recitationPacks.add(recitation.packId)) {
        throw ArgumentError.value(
          recitation.packId,
          'recitations',
          'share a pack',
        );
      }
    }
  }

  /// The day it was published, `YYYY-MM-DD`.
  final String date;
  final List<CatalogueEntry> packs;

  /// Every recitation, also those whose rights record is not complete;
  /// [listedRecitations] holds those that may be shown.
  final List<CatalogueRecitation> recitations;

  CatalogueEntry? pack(String id) =>
      packs.where((pack) => pack.id == id).firstOrNull;

  /// The short tafsir fetched at first use (`TF-06`); null when none is
  /// offered.
  CatalogueEntry? get firstUseTafsir => packs
      .where((pack) => pack.role == CatalogueRole.firstUseTafsir)
      .firstOrNull;

  /// The recitations whose rights record is complete, the only ones listed
  /// or played (`AU-01`).
  List<CatalogueRecitation> get listedRecitations => [
    for (final recitation in recitations)
      if (recitation.recitation.rightsComplete) recitation,
  ];
}

/// Why no catalogue was accepted.
sealed class CatalogueFailure implements Exception {
  const CatalogueFailure();
}

/// The catalogue or its signature could not be fetched.
final class CatalogueUnreachable extends CatalogueFailure {
  const CatalogueUnreachable(this.url, this.reason);

  final Uri url;
  final String reason;

  @override
  String toString() => 'CatalogueUnreachable($url): $reason';
}

/// The catalogue is not one this app reads: not its format, or a value
/// breaks it, or a URL in it is one the download policy refuses.
final class CatalogueRejected extends CatalogueFailure {
  const CatalogueRejected(this.reason);

  final String reason;

  @override
  String toString() => 'CatalogueRejected: $reason';
}

/// The catalogue has a format version this app does not read. [version]
/// is null when it is not an integer.
final class CatalogueUnsupported extends CatalogueFailure {
  const CatalogueUnsupported(this.version);

  final int? version;

  @override
  String toString() => 'CatalogueUnsupported: version $version';
}

final class CatalogueSignatureRejected extends CatalogueFailure {
  const CatalogueSignatureRejected();

  @override
  String toString() => 'CatalogueSignatureRejected';
}

/// The signature could not be checked, and this build accepts only a valid
/// one (D-108).
final class CatalogueSignatureNotChecked extends CatalogueFailure {
  const CatalogueSignatureNotChecked();

  @override
  String toString() => 'CatalogueSignatureNotChecked';
}
