import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/ui/features/report/view_models/report_view_model.dart';
import 'package:holyquran/ui/features/report/views/report_sheet.dart';
import 'package:provider/provider.dart';

final reportRoutes = FeatureRoutes(
  sheets: [
    SheetRoute(
      path: RoutePaths.reportSheet,
      builder: (context, state) => ChangeNotifierProvider(
        create: (context) => ReportViewModel(
          address: Routes.addressOf(state)!,
          packId: Routes.packOf(state),
          index: context.read<QuranIndexRepository?>(),
          packs: context.read<PackInstallRepository?>(),
        ),
        child: const ReportSheet(),
      ),
      owner: (state) => Routes.mushafRead(Routes.addressOf(state)!),
    ),
  ],
);
