import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/motion.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

import '../s1/render/spike_surah_text.dart';
import '../s1/render/surah_list_v1.dart';
import '../s1/render/surah_text_block.dart';
import '../s1/s1_screen.dart' show describeError;
import 'ayah_toolbar_stand_in.dart';
import 'gesture_log.dart';
import 'gesture_target.dart';
import 'reader_gestures.dart';
import 's7_debug_panel.dart';
import 's7_record.dart';
import 'synthetic_pages.dart';
import 'tap_resolver.dart';
import 'target_geometry.dart';
import 'target_practice.dart';
import 'text_size_ladder.dart';
import 'waqf_card_stand_in.dart';

// The S7 session: every surah-mode row of PRD §7.4 on the S1 V1 reader and
// the page-mode rows on synthetic pages (D-095). Quran text reaches the
// screen only through the reader, SurahName and the stand-ins; the debug
// chrome and the log hold numbers, enum names and addresses only (D-072).

/// The tap rule a session starts with: a tap well inside a word is that
/// word, and markers and marks get zones of `target-min` (AX-02) before the
/// nearest target on the line is taken (D-095, pending the device run).
const TapRule s7DefaultTapRule = TapRule.priorityZonesWithSlop;

/// The pages of the reference mushaf (RD-03).
const int s7PageCount = 604;

/// The interface levels of PRD §7.4's word-tap row.
enum S7Level { simple, medium, study }

enum S7Mode { surah, page }

/// What a gesture leads to in the session.
enum S7Action {
  toggleChrome,
  selectAyah,

  /// The word sheet at medium and study (LX-11). It needs the word as its
  /// own pack text, a slice of the stored ayah that is not allowed yet
  /// (D-062, M1.6), so the session only logs the tap.
  openWordSheet,
  openWaqfCard,
  closeToolbar,
  none,
}

/// A surah to read and its name, both from the pack.
typedef S7Surah = ({SpikeSurahText text, PackText name});

/// PRD §7.4 as S7 builds it. A marker tap opens the same toolbar as a long
/// press (M0.4-4); while the toolbar is open, any other tap only closes it.
S7Action actionFor(
  GestureTarget target, {
  required bool longPress,
  required S7Level level,
  required bool toolbarOpen,
}) {
  if (longPress) {
    return target is MarginTarget ? S7Action.none : S7Action.selectAyah;
  }
  if (toolbarOpen) {
    return target is MarkerTarget ? S7Action.selectAyah : S7Action.closeToolbar;
  }
  return switch (target) {
    WordTarget() when level == S7Level.simple => S7Action.toggleChrome,
    WordTarget() => S7Action.openWordSheet,
    MarginTarget() => S7Action.toggleChrome,
    MarkerTarget() => S7Action.selectAyah,
    WaqfMarkTarget() => S7Action.openWaqfCard,
  };
}

typedef LoggedHit = ({LoggedTarget target, QuranAddress? address, int? mark});

LoggedHit loggedHitOf(GestureTarget target) => switch (target) {
  WordTarget(:final word) => (
    target: LoggedTarget.word,
    address: word,
    mark: null,
  ),
  WaqfMarkTarget(:final ayah, :final mark) => (
    target: LoggedTarget.waqfMark,
    address: ayah,
    mark: mark,
  ),
  MarkerTarget(:final ayah) => (
    target: LoggedTarget.marker,
    address: ayah,
    mark: null,
  ),
  MarginTarget() => (target: LoggedTarget.margin, address: null, mark: null),
};

QuranAddress? _ayahOf(GestureTarget target) => switch (target) {
  WordTarget(:final word) => word.ayahAddress,
  WaqfMarkTarget(:final ayah) || MarkerTarget(:final ayah) => ayah,
  MarginTarget() => null,
};

/// The app's Arabic localizations and right-to-left direction under the
/// spike's English, left-to-right UI, as S1 gives its text widgets.
Widget s7Arabic(BuildContext context, Widget child) => Localizations.override(
  context: context,
  locale: const Locale('ar'),
  delegates: AppLocalizations.localizationsDelegates,
  child: child,
);

/// The gesture test on one [surah], or on synthetic pages only when it is
/// null. Every gesture goes to [record]; the debug panel exports it into
/// the folder [storage] gives.
final class S7Session extends StatefulWidget {
  const S7Session({
    required this.surah,
    required this.record,
    required this.storage,
    this.random,
    this.initialRule = s7DefaultTapRule,
    super.key,
  });

