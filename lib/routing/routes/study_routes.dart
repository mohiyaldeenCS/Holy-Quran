import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/ui/features/study/views/study_screen.dart';
import 'package:provider/provider.dart';

/// The study tab's hub: its entries open the search and the tafsir reader.
const studyRoutes = FeatureRoutes(tabRoot: TabRoot(ShellTab.study, _study));

Widget _study(BuildContext context, GoRouterState state) {
  final text = context.read<QuranTextRepository?>();
  final last = context.read<ReadingPositionRepository?>()?.last;
  // The tafsir reader opens at the last ayah read, or at the first ayah of the
  // text; without a text pack there is nothing to open it at.
  final tafsirAddress =
      last ?? (text == null ? null : QuranAddress(text.riwaya, 1, 1));
  return StudyScreen(tafsirAddress: tafsirAddress);
}
