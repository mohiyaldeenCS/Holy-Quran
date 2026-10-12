import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/ui/features/home/views/home_screen.dart';

final homeRoutes = FeatureRoutes(
  tabRoot: TabRoot(ShellTab.home, (context, state) => const HomeScreen()),
);
