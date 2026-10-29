import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/route_table.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/metrics/reader_screen_metrics.dart';
import 'package:holyquran/ui/core/reader/block_layout.dart';
import 'package:holyquran/ui/core/reader/block_margin.dart';
import 'package:holyquran/ui/core/reader/gesture_target.dart';
import 'package:holyquran/ui/core/reader/interactive_surah_sliver.dart';
import 'package:holyquran/ui/core/reader/reader_highlights.dart';
import 'package:holyquran/ui/core/reader/reader_pinch_stepper.dart';
import 'package:holyquran/ui/core/reader/reader_text_scale.dart';
import 'package:holyquran/ui/core/reader/surah_layout.dart';
import 'package:holyquran/ui/core/reader/target_gestures.dart';
import 'package:holyquran/ui/core/theme/motion.dart';
import 'package:holyquran/ui/core/widgets/surah_header.dart';
import 'package:holyquran/ui/features/mushaf/view_models/mushaf_view_model.dart';
import 'package:holyquran/ui/features/mushaf/view_models/reader_surah.dart';
import 'package:holyquran/ui/features/mushaf/view_models/recitation_follow.dart';
import 'package:holyquran/ui/features/mushaf/views/surah_info_text.dart';

/// The surahs of [viewModel] as one continuous vertical scroll (`RD-11`),
/// each a header and its text. It scrolls to the view model's anchor when its
/// text is first laid out, keeps the first visible ayah in place when the
/// layout changes (rotation, text scale), tells the view model which ayah is
/// first visible, saves it when a scroll ends (`RD-12`), and asks for the
/// next surah before the reader reaches the end. While not [active] it
/// neither tracks, saves nor loads. Every scroll it did not make itself
/// counts as the user's, a screen reader's included; the scrolls it makes to
/// follow the recitation move the reading position like any other.
///
/// Its gestures are the reader's (PRD §7.4): a tap or long press reaches the
/// view model, which selects an ayah or toggles the interface; a pinch steps
/// the text size (`RD-07`) and keeps the ayah under the fingers in place; the
/// margins show the marks and the ribbons of bookmarks.
///
/// It also follows the recitation (`SY-03`): when the view model asks, it
/// brings the ayah being recited into view, unless that ayah is already in
/// view, and a scroll of the user's stops the following. A recitation in a
/// surah the reader does not show next to its own reopens the reader there.
/// The scroll animates unless the platform asks for less motion.
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
  static const _maxSteps = ReaderScreenMetrics.followSteps;

  final _controller = ScrollController();
  final _headerKeys = <int, GlobalKey>{};
  final _textKeys = <int, GlobalKey>{};
  final _layouts = <int, SurahLayout>{};
  late List<ReaderSurah> _surahs;
  QuranAddress? _handledAnchor;
  QuranAddress? _pendingAnchor;
  bool _jumping = false;

  // The asks to follow the recitation: the last one met, the one waiting for
  // its surah, and the scrolls this view is making itself, which are not the
  // user's.
  FollowRequest? _handledFollow;
  FollowRequest? _pendingFollow;
  bool _followScheduled = false;
  int _followScrolls = 0;
  int _followSteps = 0;

  // The plan of the surah under the middle of the screen, which a pinch
  // anchors in, and whether a step is waiting for its new plans.
  final _focus = _FocusLayout();
  int? _focusSurah;
  bool _stepping = false;

  // Whether the stepper holds an ayah to keep in place for the step in flight.
  bool _anchored = false;

  // Whether the text is scrolling. The scroll view ignores a touch that stops
  // a fling, so a tap that does must not reach the layer around it either.
  final _moving = ValueNotifier<bool>(false);

  MushafViewModel get _model => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _surahs = _model.surahs;
    _takeAnchor();
    _handledFollow = _model.follow.request;
    _model.addListener(_onModel);
  }

  @override
  void dispose() {
    _model.removeListener(_onModel);
    _focus.dispose();
    _moving.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MushafScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active && _pendingFollow != null) {
      _scheduleFollow();
    }
  }

  void _takeAnchor() {
    if (identical(_model.anchor, _handledAnchor)) return;
    _handledAnchor = _pendingAnchor = _model.anchor;
  }

  void _onModel() {
    final request = _model.follow.request;
    if (!identical(request, _handledFollow)) {
      _handledFollow = _pendingFollow = request;
      _followSteps = 0;
      _scheduleFollow();
    }
    if (identical(_model.surahs, _surahs)) return;
    setState(() {
      _surahs = _model.surahs;
      _takeAnchor();
    });
    if (_pendingAnchor != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _retryAnchor());
    }
    if (_pendingFollow != null) _scheduleFollow();
  }

  void _scheduleFollow() {
    if (_followScheduled) return;
    _followScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _followScheduled = false;
      _follow();
    });
  }

  // Brings the ayah asked for into view. Its surah may not be laid out yet,
  // or not appended yet: the ask waits for the layout and for the surah after
  // the last one shown, which it asks for; it is dropped when its surah can
  // not be shown without a gap.
  void _follow() {
    final request = _pendingFollow;
    // A scroll in flight looks again when it ends.
    if (!mounted || request == null || _followScrolls > 0) return;
    // A reader that is not shown neither scrolls nor loads; the ask waits.
    if (!widget.active) return;
    final address = request.address;
    final shown = _surahs.where((s) => s.info.number == address.surah);
    if (shown.isEmpty) {
      if (!_model.canShow(address)) {
        _pendingFollow = null;
      } else if (_surahs.isNotEmpty &&
          address.surah == _surahs.last.info.number + 1) {
        unawaited(_model.loadNext.execute());
      } else {
        // A surah apart from the ones shown: the reader opens at it, and the
        // anchor brings the ayah into view.
        unawaited(_model.showAt(address));
      }
      return;
    }
    final layout = _layouts[address.surah];
    final sliver = _sliverOf(_textKeys, address.surah);
    if (layout == null ||
        sliver == null ||
        !identical(layout.text, shown.first.text) ||
        !_controller.hasClients) {
      return;
    }
    if (address.riwaya != layout.text.riwaya ||
        address.ayah > layout.text.ayat.length) {
      _pendingFollow = null;
      return;
    }
    final position = _controller.position;
    final start = sliver.constraints.precedingScrollExtent;
    final first = address.ayah == 1;
    final top = first
        ? _startOf(address.surah)
        : start + layout.offsetOf(address);
    final bottom =
        start +
        layout.basmalaExtent +
        (layout.lineOfAyahEnd(address.ayah) + 1) * layout.lineHeight;
    if (top >= position.pixels &&
        bottom <= position.pixels + position.viewportDimension) {
      _pendingFollow = null;
      return;
    }
    final target = first
        ? top
        : top - position.viewportDimension * ReaderScreenMetrics.followLead;
    final offset = target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    // The scroll's extent can fall short of the ayah until the blocks above
    // it are laid out, and at the end of the surahs shown until the next is
    // appended, so the ask is kept and looked at again after each scroll,
    // until the ayah is in view, the scroll stops moving or it has taken too
    // many steps.
    if (offset == position.pixels || _followSteps++ >= _maxSteps) {
      _pendingFollow = null;
      return;
    }
    _scrollTo(offset);
  }

  void _scrollTo(double offset) {
    final position = _controller.position;
    _followScrolls++;
    if (MediaQuery.disableAnimationsOf(context)) {
      position.jumpTo(offset);
      _followScrolls--;
      if (_pendingFollow != null) _scheduleFollow();
    } else {
      unawaited(
        position
            .animateTo(offset, duration: motionNormal, curve: motionCurve)
            .whenComplete(() {
              _followScrolls--;
              if (mounted && _pendingFollow != null) _scheduleFollow();
            }),
      );
    }
  }

  // An anchor near the end of the surah is out of reach until the next surah
  // gives the scroll more extent.
  void _retryAnchor() {
    final anchor = _pendingAnchor;
    if (!mounted || anchor == null) return;
    final layout = _layouts[anchor.surah];
    final current = _surahs.where((s) => s.info.number == anchor.surah);
    if (layout == null ||
        current.isEmpty ||
        !identical(layout.text, current.first.text)) {
      return;
    }
    if (_jumpTo(anchor, layout)) _pendingAnchor = null;
  }

  void _onLayout(SurahLayout layout) {
    _layouts[layout.text.surah] = layout;
    if (_pendingFollow != null) _scheduleFollow();
    if (_focusSurah == null || layout.text.surah == _focusSurah) {
      _focusSurah = layout.text.surah;
      // A step's new plans are anchored by the pinch stepper, to the ayah
      // under the fingers; any other change of plan is kept in place here.
      if (_stepping) {
        _focus.publish(layout);
        _stepping = false;
        if (_anchored) {
          _loadNextIfNear();
          return;
        }
      } else {
        _focus.keep(layout);
      }
    } else if (_stepping && _anchored) {
      // The surahs above the focus change height with the step too, and a
      // jump to keep the first visible line would move the scroll under the
      // stepper. Without an anchor (fingers on a header or a basmala below
      // the top surah) the first visible line is what is kept.
      _loadNextIfNear();
      return;
    }
    final pending = _pendingAnchor;
    final target = pending ?? _model.position?.address;
    if (target != null && target.surah == layout.text.surah) {
      if (_jumpTo(target, layout) && pending != null) _pendingAnchor = null;
    }
    _loadNextIfNear();
  }

  /// Whether the scroll reached [address]; false when the surahs shown end
  /// before it can be at the top.
  bool _jumpTo(QuranAddress address, SurahLayout layout) {
    final text = _sliverOf(_textKeys, address.surah);
    if (text == null || !_controller.hasClients) return false;
    final position = _controller.position;
    final offset = address.ayah == 1
        ? _startOf(address.surah)
        : text.constraints.precedingScrollExtent + layout.offsetOf(address);
    _jumping = true;
    position.jumpTo(
      offset.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
    _jumping = false;
    return offset <= position.maxScrollExtent;
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
    if (notification.depth == 0) {
      if (notification is ScrollStartNotification) _moving.value = true;
      if (notification is ScrollEndNotification) _moving.value = false;
    }
    if (!widget.active || _jumping || notification.depth != 0) return false;
    // A stand follows whatever the user does, so a drag leaves its ask be.
    if (_byUser(notification) && !_model.standMode) {
      _pendingFollow = null;
      _model.follow.userScrolled();
    }
    if (notification is ScrollStartNotification) _pendingAnchor = null;
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      _trackFirstVisible(notification.metrics.pixels);
      _trackFocus(notification.metrics);
    }
    if (notification is ScrollEndNotification) {
      unawaited(_model.saveFirstVisible());
    }
    _loadNextIfNear(notification.metrics);
    return false;
  }

  // A drag is the user's even when it interrupts a scroll of this view's
  // own; any other movement is the user's unless this view is making it.
  bool _byUser(ScrollNotification notification) {
    final own = _followScrolls > 0;
    return switch (notification) {
      ScrollStartNotification(:final dragDetails) =>
        dragDetails != null || !own,
      ScrollUpdateNotification(:final dragDetails) =>
        dragDetails != null || !own,
      _ => false,
    };
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

  void _trackFocus(ScrollMetrics metrics) => _focusAt(
    metrics.pixels + metrics.viewportDimension * ReaderScreenMetrics.pinchFocus,
  );

  /// Takes the surah whose text, or whose header above it, holds the scroll
  /// position [y] as the one a pinch anchors in.
  void _focusAt(double y) {
    for (final surah in _surahs) {
      final number = surah.info.number;
      final sliver = _sliverOf(_textKeys, number);
      if (sliver == null) return;
      final start = sliver.constraints.precedingScrollExtent;
      if (y >= start + sliver.geometry!.scrollExtent) continue;
      final layout = _layouts[number];
      if (layout != null && identical(layout.text, surah.text)) {
        _focusSurah = number;
        _focus.keep(layout);
      }
      return;
    }
  }

  double _focusLeading() {
    final surah = _focusSurah;
    if (surah == null) return 0;
    return _sliverOf(_textKeys, surah)?.constraints.precedingScrollExtent ?? 0;
  }

  void _onStep(int step) {
    _stepping = true;
    _model.setTextStep(step);
  }

  void _tapped(GestureTarget target) {
    final router = GoRouter.maybeOf(context);
    final word = _model.tap(
      target,
      wordSheet:
          router != null &&
          target is WordTarget &&
          hasRoute(router, Routes.wordSheet(target.word)),
    );
    if (word != null) unawaited(context.push<Object?>(Routes.wordSheet(word)));
  }

  Widget _margin(BuildContext context, BlockLayout layout) =>
      ValueListenableBuilder(
        valueListenable: _model.bookmarks.ribbons,
        builder: (context, ribbons, _) =>
            BlockMargin(layout: layout, bookmarks: ribbons),
      );

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
    final step = readerTextSteps[_model.textStep];
    final highlights = ReaderHighlights(
      selectedAyah: _model.selectedAyah,
      recitedAyah: _model.follow.recited,
    );
    return ReaderPinchStepper(
      scrollController: _controller,
      layout: _focus,
      step: _model.textStep,
      onStep: _onStep,
      leadingExtent: _focusLeading,
      focusAt: _focusAt,
      onAnchor: (anchored) => _anchored = anchored,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: _onMetrics,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          // The text column's sides and what lies between blocks belong to no
          // block; a tap there is a tap on the margin (PRD §7.4). A long hold
          // is not a tap, and neither is the touch that stops a fling.
          child: ValueListenableBuilder<bool>(
            valueListenable: _moving,
            builder: (context, moving, child) => TargetGestures(
              targetAt: (_) => const MarginTarget(),
              onTap: moving ? null : _tapped,
              onLongPress: _model.longPress,
              child: child!,
            ),
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
                    sliver: InteractiveSurahSliver(
                      key: _keyOf(_textKeys, surah.info.number),
                      text: surah.text,
                      step: step,
                      onLayout: _onLayout,
                      highlights: highlights,
                      onTap: _tapped,
                      onLongPress: _model.longPress,
                      blockOverlayBuilder: _margin,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The plan of the surah in focus for [ReaderPinchStepper], which restores
/// the scroll offset whenever the plan is announced. [keep] stores a plan
/// without announcing it; [publish] announces it.
final class _FocusLayout extends ChangeNotifier
    implements ValueListenable<SurahLayout?> {
  @override
  SurahLayout? value;

  void keep(SurahLayout layout) => value = layout;

  void publish(SurahLayout layout) {
    value = layout;
    notifyListeners();
  }
}
