import 'package:holyquran/config/test_copy.dart';

/// The base pack the app bundles under `assets/packs/<id>/<version>/`. Null
/// until B0.2 builds and signs it, as only a signed, verified pack enters
/// the assets (D-030).
const ({String id, int version})? bundledBasePack = null;

/// The base pack this build reads: the unapproved test copy's pack when the
/// build is one (D-163), else the bundled one.
({String id, int version})? get basePackInUse =>
    testCopy?.pack ?? bundledBasePack;
