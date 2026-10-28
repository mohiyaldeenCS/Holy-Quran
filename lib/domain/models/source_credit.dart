import 'installed_pack.dart';

/// One source the installed packs draw on, as its manifest publishes it
/// (D-128 (6)): the name, the link, and the licence or credit text unchanged.
/// A field the manifest leaves empty is null.
final class SourceCredit {
  const SourceCredit({
    required this.name,
    required this.url,
    required this.licenceText,
    required this.notice,
  });

  final String name;
  final String url;
  final String? licenceText;
  final String? notice;

  @override
  bool operator ==(Object other) =>
      other is SourceCredit &&
      other.name == name &&
      other.url == url &&
      other.licenceText == licenceText &&
      other.notice == notice;

  @override
  int get hashCode => Object.hash(name, url, licenceText, notice);
}

/// The sources of [installed], in the order of the packs and of each
/// manifest, a source that several packs share listed once.
List<SourceCredit> sourcesOf(List<InstalledPack> installed) {
  final seen = <SourceCredit>{};
  final credits = <SourceCredit>[];
  for (final pack in installed) {
    for (final source in pack.manifest.sources) {
      final credit = SourceCredit(
        name: source.name,
        url: source.url,
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
