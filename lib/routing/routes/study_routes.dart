import 'package:flutter/widgets.dart';

import 'package:holyquran/config/base_pack.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/ui/core/base_pack_problem.dart';
import 'package:holyquran/ui/features/study/views/study_screen.dart';
import 'package:provider/provider.dart';

/// The study tab's hub: its entries open the search and the tafsir reader.
final studyRoutes = studyRoutesFor(basePackInUse);

/// The study routes over [basePack], the pack this build reads; a parameter
/// so a test can give it the test copy's pack, as `homeRoutesFor` does.
FeatureRoutes studyRoutesFor(({String id, int version})? basePack) =>
    FeatureRoutes(
      tabRoot: TabRoot(
        ShellTab.study,
        (context, state) => _study(context, basePack?.id),
      ),
    );

Widget _study(BuildContext context, String? basePackId) {
  final text = context.read<QuranTextRepository?>();
  final last = context.read<ReadingPositionRepository?>()?.last;
  // The tafsir reader opens at the last ayah read, or at the first ayah of the
  // text. Without a text pack there is nothing to open it at, and the reader
  // says why when the base pack serves none (D-180).
  final address =
      last ?? (text == null ? null : QuranAddress(text.riwaya, 1, 1));
  final problem = basePackProblem(
    context.read<PackIntegrityRepository?>(),
    basePackId,
  );
  final tafsirLocation = address != null
      ? Routes.studyTafsir(address)
      : (problem != null ? Routes.studyTafsirAlert : null);
  return StudyScreen(tafsirLocation: tafsirLocation);
}
