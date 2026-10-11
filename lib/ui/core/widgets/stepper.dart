import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';

// .qk-stepper: min-height 56px.
const double _minHeight = 56;
// .qk-stepper-ctl: gap 6px.
const double _controlGap = 6;
// .qk-stepper-btn: border-radius 14px.
const BorderRadius _buttonRadius = BorderRadius.all(Radius.circular(14));
// Stepper in index.jsx: <Icon name="minus" size={18} />, and plus.
const double _iconSize = 18;
// .qk-stepper-val: min-width 52px.
const double _valueMinWidth = 52;
// Stepper in index.jsx: `min = 1, max = 99`.
const int _defaultMin = 1;
const int _defaultMax = 99;

// The label and the value set no line height, so they are drawn at the font's
// own (CSS `normal`); the styles do not inherit, so the ambient body line
// height cannot reach them.

// .qk-stepper: font-size 16px, in the sans 400.
const TextStyle _labelStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 16,
  fontWeight: FontWeight.w400,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);
// .qk-stepper-val: font-size 17px; font-weight 700.
const TextStyle _valueStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 17,
  fontWeight: FontWeight.w700,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);

/// A number setting with minus and plus (`Stepper`, `.qk-stepper`): the
/// [label] at the start, then minus, the value in Arabic-Indic digits with
/// its optional [unit], and plus. The value stays within [min] and [max]; at
/// a bound, the button that would pass it is disabled.
///
/// Each button is named after the setting («زيادة …»), and the value is a
/// live region, announced when it changes.
class Stepper extends StatelessWidget {
  const Stepper({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = _defaultMin,
    this.max = _defaultMax,
    this.unit,
    super.key,
  }) : assert(min <= value && value <= max);

  final String label;
  final int value;
  final int min;
  final int max;
  final String? unit;
  final ValueChanged<int> onChanged;

  void _set(int next) => onChanged(next.clamp(min, max));

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final digits = arabicDigits(value);
    final unit = this.unit;
    final valueText = unit == null
        ? digits
        : l10n.stepperValueWithUnit(digits, unit);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _minHeight),
        child: Row(
          spacing: AppSpacing.space3,
          children: [
            Expanded(
              child: Text(
                label,
                style: _labelStyle.copyWith(color: colors.ink),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: _controlGap,
              children: [
                _StepButton(
                  icon: IconName.minus,
                  label: l10n.stepperDecrease(label),
                  onPressed: value > min ? () => _set(value - 1) : null,
                ),
                Semantics(
                  container: true,
                  liveRegion: true,
                  label: valueText,
                  child: ExcludeSemantics(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: _valueMinWidth,
                      ),
                      child: Text(
                        valueText,
                        textAlign: TextAlign.center,
                        style: _valueStyle.copyWith(color: colors.ink),
                      ),
                    ),
                  ),
                ),
                _StepButton(
                  icon: IconName.plus,
                  label: l10n.stepperIncrease(label),
                  onPressed: value < max ? () => _set(value + 1) : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// `.qk-stepper-btn`: a target-min square, `line-strong` border on
/// `surface`; disabled, the border is `line` and the icon `ink-disabled`.
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconName icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onPressed != null;
    return Semantics(
      container: true,
      // Pressable states the button role and the disabled state; the enabled
      // state is announced here. A flag set twice would split the node.
      enabled: enabled ? true : null,
      label: label,
      child: Pressable(
        onPressed: onPressed,
        focusRadius: _buttonRadius,
        child: Container(
          width: AppSizes.targetMin,
          height: AppSizes.targetMin,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(
              color: enabled ? colors.lineStrong : colors.line,
            ),
            borderRadius: _buttonRadius,
          ),
          child: Icon(
            icon,
            size: _iconSize,
            color: enabled ? colors.ink : colors.inkDisabled,
          ),
        ),
      ),
    );
  }
}
