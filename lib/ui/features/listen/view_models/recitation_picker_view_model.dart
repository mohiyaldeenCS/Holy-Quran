import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/catalogue_repository.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/repositories/recitation_repository.dart';
import 'package:holyquran/domain/models/catalogue_entry.dart';
import 'package:holyquran/domain/models/resource_state.dart';

/// A recitation as the picker lists it (`AU-01`): its download state is
/// null when the catalogue or the installer cannot say.
typedef RecitationListing = ({
  CatalogueRecitation recitation,
  ResourceState? state,
});

/// The recitations that may be chosen, with their download state (`AU-01`),
/// over whichever repositories the app provides; with no recitation
/// repository nothing is listed.
final class RecitationPickerViewModel extends ChangeNotifier {
  RecitationPickerViewModel({
    this._recitations,
    this._catalogue,
    this._installs,
  }) {
    _changes.addListener(notifyListeners);
  }

  final RecitationRepository? _recitations;
  final CatalogueRepository? _catalogue;
  final PackInstallRepository? _installs;
  late final Listenable _changes = Listenable.merge([
    _recitations,
    _catalogue,
    _installs,
  ]);

  /// In the catalogue's order. A recitation without a complete rights
  /// record is never listed, whatever the repository hands over.
  List<RecitationListing> get listings => [
    for (final listed
        in _recitations?.recitations ?? const <CatalogueRecitation>[])
      if (listed.recitation.rightsComplete)
        (recitation: listed, state: _stateOf(listed.packId)),
  ];

  ResourceState? _stateOf(String packId) {
    final entry = _catalogue?.catalogue?.pack(packId);
    final installs = _installs;
    if (entry == null || installs == null) return null;
    return resourceOf(
      entry,
      installed: installs.installed.where((p) => p.id == packId).firstOrNull,
      job: installs.jobs.where((j) => j.request.packId == packId).firstOrNull,
    ).state;
  }

  @override
  void dispose() {
    _changes.removeListener(notifyListeners);
    super.dispose();
  }
}
