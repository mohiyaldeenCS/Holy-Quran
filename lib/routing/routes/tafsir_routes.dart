import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/catalogue_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/repositories/tafsir_repository.dart';
import 'package:holyquran/data/services/clipboard_service.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/routing/routes/sheet_needs.dart';
import 'package:holyquran/ui/features/tafsir/tafsir_copy_text.dart';
import 'package:holyquran/ui/features/tafsir/view_models/tafsir_view_model.dart';
import 'package:holyquran/ui/features/tafsir/views/tafsir_reader_screen.dart';
import 'package:holyquran/ui/features/tafsir/views/tafsir_sheet.dart';
import 'package:provider/provider.dart';

/// The tafsir reader of the study tab (`TF-02`, `TF-03`) and the tafsir sheet
/// of the ayah tools (`TF-02`, which the toolbar opens once it exists,
/// P1-23). Both read the text pack and, when the app provides them, the
/// tafsir repository, the catalogue and the clipboard; without a tafsir
/// repository they show the ayah and that no tafsir is downloaded.
final tafsirRoutes = FeatureRoutes(
  tabChildren: {
    ShellTab.study: [GoRoute(path: RoutePaths.studyTafsir, builder: _reader)],
  },
  sheets: [
    SheetRoute(
      path: RoutePaths.tafsirSheet,
      owner: (state) => Routes.mushafRead(Routes.addressOf(state)!),
      builder: _sheet,
    ),
  ],
);

Widget _reader(BuildContext context, GoRouterState state) {
  final quran = context.read<QuranTextRepository?>();
  // Without a text pack there is nothing to read: the screen shows its title
  // alone. The router has already sent an address that is not canonical home.
  if (quran == null) {
    return const TafsirReaderScreen(viewModel: null, onOfferDownload: null);
  }
  final address = Routes.addressOf(state)!;
  // Read here: a provider's create callback may not depend on the locale.
  final l10n = AppLocalizations.of(context);
  return ChangeNotifierProvider(
    create: (context) =>
        _viewModel(context, l10n, quran, address, withPicker: true),
    builder: (context, _) => TafsirReaderScreen(
      viewModel: context.read(),
      onOfferDownload: () => _offerDownload(context),
    ),
  );
}

Widget _sheet(BuildContext context, GoRouterState state) {
  final address = Routes.addressOf(state)!;
  final l10n = AppLocalizations.of(context);
  return SheetNeeds(
    available: (context) => context.read<QuranTextRepository?>() != null,
    child: ChangeNotifierProvider(
      create: (context) => _viewModel(
        context,
        l10n,
        context.read<QuranTextRepository>(),
        address,
      ),
      builder: (context, _) => TafsirSheet(
        viewModel: context.read(),
        onOfferDownload: () => _offerDownload(context),
        onOpenReader: () {
          final shown = context.read<TafsirViewModel>().address;
          context
            ..pop()
            ..go(Routes.studyTafsir(shown));
        },
      ),
    ),
  );
}

TafsirViewModel _viewModel(
  BuildContext context,
  AppLocalizations l10n,
  QuranTextRepository quran,
  QuranAddress address, {
  bool withPicker = false,
}) {
  final tafsirs = context.read<TafsirRepository?>();
  final clipboard = context.read<ClipboardService?>();
  return TafsirViewModel(
    address: address,
    quran: quran,
    tafsirs: tafsirs,
    catalogue: context.read<CatalogueRepository?>(),
    copyText: tafsirs == null
        ? null
        : TafsirCopyText(tafsirs: tafsirs, quran: quran, l10n: l10n),
    copyToClipboard: clipboard?.copyText,
    withPicker: withPicker,
  );
}

void _offerDownload(BuildContext context) =>
    unawaited(context.push<void>(Routes.firstUseTafsirSheet));
