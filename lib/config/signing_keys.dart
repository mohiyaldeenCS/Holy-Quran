/// The Ed25519 public keys a manifest may be signed with, each the raw 32
/// bytes: the key in use and a spare (D-108). Empty until the owner's key
/// steps (docs/plans/PHASE1.md section 3.2); only public keys belong here.
const List<List<int>> manifestPublicKeys = [];