  final S7Surah? surah;
  final S7Record record;
  final Future<Directory> Function() storage;
  final Random? random;
  final TapRule initialRule;

  @override
  State<S7Session> createState() => _S7SessionState();
}

final class _S7SessionState extends State<S7Session> {
  final _scaffold = GlobalKey<ScaffoldState>();
  final _blockKey = GlobalKey();
  final _viewportKey = GlobalKey();
  final _chromeKey = GlobalKey();
  final _controller = ScrollController();
  late final Random _random = widget.random ?? Random();
  late S7Mode _mode = widget.surah == null ? S7Mode.page : S7Mode.surah;
  late TapRule _rule = widget.initialRule;
  S7Level _level = S7Level.simple;
  double _step = 1;
  bool _stepChosen = false;
  double _chromeHeight = 0;
  double _viewportHeight = 0;
  double _systemScale = 1;
  bool _chromeShown = true;
  QuranAddress? _selected;
  (QuranAddress, int)? _waqf;
  bool _practising = false;
  PracticeTarget? _practice;
  Offset _lastPointer = Offset.zero;
  String? _exportStatus;

  GestureLog get _log => widget.record.log;

  RenderSurahTextBlock? get _block {
    final block = _blockKey.currentContext?.findRenderObject();
    return block is RenderSurahTextBlock && block.hasSize ? block : null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = AppTextStyles.quranPage.fontSize!;
    _systemScale = MediaQuery.textScalerOf(context).scale(size) / size;
    if (!_stepChosen) {
      _step = stepAfterPinch(_systemScale, 1);
      _stepChosen = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset? _blockPoint() => _block?.globalToLocal(_lastPointer);

  void _onTap(GestureTarget target) {
    final hit = loggedHitOf(target);
    final expected = _practising ? _practice : null;
    _log.record(
      gesture: LoggedGesture.tap,
      target: hit.target,
      address: hit.address,
      mark: hit.mark,
      rule: _rule.name,
      textSize: _step,
      point: _blockPoint(),
      expectedTarget: expected?.kind,
      expectedAddress: expected?.address,
      expectedMark: expected?.mark,
    );
    if (_practising) {
      setState(_pickTarget);
      return;
    }
    _act(target, longPress: false);
  }

  void _onLongPress(GestureTarget target) {
    final hit = loggedHitOf(target);
    _log.record(
      gesture: LoggedGesture.longPress,
      target: hit.target,
      address: hit.address,
      mark: hit.mark,
      rule: _rule.name,
      textSize: _step,
      point: _blockPoint(),
    );
    if (!_practising) _act(target, longPress: true);
  }

  void _act(GestureTarget target, {required bool longPress}) {
    final action = actionFor(
      target,
      longPress: longPress,
      level: _level,
      toolbarOpen: _selected != null,
    );
    setState(() {
      switch (action) {
        case S7Action.toggleChrome:
          _chromeShown = !_chromeShown;
        case S7Action.selectAyah:
          _selected = _ayahOf(target);
        case S7Action.openWaqfCard:
          final mark = target as WaqfMarkTarget;
          _waqf = (mark.ayah, mark.mark);
        case S7Action.closeToolbar:
          _selected = null;
        // Logged only: see S7Action.openWordSheet.
        case S7Action.openWordSheet || S7Action.none:
      }
    });
  }

  void _pinchEnd(double scale, Offset focal) {
    final block = _block;
    final step = _step;
    if (block == null) return;
    final local = block.globalToLocal(focal);
    final anchor = focalAyahAt(block.paragraph, local);
    final next = stepAfterPinch(step, scale);
    _log.record(
      gesture: LoggedGesture.textPinch,
      address: anchor?.ayah,
      scale: scale,
      textSize: next,
      point: local,
    );
    if (next == step) return;
    setState(() => _step = next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final block = _block;
      if (anchor != null && block != null && _controller.hasClients) {
        final y = yOfFocalAyah(block.paragraph, anchor);
        if (y != null) {
          final top = block.localToGlobal(Offset.zero).dy;
          final position = _controller.position;
          _controller.jumpTo(
            (position.pixels + top + y - focal.dy).clamp(
              position.minScrollExtent,
              position.maxScrollExtent,
            ),
          );
        }
      }
      if (_practising) setState(_pickTarget);
    });
  }

  void _onPage(PageGesture gesture) {
    switch (gesture) {
      case PageTap(:final page, :final line, :final point):
        _log.record(
          gesture: LoggedGesture.tap,
          target: line == null ? LoggedTarget.margin : LoggedTarget.pageLine,
          page: page + 1,
          line: line,
          point: point,
        );
        setState(() => _chromeShown = !_chromeShown);
      case PageTurn(:final page, :final to, :final zoom):
        _log.record(
          gesture: LoggedGesture.pageTurn,
          page: page + 1,
          toPage: to + 1,
          scale: zoom,
        );
      case PageTurnCancelled(:final page, :final zoom):
        _log.record(
          gesture: LoggedGesture.pageTurnCancelled,
          page: page + 1,
          scale: zoom,
        );
      case PageZoom(:final page, :final zoom):
        _log.record(
          gesture: LoggedGesture.pageZoom,
          page: page + 1,
          scale: zoom,
        );
    }
  }

  /// Picks the next practice target among those wholly in the viewport.
  void _pickTarget() {
    final block = _block;
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (block == null || viewport is! RenderBox || !viewport.hasSize) {
      _practice = null;
      return;
    }
    final visible = Rect.fromPoints(
      block.globalToLocal(viewport.localToGlobal(Offset.zero)),
      block.globalToLocal(
        viewport.localToGlobal(viewport.size.bottomRight(Offset.zero)),
      ),
    );
    _practice = pickPracticeTarget(
      TargetGeometry.of(block.paragraph, within: visible),
      visible,
      _random,
    );
  }

  void _pickTargetAfterFrame() =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _practising) setState(_pickTarget);
      });

  void _setPractising(bool on) {
    _scaffold.currentState?.closeEndDrawer();
    setState(() {
      _practising = on;
      _practice = null;
      _selected = _waqf = null;
    });
    if (on) _pickTargetAfterFrame();
  }

  void _setMode(S7Mode mode) => setState(() {
    _mode = mode;
    _practising = false;
    _practice = null;
    _selected = _waqf = null;
  });

  Future<void> _export() async {
    String status;
    try {
      final file = await exportS7Record(await widget.storage(), widget.record);
      status = 'Saved ${file.path}';
    } on Object catch (e) {
      status = describeError(e);
    }
    if (mounted) setState(() => _exportStatus = status);
  }

  /// Keeps the reader's top inset at the chrome's height, so the chrome
  /// covers no text at the top and showing it moves nothing.
  void _measureChrome(Duration _) {
    final bar = _chromeKey.currentContext?.findRenderObject();
    if (!mounted || bar is! RenderBox || !bar.hasSize) return;
    if (bar.size.height != _chromeHeight) {
      setState(() => _chromeHeight = bar.size.height);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_measureChrome);
    return _body(context);
  }

  Widget _body(BuildContext context) => Scaffold(
    key: _scaffold,
    endDrawerEnableOpenDragGesture: false,
    endDrawer: Drawer(
      child: S7DebugPanel(
        mode: _mode,
        onMode: _setMode,
        surahAvailable: widget.surah != null,
        level: _level,
        onLevel: (level) => setState(() => _level = level),
        rule: _rule,
        defaultRule: s7DefaultTapRule,
        onRule: (rule) => setState(() => _rule = rule),
        step: _step,
        systemScale: _systemScale,
        practising: _practising,
        onPractice: _setPractising,
        record: widget.record,
        onExport: _export,
        exportStatus: _exportStatus,
      ),
    ),
    body: s7Arabic(
      context,
      Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          _lastPointer = event.position;
          _log.pointerDown();
        },
        onPointerMove: (event) => _lastPointer = event.position,
        onPointerUp: (event) {
          _lastPointer = event.position;
          _log.pointerUp();
        },
        onPointerCancel: (_) => _log.pointerUp(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_practising)
              _PracticeBar(
                target: _practice,
                record: widget.record,
                onNewTarget: () => setState(_pickTarget),
                onStop: () => _setPractising(false),
              ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  switch (_mode) {
                    S7Mode.surah => _surahReader(widget.surah!),
                    S7Mode.page => Builder(
                      builder: (context) {
                        _log.setContext(gestureLogContextOf(context));
                        return SyntheticPages(
                          pageCount: s7PageCount,
                          onGesture: _onPage,
                        );
                      },
                    ),
                  },
                  _ChromeOverlay(
                    barKey: _chromeKey,
                    shown: _chromeShown && !_practising,
                    title: _mode == S7Mode.surah ? widget.surah?.name : null,
                    onDebug: () => _scaffold.currentState?.openEndDrawer(),
                  ),
                  if (_selected != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.space4),
                          child: Center(
                            child: AyahToolbarStandIn(
                              onAction: (action) => setState(
                                () => widget.record.countAction(action),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if ((_waqf, widget.surah) case (
                    (final ayah, final mark)?,
                    final surah?,
                  )) ...[
                    ModalBarrier(
                      color: context.colors.scrim,
                      onDismiss: () => setState(() => _waqf = null),
                      semanticsLabel: MaterialLocalizations.of(
                        context,
                      ).modalBarrierDismissLabel,
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: WaqfCardStandIn(
                        surahName: surah.name,
                        ayah: ayah,
                        mark: mark,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  /// The reader at the pinch's step, which replaces the system scale
  /// (RD-07's steps are absolute); the system scale only chose the first
  /// step.
  Widget _surahReader(S7Surah surah) => Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(_step)),
      child: Builder(
        builder: (context) {
          _log.setContext(gestureLogContextOf(context));
          return ReaderPinch(
            onPinchEnd: _pinchEnd,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Read by _wrap, which the list calls within this builder.
                _viewportHeight = constraints.maxHeight;
                return KeyedSubtree(
                  key: _viewportKey,
                  child: SurahListV1(
                    surah: surah.text,
                    selected: {?_selected},
                    controller: _controller,
                    blockKey: _blockKey,
                    wrapBlock: _wrap,
                  ),
                );
              },
            ),
          );
        },
      ),
    ),
  );

  /// The block's gestures, and the margin's: the gutters, the chrome's inset
  /// above the text and, in a short surah, the viewport below it. Both sit
  /// inside the scroll view, which ignores pointers while it flings, so a
  /// tap that stops a fling opens nothing. On the block, the arena gives a
  /// tap or a long press to the block's own recognisers, which joined
  /// first.
  Widget _wrap(BuildContext context, SurahTextBlock block) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    excludeFromSemantics: true,
    onTapUp: (_) => _onTap(const MarginTarget()),
    onLongPressStart: (_) => _onLongPress(const MarginTarget()),
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: _viewportHeight),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.space4,
          _chromeHeight,
          AppSpacing.space4,
          0,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            BlockGestures(
              rule: _rule,
              onTap: _onTap,
              onLongPress: _onLongPress,
              child: block,
            ),
            if (_practice case final target?) PracticeRing(box: target.box),
          ],
        ),
      ),
    ),
  );
}

