import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/copy_form.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/copy_sheet.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

// Synthetic, never Quran text. Spaces at both ends and a double space inside
// would be lost to any trimming or normalising.
const _ayah = PackText.fromPack(' نص تجريبي  للاختبار ');
final _longAyah = PackText.fromPack(
  List.filled(12, 'نص تجريبي للاختبار').join(' '),
);

// Synthetic references; the ayah-only form has none.
const _references = {
  CopyForm.ayahOnly: null,
  CopyForm.withSurah: '[اسم تجريبي]',
  CopyForm.withSurahAndNumber: '[اسم تجريبي: ٥]',
};

final _labels = {
  CopyForm.ayahOnly: _l10n.copyAyahOnly,
  CopyForm.withSurah: _l10n.copyWithSurah,
  CopyForm.withSurahAndNumber: _l10n.copyWithSurahAndNumber,
};

Future<void> _pump(
  WidgetTester tester,
  Widget sheet, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = const Size(360, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    goldenApp(
      theme,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Align(alignment: Alignment.bottomCenter, child: sheet),
        ),
      ),
    ),
  );
}

/// A sheet whose selection follows taps, previewing [ayah] with the selected
/// form's reference; [copies] counts the copy taps.
Widget _live({
  List<CopyForm> forms = CopyForm.values,
  List<CopyForm>? selections,
  List<int>? copies,
  bool enabled = true,
  PackText? ayah = _ayah,
}) {
  var selected = CopyForm.withSurahAndNumber;
  return StatefulBuilder(
    builder: (context, setState) => CopySheet(
      forms: forms,
      selected: selected,
      onSelected: (form) {
        selections?.add(form);
        setState(() => selected = form);
      },
      onCopy: enabled ? () => copies?.add(1) : null,
      ayah: ayah,
      reference: _references[selected],
    ),
  );
}

List<InlineSpan> _previewSpans(WidgetTester tester) =>
    (tester
                .renderObject<RenderParagraph>(
                  find.descendant(
                    of: find.byType(QuranText),
                    matching: find.byType(RichText),
                  ),
                )
                .text
            as TextSpan)
        .children!;

// The nearest bordered box around the preview's text; the sheet is the next.
Finder _previewBox() => find
    .ancestor(
      of: find.byType(QuranText),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).border != null,
      ),
    )
    .first;

Finder _row(CopyForm form) => find.ancestor(
  of: find.text(_labels[form]!),
  matching: find.byType(GestureDetector),
);

