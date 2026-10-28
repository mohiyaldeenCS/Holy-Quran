import 'pack_manifest.dart';

/// One source the packs draw on, as its manifest publishes it (D-128 (6)):
/// the name, the link, the publisher, the version and the licence or credit
/// text unchanged. A field the manifest leaves empty is null.
final class SourceCredit {
  const SourceCredit({
    required this.name,
    required this.url,
    required this.publisher,
    required this.version,
    required this.licenceText,
    required this.notice,
  });

  final String name;
  final String url;
  final String? publisher;
  final String? version;
  final String? licenceText;
  final String? notice;

  @override
  bool operator ==(Object other) =>
      other is SourceCredit &&
      other.name == name &&
      other.url == url &&
      other.publisher == publisher &&
      other.version == version &&
      other.licenceText == licenceText &&
      other.notice == notice;

  @override
  int get hashCode =>
      Object.hash(name, url, publisher, version, licenceText, notice);
}

/// The sources of [manifests], in their order and each manifest's, a source
/// that several packs share listed once.
List<SourceCredit> sourcesOf(Iterable<PackManifest> manifests) {
  final seen = <SourceCredit>{};
  final credits = <SourceCredit>[];
  for (final manifest in manifests) {
    for (final source in manifest.sources) {
      final credit = SourceCredit(
        name: source.name,
        url: source.url,
        publisher: _present(source.publisher),
        version: _present(source.version),
        licenceText: _present(source.licence.text),
        notice: _present(source.licence.notice),
      );
      if (seen.add(credit)) credits.add(credit);
    }
  }
  return credits;
}

String? _present(String? text) =>
    text == null || text.trim().isEmpty ? null : text;
