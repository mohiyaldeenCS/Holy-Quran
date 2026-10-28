import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/services/clipboard_service.dart';
import 'package:holyquran/data/services/share_service.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/routing/routes/sheet_needs.dart';
import 'package:holyquran/ui/core/share/ayah_copy_text.dart';
import 'package:holyquran/ui/core/share/copy_sheet_view.dart';
import 'package:holyquran/ui/core/share/copy_sheet_view_model.dart';
import 'package:holyquran/ui/core/share/share_card_sheet_view.dart';
import 'package:holyquran/ui/core/share/share_card_sheet_view_model.dart';
import 'package:provider/provider.dart';

/// The copy and share sheets of an ayah (SH-01, SH-02). The ayah toolbar
/// opens them once its icons exist (P1-23, P1-31).
final shareRoutes = FeatureRoutes(
  sheets: [
    SheetRoute(
      path: RoutePaths.copySheet,
      owner: _reader,
      builder: (context, state) {
        final address = Routes.addressOf(state)!;
        return SheetNeeds(
          available: (context) =>
              context.read<QuranTextRepository?>() != null &&
              context.read<ClipboardService?>() != null,
          child: CopySheetView(
            create: () => CopySheetViewModel(
              address: address,
              copyText: AyahCopyText(
                context.read<QuranTextRepository>(),
                AppLocalizations.of(context),
              ),
              copyToClipboard: context.read<ClipboardService>().copyText,
            ),
          ),
        );
      },
    ),
    SheetRoute(
      path: RoutePaths.shareSheet,
      owner: _reader,
      builder: (context, state) {
        final address = Routes.addressOf(state)!;
        return SheetNeeds(
          available: (context) =>
              context.read<QuranTextRepository?>() != null &&
              context.read<ShareService?>() != null,
          child: ShareCardSheetView(
            create: () => ShareCardSheetViewModel(
              address: address,
              repository: context.read<QuranTextRepository>(),
              shareImage: context.read<ShareService>().shareImage,
            ),
            onCopy: () => context.pushReplacement(Routes.copySheet(address)),
          ),
        );
      },
    ),
  ],
);

String _reader(GoRouterState state) =>
    Routes.mushafRead(Routes.addressOf(state)!);
