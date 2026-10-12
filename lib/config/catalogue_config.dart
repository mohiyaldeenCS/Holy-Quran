/// The HTTPS address of `catalogue.json` (D-109, docs/PACK_CATALOGUE.md); its
/// signature is at the same address followed by `.sig`. Empty until the
/// first test pack and catalogue are published on this repository's GitHub
/// Releases (O-08): until then the catalogue is not configured.
const String catalogueAddress = '';

/// [catalogueAddress] as a URL; null while the catalogue is not configured.
Uri? get catalogueUrl =>
    catalogueAddress.isEmpty ? null : Uri.parse(catalogueAddress);
