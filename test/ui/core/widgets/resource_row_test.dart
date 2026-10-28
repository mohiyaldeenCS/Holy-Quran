import 'package:flutter/material.dart' hide Icon;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';
import 'package:holyquran/ui/core/widgets/progress_bar.dart';
import 'package:holyquran/ui/core/widgets/resource_row.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));
final _title = _l10n.sampleResourceTitle;
final _size = _l10n.sampleSize;
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space5),
            child: child,
          ),
        ),
      ),
    ),
  );
}

ResourceRow _row(
  ResourceStatus status, {
  String? size,
  double progress = 0,
  VoidCallback? onAction,
  bool divider = true,
}) => ResourceRow(
  title: _title,
  status: status,
  size: size,
  progress: progress,
  onAction: status == ResourceStatus.downloading ? onAction : onAction ?? () {},
  divider: divider,
);

Finder _face() => find.descendant(
  of: find.byType(Pressable),
  matching: find.byType(DecoratedBox),
);

BoxDecoration _faceDecoration(WidgetTester tester) =>
    tester.widget<DecoratedBox>(_face()).decoration as BoxDecoration;

TextStyle _style(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

void main() {
  tearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );

  testWidgets('pads 14 above and below, with a line hairline under it', (
    tester,
  ) async {
    await _pump(tester, _row(ResourceStatus.available, size: _size));
    final row = tester.getRect(find.byType(ResourceRow));
    final title = tester.getRect(find.text(_title));
    expect(title.top - row.top, 14);
    final border =
        (tester
                        .widget<DecoratedBox>(
                          find
                              .descendant(
                                of: find.byType(ResourceRow),
                                matching: find.byType(DecoratedBox),
                              )
                              .first,
                        )
                        .decoration
                    as BoxDecoration)
                .border!
            as Border;
    expect(border.bottom.color, _colors.line);
    expect(border.bottom.width, 1);
    final titleStyle = _style(tester, _title);
    expect(titleStyle.fontSize, 17);
    expect(titleStyle.fontWeight, FontWeight.w600);
    expect(titleStyle.color, _colors.ink);

    await _pump(
      tester,
      _row(ResourceStatus.available, size: _size, divider: false),
    );
    expect(
      (tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(ResourceRow),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration)
          .border,
      isNull,
    );
  });

  testWidgets('available: the size in ink-muted and a primary download', (
    tester,
  ) async {
    await _pump(tester, _row(ResourceStatus.available, size: _size));
    final meta = _style(tester, _l10n.resourceAvailableMeta(_size));
    expect(meta.fontSize, 14);
    expect(meta.color, _colors.inkMuted);
    final decoration = _faceDecoration(tester);
    expect(decoration.color, _colors.primary);
    expect(decoration.border, isNull);
    expect(decoration.borderRadius, BorderRadius.circular(14));
    final label = _style(tester, _l10n.resourceDownload);
    expect(label.fontSize, 15);
    expect(label.fontWeight, FontWeight.w600);
    expect(label.color, _colors.onPrimary);
    expect(tester.getSize(_face()).height, 44);
    final face = tester.getRect(_face());
    final text = tester.getRect(find.text(_l10n.resourceDownload));
    expect(face.right - text.right, AppSpacing.space4);
    // The button sits at the left, 16 from the title column.
    final row = tester.getRect(find.byType(ResourceRow));
    expect(face.left, row.left);
  });

  testWidgets(
    'downloaded: a check and the words in success, an outline delete',
    (tester) async {
      await _pump(tester, _row(ResourceStatus.downloaded, size: _size));
      final meta = _style(tester, _l10n.resourceDownloadedMeta(_size));
      expect(meta.fontSize, 14);
      expect(meta.fontWeight, FontWeight.w500);
      expect(meta.color, _colors.success);
      final check = tester.widget<Icon>(find.byType(Icon));
      expect(check.name, IconName.check);
      expect(check.size, 16);
      expect(check.color, _colors.success);
      final checkRect = tester.getRect(find.byType(Icon));
      final metaRect = tester.getRect(
        find.text(_l10n.resourceDownloadedMeta(_size)),
      );
      expect(checkRect.left - metaRect.right, AppSpacing.space1);
      final decoration = _faceDecoration(tester);
      expect(decoration.color, isNull);
      final border = decoration.border! as Border;
      expect(border.top.color, _colors.line);
      expect(border.top.width, 1.5);
      expect(_style(tester, _l10n.resourceDelete).color, _colors.ink);
    },
  );

  testWidgets('downloading: a primary track and the percentage', (
    tester,
  ) async {
    await _pump(tester, _row(ResourceStatus.downloading, progress: 0.6));
    final bar = tester.widget<ProgressBar>(find.byType(ProgressBar));
    expect(bar.tone, ProgressBarTone.primary);
    expect(bar.value, 0.6);
    expect(bar.label, _l10n.resourceDownloading(_title));
    final percent = _l10n.percentValue(arabicDigits(60));
    final style = _style(tester, percent);
    expect(style.fontSize, 15);
    expect(style.fontWeight, FontWeight.w600);
    expect(style.color, _colors.primary);
    expect(find.byType(Pressable), findsNothing);
    final title = tester.getRect(find.text(_title));
    final track = tester.getRect(find.byType(ProgressBar));
    expect(track.top - title.bottom, 6);
  });

  testWidgets('says the status alone when the size is unknown', (tester) async {
    await _pump(tester, _row(ResourceStatus.available));
    expect(find.text(_l10n.resourceAvailable), findsOneWidget);
    await _pump(tester, _row(ResourceStatus.downloaded));
    expect(find.text(_l10n.resourceDownloaded), findsOneWidget);
  });

  testWidgets('writes its details after the state, joined and unchanged', (
    tester,
  ) async {
    const details = [' نص تجريبي  أول', '٢', 'نص تجريبي ثان '];
    for (final (status, state) in [
      (ResourceStatus.available, _l10n.resourceAvailableMeta(_size)),
      (ResourceStatus.downloaded, _l10n.resourceDownloadedMeta(_size)),
    ]) {
      await _pump(
        tester,
        ResourceRow(
          title: _title,
          status: status,
          size: _size,
          details: details,
          onAction: () {},
        ),
      );
      final line = [state, ...details].join(_l10n.dataSeparator);
      expect(find.text(line), findsOneWidget, reason: status.name);
      expect(_style(tester, line).fontSize, 14, reason: status.name);
    }
  });

  testWidgets('writes details after the bare state when the size is unknown', (
    tester,
  ) async {
    await _pump(
      tester,
      ResourceRow(
        title: _title,
        status: ResourceStatus.available,
        details: const ['٢'],
        onAction: () {},
      ),
    );
    expect(
      find.text([_l10n.resourceAvailable, '٢'].join(_l10n.dataSeparator)),
      findsOneWidget,
    );
  });

  testWidgets('acts when tapped anywhere in its 48 target or by keyboard', (
    tester,
  ) async {
    var presses = 0;
    await _pump(
      tester,
      _row(ResourceStatus.available, onAction: () => presses++),
    );
    final face = tester.getRect(_face());
    await tester.tapAt(face.center);
    await tester.tapAt(face.topCenter - const Offset(0, 1.5));
    expect(presses, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(presses, 3);
  });

  testWidgets('reads the button as one labelled node', (tester) async {
    final handle = tester.ensureSemantics();
    for (final (status, label) in [
      (ResourceStatus.available, _l10n.resourceDownload),
      (ResourceStatus.downloaded, _l10n.resourceDelete),
    ]) {
      await _pump(tester, _row(status, size: _size));
      final node = tester.getSemantics(find.byType(Pressable));
      expect(
        node,
        matchesSemantics(
          label: label,
          isButton: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
        reason: status.name,
      );
      expect(node.childrenCount, 0, reason: status.name);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    }

    await _pump(tester, _row(ResourceStatus.downloading, progress: 0.6));
    expect(
      tester.getSemantics(find.byType(ProgressBar)),
      matchesSemantics(
        label: _l10n.resourceDownloading(_title),
        value: _l10n.percentValue(arabicDigits(60)),
      ),
    );
    final percent = find.text(_l10n.percentValue(arabicDigits(60)));
    expect(
      find.ancestor(of: percent, matching: find.byType(ExcludeSemantics)),
      findsWidgets,
    );
    handle.dispose();
  });

  testWidgets('draws the focus ring in keyboard mode only', (tester) async {
    await _pump(tester, _row(ResourceStatus.available, size: _size));
    bool ringDrawn() =>
        tester
            .widget<CustomPaint>(
              find
                  .descendant(
                    of: find.byType(FocusRing),
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
    expect(
      tester.widget<FocusRing>(find.byType(FocusRing)).radius,
      BorderRadius.circular(14),
    );
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    await tester.pump();
    expect(ringDrawn(), isFalse);
  });

  testWidgets('does not overflow at 200% text on 360 wide', (tester) async {
    await _pump(
      tester,
      // Scrolls, as the resource manager does, so only the rows can overflow.
      SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ResourceRow(
              title: _l10n.sampleLongText,
              status: ResourceStatus.downloaded,
              size: _size,
              onAction: () {},
            ),
            _row(ResourceStatus.downloading, progress: 1),
            _row(ResourceStatus.available, size: _size),
          ],
        ),
      ),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
  });
}
