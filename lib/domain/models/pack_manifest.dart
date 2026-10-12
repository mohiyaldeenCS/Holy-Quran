import 'edition_map.dart';

enum PackKind { text, tafsir, recitation }

enum TrustGrade { a, b, c }

/// What a pack takes from a source: its text, its edition's divisions, the
/// search forms of its words, a tafsir book or a recitation.
enum SourceRole { text, editionMap, searchForms, tafsir, recitation }

/// A pack's `manifest.json` (docs/CONTENT_PACKS.md). Dates are kept as the
/// manifest writes them, `YYYY-MM-DD`.
///
/// [edition], [font], [surahSha256] and [counts] belong to a text pack
/// only: a text manifest has all of them, any other none, and reading one
/// of another kind's manifest is a [StateError]. [kindCounts] holds the
/// counts of every kind.
final class PackManifest {
  PackManifest({
    required this.formatVersion,
    required this.id,
    required this.kind,
    required this.version,
    required List<PackChange> changelog,
    required this.riwaya,
    String? edition,
    PackFont? font,
    required List<PackSource> sources,
    required List<PackFile> files,
    Map<int, String>? surahSha256,
    required PackKindCounts counts,
    required List<PackReview> reviews,
  }) : changelog = List.unmodifiable(changelog),
       sources = List.unmodifiable(sources),
       files = List.unmodifiable(files),
       _edition = edition,
       _font = font,
       _surahSha256 = surahSha256 == null
           ? null
           : Map.unmodifiable(surahSha256),
       kindCounts = counts,
       reviews = List.unmodifiable(reviews) {
    final textFields = [edition, font, surahSha256];
    final matches = switch ((kind, counts)) {
      (PackKind.text, PackCounts()) => !textFields.contains(null),
      (PackKind.tafsir, TafsirCounts()) ||
      (
        PackKind.recitation,
        RecitationCounts(),
      ) => textFields.every((field) => field == null),
      _ => false,
    };
    if (!matches) {
      throw ArgumentError('The fields do not match a ${kind.name} manifest');
    }
  }

  final int formatVersion;
  final String id;
  final PackKind kind;
  final int version;
  final List<PackChange> changelog;

  /// Null for a pack to which no riwaya applies.
  final String? riwaya;
  final String? _edition;
  final PackFont? _font;
  final List<PackSource> sources;
  final List<PackFile> files;
  final Map<int, String>? _surahSha256;
  final PackKindCounts kindCounts;
  final List<PackReview> reviews;

  String get edition => _edition ?? _notText('edition');

  PackFont get font => _font ?? _notText('font');

  Map<int, String> get surahSha256 => _surahSha256 ?? _notText('surahSha256');

  PackCounts get counts => switch (kindCounts) {
    final PackCounts counts => counts,
    _ => _notText('counts'),
  };

  Never _notText(String field) =>
      throw StateError('A ${kind.name} manifest has no $field');
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
  PackSource({
    required this.role,
    required this.registryRow,
    required this.name,
    required this.publisher,
    required this.url,
    required this.version,
    required this.fetchedOn,
    required this.fileSha256,
    required this.trustGrade,
    required Map<String, Object>? options,
    required this.licence,
  }) : options = options == null ? null : Map.unmodifiable(options) {
    for (final MapEntry(:key, :value)
        in (this.options ?? const <String, Object>{}).entries) {
      if (value is! String && value is! num && value is! bool) {
        throw ArgumentError.value(
          value,
          'options[$key]',
          'is not a string, number or boolean',
        );
      }
    }
  }

  final SourceRole role;
  final int registryRow;
  final String name;
  final String publisher;
  final String url;
  final String version;
  final String fetchedOn;
  final String fileSha256;
  final TrustGrade trustGrade;

  /// The choices the source file was produced with, as the source names
  /// them: each value a [String], a [num] or a [bool]. Null when the source
  /// offers none (D-077).
  final Map<String, Object>? options;
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

/// The counts a manifest gives, by kind.
sealed class PackKindCounts {
  const PackKindCounts();
}

/// The counts of a text pack.
final class PackCounts extends PackKindCounts {
  PackCounts({
    required this.surahs,
    required this.ayat,
    required this.words,
    required this.marks,
    required Map<Division, int> divisions,
    required this.sajdas,
    Map<String, int> searchForms = const {},
  }) : divisions = Map.unmodifiable(divisions),
       searchForms = Map.unmodifiable(searchForms);

  final int surahs;
  final int ayat;
  final int words;
  final int marks;
  final Map<Division, int> divisions;
  final int sajdas;

  /// The rows of each search form kind the pack provides, one per word;
  /// empty when it provides none, as every format 1 pack.
  final Map<String, int> searchForms;
}

final class TafsirCounts extends PackKindCounts {
  const TafsirCounts({required this.passages});

  final int passages;
}

final class RecitationCounts extends PackKindCounts {
  const RecitationCounts({required this.files});

  final int files;
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
