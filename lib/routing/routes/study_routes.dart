import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/ui/features/study/views/study_screen.dart';

final studyRoutes = FeatureRoutes(
  tabRoot: TabRoot(ShellTab.study, (context, state) => const StudyScreen()),
);
