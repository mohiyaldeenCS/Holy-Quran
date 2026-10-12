import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/ui/features/mushaf/views/mushaf_screen.dart';

final mushafRoutes = FeatureRoutes(
  tabRoot: TabRoot(ShellTab.mushaf, (context, state) => const MushafScreen()),
);
