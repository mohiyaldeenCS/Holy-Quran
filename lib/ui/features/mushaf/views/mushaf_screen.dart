import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_position.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/route_table.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/metrics/reader_screen_metrics.dart';
import 'package:holyquran/ui/core/reader/page_mark.dart';
import 'package:holyquran/ui/core/reader/position_bar_button.dart';
import 'package:holyquran/ui/core/shell_chrome.dart';
import 'package:holyquran/ui/core/widgets/ayah_toolbar.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/core/widgets/position_bar.dart';
import 'package:holyquran/ui/features/mushaf/view_models/mushaf_view_model.dart';
import 'package:holyquran/ui/features/mushaf/views/mushaf_scroll_view.dart';
import 'package:provider/provider.dart';

/// The reader in surah mode (`RD-02`), as the Screens and Mushaf boards draw
/// it: the position bar, the surahs as one scroll, and the reference page
/// number under them. While the base pack fails its check it shows the
/// integrity alert and no text (PRD §9.5).
///
/// The reader is active while its route is the current one, its tab is the
/// one shown and the app is in the foreground. It opens when it becomes
/// active and leaves, saving the reading position (`RD-12`), when it stops
/// being; an inactive reader neither loads nor saves. In distraction-free
/// mode (`RD-09`) it also hides the shell's tab bar.
class MushafScreen extends StatefulWidget {
  const MushafScreen({required this.viewModel, super.key});

  final MushafViewModel viewModel;

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  late final AppLifecycleListener _lifecycle;
  ShellChrome? _chrome;
  bool _shown = true;
  bool _foreground = true;
  bool _active = false;
  bool _tabBarHidden = false;

  MushafViewModel get _model => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    _model.addListener(_syncChrome);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chrome = context.read<ShellChrome?>();
    // A screen outside a navigator is shown.
    _shown =
        (ModalRoute.isCurrentOf(context) ?? true) &&
        TickerMode.valuesOf(context).enabled;
    _refreshAfterBuild();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _model.removeListener(_syncChrome);
    if (_active) unawaited(_model.leave());
    if (_tabBarHidden) _showTabBarAfterFrame(_chrome);
    super.dispose();
  }

  void _onLifecycle(AppLifecycleState state) {
    _foreground =
        state != AppLifecycleState.hidden &&
        state != AppLifecycleState.paused &&
        state != AppLifecycleState.detached;
    _refresh();
  }

  // The dependencies change while the tree is building, when a view model may
  // not notify.
  void _refreshAfterBuild() =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refresh();
      });

  void _refresh() {
    final active = _shown && _foreground;
    if (active == _active) return;
    setState(() => _active = active);
    if (active) {
      unawaited(_model.open.execute());
    } else {
      unawaited(_model.leave());
    }
    _syncChrome();
  }

  // The tab bar is the shell's; it is hidden only while this reader is shown
  // in distraction-free mode, and always given back.
  void _syncChrome() {
    final hide = _active && _model.distractionFree;
    if (hide == _tabBarHidden) return;
    _tabBarHidden = hide;
    _chrome?.tabBarVisible = !hide;
  }

  void _showTabBarAfterFrame(ShellChrome? chrome) => WidgetsBinding.instance
      .addPostFrameCallback((_) => chrome?.tabBarVisible = true);

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListenableBuilder(
      listenable: _model,
      builder: (context, _) => switch (_model.status) {
        ReaderStatus.loading => const SizedBox.expand(),
        ReaderStatus.unavailable => const _Unavailable(),
        ReaderStatus.ready => _Reader(viewModel: _model, active: _active),
      },
    ),
  );
}

class _Reader extends StatelessWidget {
  const _Reader({required this.viewModel, required this.active});

  final MushafViewModel viewModel;
  final bool active;

  Widget _positionBar(
    BuildContext context,
    GoRouter? router,
    PackText name,
    QuranPosition position,
  ) {
    final bar = PositionBar(
      surahName: name,
      juz: position.juz,
      hizb: position.hizb,
    );
    if (router == null || !hasRoute(router, Routes.goToSheet)) return bar;
    return PositionBarButton(
      label: AppLocalizations.of(context).goToTitle,
      onPressed: () => unawaited(context.push<Object?>(Routes.goToSheet)),
      child: bar,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = viewModel.positionSurahName;
    final position = viewModel.position;
    final chrome = !viewModel.distractionFree && position != null;
    final router = GoRouter.maybeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (chrome && name != null)
          Padding(
            padding: ReaderScreenMetrics.barPadding,
            // The bar opens «اذهب إلى» (D-140, 11) where that sheet has a
            // route.
            child: _positionBar(context, router, name, position),
          ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: MushafScrollView(viewModel: viewModel, active: active),
              ),
              if (viewModel.selectedAyah case final ayah?)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: ReaderScreenMetrics.toolbarPadding,
                    child: _Toolbar(viewModel: viewModel, ayah: ayah),
                  ),
                ),
            ],
          ),
        ),
        if (chrome)
          Padding(
            padding: ReaderScreenMetrics.footerPadding,
            child: PageMark(page: position.page),
          ),
      ],
    );
  }
}

/// The selected ayah's toolbar, with the tools that can work and have a
/// sheet to open.
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.viewModel, required this.ayah});

  final MushafViewModel viewModel;
  final QuranAddress ayah;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    VoidCallback? open(bool works, String location) =>
        works && router != null && hasRoute(router, location)
        ? () => unawaited(context.push<Object?>(location))
        : null;
    final bookmarks = viewModel.bookmarks;
    return ListenableBuilder(
      listenable: bookmarks,
      builder: (context, _) => AyahToolbar(
        onPlay: open(viewModel.tools.play, Routes.playOptionsSheet(ayah)),
        onBookmark: bookmarks.available
            ? () => unawaited(bookmarks.toggle(ayah))
            : null,
        bookmarked: bookmarks.has(ayah),
        onStudy: open(true, Routes.ayahSheet(ayah)),
        onCopy: open(viewModel.tools.copy, Routes.copySheet(ayah)),
        onShare: open(viewModel.tools.share, Routes.shareSheet(ayah)),
        onUndo: bookmarks.canUndoAt(ayah)
            ? () => unawaited(bookmarks.undo())
            : null,
        notice: bookmarks.failed
            ? AppLocalizations.of(context).userDataNotSaved
            : null,
      ),
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
