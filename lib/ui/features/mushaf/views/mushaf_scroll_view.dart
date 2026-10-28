import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/metrics/reader_screen_metrics.dart';
import 'package:holyquran/ui/core/reader/surah_layout.dart';
import 'package:holyquran/ui/core/reader/surah_sliver.dart';
import 'package:holyquran/ui/core/widgets/surah_header.dart';
import 'package:holyquran/ui/features/mushaf/view_models/mushaf_view_model.dart';
import 'package:holyquran/ui/features/mushaf/view_models/reader_surah.dart';
import 'package:holyquran/ui/features/mushaf/views/surah_info_text.dart';

/// The surahs of [viewModel] as one continuous vertical scroll (`RD-11`),
/// each a header and its text. It scrolls to the view model's anchor when its
/// text is first laid out, keeps the first visible ayah in place when the
/// layout changes (rotation, text scale), tells the view model which ayah is
/// first visible, saves it when a scroll ends (`RD-12`), and asks for the
/// next surah before the reader reaches the end. While not [active] it
/// neither tracks, saves nor loads. Every scroll it did not make itself
/// counts as the user's, a screen reader's included.
final class MushafScrollView extends StatefulWidget {
  const MushafScrollView({
    required this.viewModel,
    required this.active,
    super.key,
  });

  final MushafViewModel viewModel;
  final bool active;

  @override
  State<MushafScrollView> createState() => _MushafScrollViewState();
}

final class _MushafScrollViewState extends State<MushafScrollView> {
  final _controller = ScrollController();
  final _headerKeys = <int, GlobalKey>{};
  final _textKeys = <int, GlobalKey>{};
  final _layouts = <int, SurahLayout>{};
  late List<ReaderSurah> _surahs;
  QuranAddress? _handledAnchor;
  QuranAddress? _pendingAnchor;
  bool _jumping = false;

  MushafViewModel get _model => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _surahs = _model.surahs;
    _takeAnchor();
    _model.addListener(_onModel);
  }

  @override
  void dispose() {
    _model.removeListener(_onModel);
    _controller.dispose();
    super.dispose();
  }

  void _takeAnchor() {
    if (identical(_model.anchor, _handledAnchor)) return;
    _handledAnchor = _pendingAnchor = _model.anchor;
  }

  void _onModel() {
    if (identical(_model.surahs, _surahs)) return;
    setState(() {
      _surahs = _model.surahs;
      _takeAnchor();
    });
  }

  void _onLayout(SurahLayout layout) {
    _layouts[layout.text.surah] = layout;
    final target = _pendingAnchor ?? _model.position?.address;
    if (target != null && target.surah == layout.text.surah) {
      _pendingAnchor = null;
      _jumpTo(target, layout);
    }
    _loadNextIfNear();
  }

  void _jumpTo(QuranAddress address, SurahLayout layout) {
    final text = _sliverOf(_textKeys, address.surah);
    if (text == null || !_controller.hasClients) return;
    final position = _controller.position;
    final offset = address.ayah == 1
        ? _startOf(address.surah)
        : text.constraints.precedingScrollExtent + layout.offsetOf(address);
    _jumping = true;
    position.jumpTo(
      offset.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
    _jumping = false;
  }

  /// Where a surah begins: the very top for the first one shown, else the top
  /// of its header, so that the first ayah is reached with its header and
  /// basmala above it.
  double _startOf(int surah) => surah == _surahs.first.info.number
      ? 0
      : _sliverOf(_headerKeys, surah)?.constraints.precedingScrollExtent ?? 0;

  RenderSliver? _sliverOf(Map<int, GlobalKey> keys, int surah) {
    final object = keys[surah]?.currentContext?.findRenderObject();
    return object is RenderSliver && object.geometry != null ? object : null;
  }

  bool _onScroll(ScrollNotification notification) {
    if (!widget.active || _jumping || notification.depth != 0) return false;
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      _trackFirstVisible(notification.metrics.pixels);
    }
    if (notification is ScrollEndNotification) {
      unawaited(_model.saveFirstVisible());
    }
    _loadNextIfNear(notification.metrics);
    return false;
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    if (widget.active && notification.depth == 0) {
      _loadNextIfNear(notification.metrics);
    }
    return false;
  }

  // From the pixels the scroll is at now, not from the slivers' constraints,
  // which still hold the frame before.
  void _trackFirstVisible(double pixels) {
    for (final surah in _surahs) {
      final number = surah.info.number;
      final sliver = _sliverOf(_textKeys, number);
      if (sliver == null) return;
      final start = sliver.constraints.precedingScrollExtent;
      if (pixels >= start + sliver.geometry!.scrollExtent) continue;
      final layout = _layouts[number];
      if (layout != null && identical(layout.text, surah.text)) {
        _model.showFirstVisible(layout.ayahAt(pixels - start), byUser: true);
      }
      return;
    }
  }

  void _loadNextIfNear([ScrollMetrics? metrics]) {
    if (!widget.active) return;
    final reading =
        metrics ?? (_controller.hasClients ? _controller.position : null);
    if (reading == null || !reading.hasContentDimensions) return;
    if (reading.extentAfter <
        ReaderScreenMetrics.preloadViewports * reading.viewportDimension) {
      _model.loadNext.execute();
    }
  }

  GlobalKey _keyOf(Map<int, GlobalKey> keys, int surah) =>
      keys.putIfAbsent(surah, GlobalKey.new);

  // The whole header opens «مقدمة السورة» when there are facts to show.
  Widget _header(BuildContext context, ReaderSurah surah) {
    final info = surahInfoText(AppLocalizations.of(context), surah.info);
    return SurahHeader(
      name: surah.info.name,
      info: info,
      onInfoPressed: info == null
          ? null
          : () => unawaited(
              context.push<Object?>(Routes.surahInfoSheet(surah.info.number)),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _onMetrics,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: CustomScrollView(
          controller: _controller,
          slivers: [
            const SliverToBoxAdapter(
              child: SizedBox(height: ReaderScreenMetrics.columnTop),
            ),
            for (final surah in _surahs) ...[
              SliverPadding(
                key: _keyOf(_headerKeys, surah.info.number),
                padding: ReaderScreenMetrics.blockPadding,
                sliver: SliverToBoxAdapter(child: _header(context, surah)),
              ),
              SliverPadding(
                padding: ReaderScreenMetrics.blockPadding,
                sliver: SurahSliver(
                  key: _keyOf(_textKeys, surah.info.number),
                  text: surah.text,
                  onLayout: _onLayout,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
