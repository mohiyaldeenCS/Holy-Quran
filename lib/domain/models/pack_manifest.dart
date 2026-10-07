import 'edition_map.dart';

enum PackKind { text }

enum TrustGrade { a, b, c }

/// What a pack takes from a source: its text, or its edition's divisions.
enum SourceRole { text, editionMap }

/// A pack's `manifest.json` (docs/CONTENT_PACKS.md). Dates are kept as the
/// manifest writes them, `YYYY-MM-DD`.
final class PackManifest {
  PackManifest({
    required this.formatVersion,
    required this.id,
    required this.kind,
    required this.version,
    required List<PackChange> changelog,
    required this.riwaya,
    required this.edition,
    required this.font,
    required List<PackSource> sources,
    required List<PackFile> files,
    required Map<int, String> surahSha256,
    required this.counts,
    required List<PackReview> reviews,
  }) : changelog = List.unmodifiable(changelog),
       sources = List.unmodifiable(sources),
       files = List.unmodifiable(files),
       surahSha256 = Map.unmodifiable(surahSha256),
       reviews = List.unmodifiable(reviews);

  final int formatVersion;
  final String id;
  final PackKind kind;
  final int version;
  final List<PackChange> changelog;

  /// Null for a pack to which no riwaya applies.
  final String? riwaya;
  final String edition;
  final PackFont font;
  final List<PackSource> sources;
  final List<PackFile> files;
  final Map<int, String> surahSha256;
  final PackCounts counts;
  final List<PackReview> reviews;
}

final class PackChange {
  const PackChange({
    required this.version,
    required this.date,
    required this.summary,
  });

  final int version;
  final String date;
  final String summary;
}

final class PackFont {
  const PackFont({
    required this.family,
    required this.version,
    required this.sha256,
  });

  final String family;
  final String version;
  final String sha256;
}

final class PackSource {
  const PackSource({
    required this.role,
    required this.registryRow,
    required this.name,
    required this.publisher,
    required this.url,
    required this.version,
    required this.fetchedOn,
    required this.fileSha256,
    required this.trustGrade,
    required this.licence,
  });

  final SourceRole role;
  final int registryRow;
  final String name;
  final String publisher;
  final String url;
  final String version;
  final String fetchedOn;
  final String fileSha256;
  final TrustGrade trustGrade;
  final PackLicence licence;
}

/// At least one of [text] and [permissionRef] is set; the parser refuses a
/// licence with neither.
final class PackLicence {
  const PackLicence({
    required this.text,
    required this.permissionRef,
    required this.notice,
    required this.allowsExport,
  });

  final String? text;
  final String? permissionRef;
  final String? notice;
  final bool allowsExport;
}

final class PackFile {
  const PackFile({
    required this.name,
    required this.sha256,
    required this.bytes,
  });

  final String name;
  final String sha256;
  final int bytes;
}

final class PackCounts {
  PackCounts({
    required this.surahs,
    required this.ayat,
    required this.words,
    required Map<Division, int> divisions,
    required this.sajdas,
  }) : divisions = Map.unmodifiable(divisions);

  final int surahs;
  final int ayat;
  final int words;
  final Map<Division, int> divisions;
  final int sajdas;
}

final class PackReview {
  const PackReview({
    required this.reviewer,
    required this.date,
    required this.scope,
  });

  final String reviewer;
  final String date;
  final String scope;
}
