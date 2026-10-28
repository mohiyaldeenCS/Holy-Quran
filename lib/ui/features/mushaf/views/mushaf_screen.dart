import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/metrics/reader_screen_metrics.dart';
import 'package:holyquran/ui/core/reader/page_mark.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/core/widgets/position_bar.dart';
import 'package:holyquran/ui/features/mushaf/view_models/mushaf_view_model.dart';
import 'package:holyquran/ui/features/mushaf/views/mushaf_scroll_view.dart';

/// The reader in surah mode (`RD-02`), as the Screens and Mushaf boards draw
/// it: the position bar, the surahs as one scroll, and the reference page
/// number under them. While the base pack fails its check it shows the
/// integrity alert and no text (PRD §9.5).
class MushafScreen extends StatefulWidget {
  const MushafScreen({required this.viewModel, super.key});

  final MushafViewModel viewModel;

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  MushafViewModel get _model => widget.viewModel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _model.open.execute();
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListenableBuilder(
      listenable: _model,
      builder: (context, _) => switch (_model.status) {
        ReaderStatus.loading => const SizedBox.expand(),
        ReaderStatus.unavailable => const _Unavailable(),
        ReaderStatus.ready => _Reader(viewModel: _model),
      },
    ),
  );
}

class _Reader extends StatelessWidget {
  const _Reader({required this.viewModel});

  final MushafViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final name = viewModel.positionSurahName;
    final position = viewModel.position;
    final chrome = !viewModel.distractionFree && position != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (chrome && name != null)
          Padding(
            padding: ReaderScreenMetrics.barPadding,
            child: PositionBar(
              surahName: name,
              juz: position.juz,
              hizb: position.hizb,
            ),
          ),
        Expanded(child: MushafScrollView(viewModel: viewModel, active: true)),
        if (chrome)
          Padding(
            padding: ReaderScreenMetrics.footerPadding,
            child: PageMark(page: position.page),
          ),
      ],
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: ReaderScreenMetrics.messagePadding,
        child: IntegrityAlert(
          title: l10n.integrityBaseTitle,
          body: l10n.integrityBaseBody,
        ),
      ),
    );
  }
}
