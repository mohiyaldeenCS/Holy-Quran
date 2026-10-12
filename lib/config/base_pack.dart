/// The base pack the app bundles under `assets/packs/<id>/<version>/`. Null
/// until B0.2 builds and signs it, as only a signed, verified pack enters
/// the assets (D-030).
const ({String id, int version})? bundledBasePack = null;