void main() {
  testWidgets('shows the title, the given forms and the copy button', (
    tester,
  ) async {
    await _pump(tester, _live(forms: [CopyForm.withSurahAndNumber]));
    expect(find.text(_l10n.copySheetTitle), findsOneWidget);
    expect(find.text(_l10n.copyWithSurahAndNumber), findsOneWidget);
    expect(find.text(_l10n.copyAyahOnly), findsNothing);
    expect(find.text(_l10n.copyWithSurah), findsNothing);
    expect(tester.widget<Button>(find.byType(Button)).label, _l10n.copyAction);
  });

  testWidgets('a form is chosen by tap and by keyboard; copy runs on tap', (
    tester,
  ) async {
    final selections = <CopyForm>[];
    final copies = <int>[];
    await _pump(tester, _live(selections: selections, copies: copies));
    await tester.tap(find.text(_l10n.copyAyahOnly));
    await tester.pump();
    expect(selections, [CopyForm.ayahOnly]);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(selections, [CopyForm.ayahOnly, CopyForm.withSurah]);

    await tester.tap(find.byType(Button));
    expect(copies, [1]);
  });

  testWidgets('the forms are a labelled radio group; the button is disabled '
      'without onCopy', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _live(enabled: false));
    expect(
      tester.getSemantics(find.text(_l10n.copySheetTitle)),
      matchesSemantics(label: _l10n.copySheetTitle, isHeader: true),
    );
    for (final form in CopyForm.values) {
      final selected = form == CopyForm.withSurahAndNumber;
      expect(
        tester.getSemantics(_row(form).first),
        matchesSemantics(
          label: _labels[form],
          hasCheckedState: true,
          isChecked: selected,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
    }
    expect(
      tester.getSemantics(find.byType(Button)),
      matchesSemantics(
        label: _l10n.copyAction,
        isButton: true,
        hasEnabledState: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('the selected radio is primary with its dot; the others '
      'line-strong rings', (tester) async {
    await _pump(tester, _live());
    final colors = buildAppTheme(ReadingTheme.paper).extension<AppColors>()!;
    for (final form in CopyForm.values) {
      final rings = find.descendant(
        of: _row(form).first,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
      );
      final selected = form == CopyForm.withSurahAndNumber;
      expect(rings, findsNWidgets(selected ? 2 : 1));
      final ring =
          tester.widget<Container>(rings.first).decoration! as BoxDecoration;
      expect(
        (ring.border! as Border).top.color,
        selected ? colors.primary : colors.lineStrong,
      );
      expect(tester.getSize(rings.first), const Size(22, 22));
    }
  });

  testWidgets('every row and the button are at least 48 high', (tester) async {
    await _pump(tester, _live());
    for (final form in CopyForm.values) {
      expect(
        tester.getSize(_row(form).first).height,
        greaterThanOrEqualTo(AppSizes.targetMin),
      );
    }
    expect(
      tester.getSize(find.byType(Button)).height,
      greaterThanOrEqualTo(AppSizes.targetMin),
    );
  });

  for (final form in CopyForm.values) {
    testWidgets('the preview of ${form.name} is the ayah unchanged, quoted, '
        "with that form's reference", (tester) async {
      await _pump(tester, _live());
      await tester.tap(find.text(_labels[form]!));
      await tester.pump();
      expect(tester.widget<QuranText>(find.byType(QuranText)).text, _ayah);
      final spans = _previewSpans(tester);
      final text = (spans[1] as TextSpan).text!;
      expect(identical(text, _ayah.verbatim), isTrue);
      expect(utf8.encode(text), utf8.encode(_ayah.verbatim));
      expect((spans[0] as TextSpan).text, _l10n.ayahQuoteOpen);
      expect((spans[2] as TextSpan).text, _l10n.ayahQuoteClose);
      final reference = _references[form];
      if (reference == null) {
        expect(spans, hasLength(3));
      } else {
        expect(spans, hasLength(4));
        expect((spans[3] as TextSpan).toPlainText(), ' $reference');
      }
    });
  }

  testWidgets('no preview without an ayah', (tester) async {
    await _pump(tester, _live(ayah: null));
    expect(find.byType(QuranText), findsNothing);
    expect(find.text(_l10n.copyAction), findsOneWidget);
  });

  testWidgets('the preview sits between the forms and the button, on ground '
      'with a line border, its reference in ink-muted', (tester) async {
    await _pump(tester, _live());
    final colors = buildAppTheme(ReadingTheme.paper).extension<AppColors>()!;
    final box =
        tester.widget<DecoratedBox>(_previewBox()).decoration as BoxDecoration;
    expect(box.color, colors.ground);
    expect((box.border! as Border).top.color, colors.line);
    expect(box.borderRadius, BorderRadius.circular(AppRadius.radiusButton));
    final reference = (_previewSpans(tester)[3] as TextSpan).style!;
    expect(reference.color, colors.inkMuted);
    expect(reference.fontSize, 15);
    expect(reference.fontFamily, AppFonts.sans);
    final top = tester.getTopLeft(_previewBox()).dy;
    expect(
      top,
      greaterThan(tester.getBottomLeft(_row(CopyForm.values.last).first).dy),
    );
    expect(
      tester.getBottomLeft(_previewBox()).dy,
      lessThan(tester.getTopLeft(find.byType(Button)).dy),
    );
  });

  for (final theme in ReadingTheme.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('lays out without overflow in ${theme.name} at '
          '${(scale * 100).round()}% on 360 wide, with a long preview', (
        tester,
      ) async {
        await _pump(
          tester,
          _live(ayah: _longAyah),
          theme: theme,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(QuranText), findsOneWidget);
        expect(tester.getSize(_previewBox()).width, lessThanOrEqualTo(360));
      });
    }
  }
}
