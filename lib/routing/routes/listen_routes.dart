import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/ui/features/listen/views/listen_screen.dart';

final listenRoutes = FeatureRoutes(
  tabRoot: TabRoot(ShellTab.listen, (context, state) => const ListenScreen()),
);
