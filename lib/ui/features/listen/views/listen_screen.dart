import 'package:flutter/widgets.dart';

import 'package:holyquran/data/repositories/catalogue_repository.dart';
import 'package:holyquran/data/repositories/download_settings_repository.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/recitation_download_repository.dart';
import 'package:holyquran/data/repositories/recitation_repository.dart';
import 'package:holyquran/ui/features/listen/view_models/player_view_model.dart';
import 'package:holyquran/ui/features/listen/view_models/recitation_picker_view_model.dart';
import 'package:holyquran/ui/features/listen/views/player_screen.dart';
import 'package:provider/provider.dart';

/// The listen tab's first screen: the full player over the app's player.
class ListenScreen extends StatefulWidget {
  const ListenScreen({super.key});

  @override
  State<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends State<ListenScreen> {
  PlayerViewModel? _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = createPlayerViewModel(context);
  }

  @override
  void dispose() {
    _viewModel?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PlayerScreen(viewModel: _viewModel);
}

/// The player's view model, or null when the app provides no player: an
/// area provides one only over a verified base pack (D-111).
PlayerViewModel? createPlayerViewModel(BuildContext context) {
  final player = _provided<PlayerRepository>(context);
  final index = _provided<QuranIndexRepository>(context);
  if (player == null || index == null) return null;
  return PlayerViewModel(player: player, index: index);
}

/// The picker's view model over whichever of its repositories the app
/// provides; with no recitation repository it lists nothing.
RecitationPickerViewModel createRecitationPickerViewModel(
  BuildContext context,
) => RecitationPickerViewModel(
  recitations: _provided<RecitationRepository>(context),
  catalogue: _provided<CatalogueRepository>(context),
  installs: _provided<PackInstallRepository>(context),
  downloads: _provided<RecitationDownloadRepository>(context),
  settings: _provided<DownloadSettingsRepository>(context),
);

// Areas provide a repository only once what it stands on is ready.
T? _provided<T>(BuildContext context) {
  try {
    return context.read<T>();
  } on ProviderNotFoundException {
    return null;
  }
}
