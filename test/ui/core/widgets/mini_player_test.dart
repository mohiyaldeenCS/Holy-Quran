import 'package:flutter/material.dart' hide Icon;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/mini_player.dart';
import 'package:holyquran/ui/core/widgets/progress_bar.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));
final _surah = PackText.fromPack(_l10n.sampleSurahName);
const _colors = AppColors.paper;

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = const Size(360, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    goldenApp(
      ReadingTheme.paper,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child,
        ),
      ),
    ),
  );
}

MiniPlayer _player({
  String? reciter,
  bool playing = true,
  int repeat = 0,
  VoidCallback? onRepeat,
  VoidCallback? onPrevious,
  VoidCallback? onPlayPause,
  VoidCallback? onNext,
  VoidCallback? onSleepTimer,
}) => MiniPlayer(
  surah: _surah,
  ayah: 5,
  reciter: reciter,
  speed: _l10n.gallerySpeed,
  playing: playing,
  progress: 0.46,
  repeat: repeat,
  onRepeat: onRepeat,
  onPrevious: onPrevious,
  onPlayPause: onPlayPause,
  onNext: onNext,
  onSleepTimer: onSleepTimer,
);

Finder _button(IconName icon) => find.byWidgetPredicate(
  (widget) => widget is PlayerButton && widget.icon == icon,
);

Finder _face(IconName icon) => find.descendant(
  of: _button(icon),
  matching: find.byWidgetPredicate(
    (widget) => widget is Container && widget.decoration != null,
  ),
);

BoxDecoration _faceDecoration(WidgetTester tester, IconName icon) =>
    tester.widget<Container>(_face(icon)).decoration! as BoxDecoration;

BoxDecoration _cardDecoration(WidgetTester tester) =>
    tester.widget<Container>(find.byType(Container).first).decoration!
        as BoxDecoration;

const _plainIcons = [
  IconName.repeat,
  IconName.previous,
  IconName.next,
  IconName.night,
];