/// The UI over the text: shown and hidden in place, so the text never
/// moves; a fade, or none under reduce motion (AX-06).
final class _ChromeOverlay extends StatelessWidget {
  const _ChromeOverlay({
    required this.barKey,
    required this.shown,
    required this.title,
    required this.onDebug,
  });

  final Key barKey;
  final bool shown;
  final PackText? title;
  final VoidCallback onDebug;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = this.title;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !shown,
        child: ExcludeSemantics(
          excluding: !shown,
          child: AnimatedOpacity(
            opacity: shown ? 1 : 0,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : motionNormal,
            curve: motionCurve,
            child: ColoredBox(
              key: barKey,
              color: colors.ground,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space4,
                  ),
                  child: Row(
                    spacing: AppSpacing.space2,
                    children: [
                      Expanded(
                        child: title == null
                            ? const SizedBox.shrink()
                            : SurahName(
                                title,
                                style: AppTextStyles.surahHeader.copyWith(
                                  color: colors.primary,
                                ),
                              ),
                      ),
                      // Debug chrome, in the spike's English (D-072).
                      TextButton(
                        onPressed: onDebug,
                        child: const Text('Debug'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The practice prompt, in the spike's English: no UI string asks for a
/// tap yet.
final class _PracticeBar extends StatelessWidget {
  const _PracticeBar({
    required this.target,
    required this.record,
    required this.onNewTarget,
    required this.onStop,
  });

  final PracticeTarget? target;
  final S7Record record;
  final VoidCallback onNewTarget;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final trials = record.log.entries.where((entry) => entry.isTrial);
    final hits = trials.where((entry) => entry.isHit).length;
    final prompt = switch (target?.kind) {
      null => 'No target on screen: scroll, then New target',
      final kind => 'Tap the ringed ${kind.name}',
    };
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: context.colors.surface,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
            child: Wrap(
              spacing: AppSpacing.space2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('$prompt ($hits of ${trials.length} hit)'),
                TextButton(
                  onPressed: onNewTarget,
                  child: const Text('New target'),
                ),
                TextButton(onPressed: onStop, child: const Text('Stop')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