void main() {
  tearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );

  testWidgets(
    'is the emerald card: radius 24, padding 22 by 24, sheet shadow',
    (tester) async {
      await _pump(tester, _player(reciter: _l10n.sampleReciter));
      final decoration = _cardDecoration(tester);
      expect(decoration.color, _colors.player);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(AppRadius.radiusCard),
      );
      expect(decoration.boxShadow, AppShadows.paper.shadowSheet);
      expect(
        tester.widget<Container>(find.byType(Container).first).padding,
        const EdgeInsets.symmetric(vertical: 22, horizontal: 24),
      );
      final progress = tester.widget<ProgressBar>(find.byType(ProgressBar));
      expect(progress.tone, ProgressBarTone.player);
      expect(progress.value, 0.46);
      expect(progress.label, _l10n.playerPosition);
    },
  );

  testWidgets('titles the surah with the ayah, Reem Kufi 24 at weight 400', (
    tester,
  ) async {
    await _pump(tester, _player());
    final title = tester.widget<SurahName>(find.byType(SurahName));
    expect(title.name, _surah);
    expect(title.format, SurahNameFormat.withAyah);
    expect(title.ayah, 5);
    expect(title.style.fontFamily, AppFonts.kufi);
    expect(title.style.fontSize, 24);
    expect(title.style.height, 1.4);
    expect(title.style.fontWeight, FontWeight.w400);
    expect(title.style.color, _colors.onPlayer);
    expect(
      find.text(
        _l10n.surahAyahReference(_l10n.sampleSurahName, arabicDigits(5)),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows the reciter in on-player-muted, hides it when null', (
    tester,
  ) async {
    await _pump(tester, _player(reciter: _l10n.sampleReciter));
    final reciter = tester.widget<Text>(find.text(_l10n.sampleReciter));
    expect(reciter.style!.fontSize, 14);
    expect(reciter.style!.color, _colors.onPlayerMuted);

    await _pump(tester, _player());
    expect(find.text(_l10n.sampleReciter), findsNothing);
    expect(
      find.descendant(of: find.byType(MiniPlayer), matching: find.byType(Text)),
      findsNWidgets(2),
    );
  });

  testWidgets('draws the speed chip: paper-100 at 14%, radius 12, 14 bold', (
    tester,
  ) async {
    await _pump(tester, _player());
    final speed = tester.widget<Text>(find.text(_l10n.gallerySpeed));
    expect(speed.style!.fontSize, 14);
    expect(speed.style!.fontWeight, FontWeight.w600);
    expect(speed.style!.color, _colors.onPlayer);
    final chip = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.text(_l10n.gallerySpeed),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = chip.decoration as BoxDecoration;
    expect(decoration.color, Ramps.paper100.withValues(alpha: 0.14));
    expect(decoration.borderRadius, BorderRadius.circular(AppRadius.radiusMd));
    final chipRect = tester.getRect(
      find
          .ancestor(
            of: find.text(_l10n.gallerySpeed),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final textRect = tester.getRect(find.text(_l10n.gallerySpeed));
    expect(textRect.top - chipRect.top, 6);
    expect(chipRect.right - textRect.right, 12);
  });

  testWidgets('sizes and colours the five buttons as the reference does', (
    tester,
  ) async {
    await _pump(tester, _player());
    for (final icon in _plainIcons) {
      expect(tester.getSize(_face(icon)), const Size.square(48));
      expect(_faceDecoration(tester, icon).color, isNull);
      final glyph = tester.widget<Icon>(
        find.descendant(of: _button(icon), matching: find.byType(Icon)),
      );
      expect(glyph.size, 26, reason: icon.name);
      expect(glyph.color, _colors.onPlayer, reason: icon.name);
    }
    expect(tester.getSize(_face(IconName.pause)), const Size.square(60));
    expect(_faceDecoration(tester, IconName.pause).color, _colors.playerAccent);
    expect(
      _faceDecoration(tester, IconName.pause).borderRadius,
      BorderRadius.circular(AppRadius.radiusFull),
    );
    final main = tester.widget<Icon>(
      find.descendant(of: _button(IconName.pause), matching: find.byType(Icon)),
    );
    expect(main.size, 28);
    expect(main.color, Ramps.emerald950);
  });

  testWidgets('orders the buttons from the right: repeat first, sleep last', (
    tester,
  ) async {
    await _pump(tester, _player());
    final order = [
      IconName.repeat,
      IconName.previous,
      IconName.pause,
      IconName.next,
      IconName.night,
    ];
    final xs = [for (final icon in order) tester.getCenter(_button(icon)).dx];
    for (var i = 1; i < xs.length; i++) {
      expect(xs[i], lessThan(xs[i - 1]), reason: order[i].name);
    }
    // The title sits at the right, the speed chip at the left.
    expect(
      tester.getCenter(find.byType(SurahName)).dx,
      greaterThan(tester.getCenter(find.text(_l10n.gallerySpeed)).dx),
    );
  });

  testWidgets('shows play while paused and pause while playing', (
    tester,
  ) async {
    await _pump(tester, _player(playing: false));
    expect(_button(IconName.play), findsOneWidget);
    expect(_button(IconName.pause), findsNothing);
  });

  testWidgets('shows the repeat count at the top left, 18 round, in gold', (
    tester,
  ) async {
    await _pump(tester, _player());
    expect(
      find.descendant(
        of: _button(IconName.repeat),
        matching: find.byType(Text),
      ),
      findsNothing,
    );

    await _pump(tester, _player(repeat: 3));
    final count = find.descendant(
      of: _button(IconName.repeat),
      matching: find.text(arabicDigits(3)),
    );
    expect(count, findsOneWidget);
    final text = tester.widget<Text>(count);
    expect(text.style!.fontSize, 11);
    expect(text.style!.fontWeight, FontWeight.w700);
    expect(text.style!.color, Ramps.emerald950);
    final badge = find.ancestor(of: count, matching: find.byType(Container));
    final decoration =
        tester.widget<Container>(badge.first).decoration! as BoxDecoration;
    expect(decoration.color, _colors.playerAccent);
    expect(decoration.borderRadius, BorderRadius.circular(9));
    final badgeRect = tester.getRect(badge.first);
    final buttonRect = tester.getRect(_button(IconName.repeat));
    expect(badgeRect.size, const Size.square(18));
    expect(badgeRect.topLeft - buttonRect.topLeft, const Offset(2, 2));
    expect(tester.widget<PlayerButton>(_button(IconName.repeat)).count, 3);
  });

  testWidgets('keeps the repeat count round at 200%, a pill only when wide', (
    tester,
  ) async {
    Rect countRect(int repeat) => tester.getRect(
      find
          .ancestor(
            of: find.text(arabicDigits(repeat)),
            matching: find.byType(Container),
          )
          .first,
    );
    BorderRadius? countRadius(int repeat) =>
        (tester
                        .widget<Container>(
                          find
                              .ancestor(
                                of: find.text(arabicDigits(repeat)),
                                matching: find.byType(Container),
                              )
                              .first,
                        )
                        .decoration!
                    as BoxDecoration)
                .borderRadius
            as BorderRadius?;

    await _pump(tester, _player(repeat: 3), textScale: 2);
    final round = countRect(3);
    expect(round.width, round.height);
    expect(round.height, 36);
    expect(countRadius(3), BorderRadius.circular(18));

    // The count has no padding: only a long number is wider than the circle.
    await _pump(tester, _player(repeat: 100000), textScale: 2);
    final pill = countRect(100000);
    expect(pill.height, 36);
    expect(pill.width, greaterThan(pill.height));
    expect(countRadius(100000), BorderRadius.circular(18));
  });

  testWidgets('names the repeat count in the genitive after «تكرار»', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    for (final (repeat, label) in [
      (1, 'تكرار مرة واحدة'),
      (2, 'تكرار مرتين'),
      (3, 'تكرار ٣ مرات'),
      (11, 'تكرار ١١ مرة'),
    ]) {
      expect(_l10n.playerRepeatTimes(repeat, arabicDigits(repeat)), label);
      await _pump(tester, _player(repeat: repeat, onRepeat: () {}));
      expect(
        tester.getSemantics(_button(IconName.repeat)).label,
        label,
        reason: '$repeat',
      );
    }
    handle.dispose();
  });

  testWidgets('calls each callback when tapped or activated by keyboard', (
    tester,
  ) async {
    final presses = <String>[];
    await _pump(
      tester,
      _player(
        onRepeat: () => presses.add('repeat'),
        onPrevious: () => presses.add('previous'),
        onPlayPause: () => presses.add('main'),
        onNext: () => presses.add('next'),
        onSleepTimer: () => presses.add('sleep'),
      ),
    );
    for (final icon in [
      IconName.repeat,
      IconName.previous,
      IconName.pause,
      IconName.next,
      IconName.night,
    ]) {
      await tester.tap(_button(icon));
    }
    expect(presses, ['repeat', 'previous', 'main', 'next', 'sleep']);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(presses.last, 'repeat');
  });

  testWidgets('a button with no callback is disabled and does nothing', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var presses = 0;
    await _pump(tester, _player(onNext: () => presses++));
    await tester.tap(_button(IconName.previous), warnIfMissed: false);
    expect(presses, 0);
    expect(
      tester.getSemantics(_button(IconName.previous)),
      matchesSemantics(
        label: _l10n.playerPreviousAyah,
        isButton: true,
        hasEnabledState: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('reads every button as one labelled node', (tester) async {
    final handle = tester.ensureSemantics();
    void call() {}
    await _pump(
      tester,
      _player(
        repeat: 3,
        onRepeat: call,
        onPrevious: call,
        onPlayPause: call,
        onNext: call,
        onSleepTimer: call,
      ),
    );
    final labels = {
      IconName.repeat: _l10n.playerRepeatTimes(3, arabicDigits(3)),
      IconName.previous: _l10n.playerPreviousAyah,
      IconName.pause: _l10n.playerPause,
      IconName.next: _l10n.playerNextAyah,
      IconName.night: _l10n.playerSleepTimer,
    };
    for (final MapEntry(key: icon, value: label) in labels.entries) {
      // One node per button: the badge and the glyph add none.
      expect(tester.getSemantics(_button(icon)).childrenCount, 0);
      expect(
        tester.getSemantics(_button(icon)),
        matchesSemantics(
          label: label,
          isButton: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
        reason: icon.name,
      );
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    await _pump(tester, _player(playing: false, onRepeat: call));
    expect(
      tester.getSemantics(_button(IconName.repeat)).label,
      _l10n.playerRepeat,
    );
    expect(tester.getSemantics(_button(IconName.play)).label, _l10n.playerPlay);
    handle.dispose();
  });

  testWidgets('draws the focus ring in keyboard mode only', (tester) async {
    await _pump(tester, _player(onRepeat: () {}));
    bool ringDrawn() =>
        tester
            .widget<CustomPaint>(
              find
                  .descendant(
                    of: find.descendant(
                      of: _button(IconName.repeat),
                      matching: find.byType(FocusRing),
                    ),
                    matching: find.byType(CustomPaint),
                  )
                  .first,
            )
            .foregroundPainter !=
        null;
    expect(ringDrawn(), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(ringDrawn(), isTrue);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    await tester.pump();
    expect(ringDrawn(), isFalse);
  });

  testWidgets('does not overflow at 200% text on 360 wide', (tester) async {
    await _pump(
      tester,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
        child: MiniPlayer(
          surah: _surah,
          ayah: 286,
          reciter: _l10n.sampleLongText,
          speed: _l10n.gallerySpeed,
          playing: true,
          repeat: 11,
        ),
      ),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
  });
}
