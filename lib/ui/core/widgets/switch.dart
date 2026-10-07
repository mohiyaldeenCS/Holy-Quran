import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/theme/motion.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';

// .qk-switch: width 56px.
const double _trackWidth = 56;
// .qk-switch: height 32px; border-radius 16px is half of it.
const double _trackHeight = 32;
// .qk-switch-knob: width and height 24px; border-radius 12px is half of it.
const double _knobSize = 24;
// .qk-switch-knob: top 4px, right 4px; .is-on: right 28px.
const double _knobInset = AppSpacing.space1;
const double _knobOnRight = _trackWidth - _knobSize - _knobInset;

const BorderRadius _trackRadius = BorderRadius.all(
  Radius.circular(_trackHeight / 2),
);
const BorderRadius _knobRadius = BorderRadius.all(
  Radius.circular(_knobSize / 2),
);

/// The identity's settings switch (`Switch`, `.qk-switch-row`): the label and
/// a 56 by 32 track in a row at least 48 high; the whole row toggles. Off, the
/// knob sits on the right; on, it moves to the left (`right: 4px` to `28px`).
/// The off track is `line`, as in the reference (O-12).
class Switch extends StatelessWidget {
  const Switch({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  void _toggle() => onChanged(!value);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final track = SizedBox(
      width: _trackWidth,
      height: _trackHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: value ? colors.primary : colors.line,
          borderRadius: _trackRadius,
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              // .qk-switch-knob: transition right 200ms ease-out.
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : motionNormal,
              curve: motionCurve,
              top: _knobInset,
              right: value ? _knobOnRight : _knobInset,
              width: _knobSize,
              height: _knobSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: value ? colors.onPrimary : colors.surface,
                  borderRadius: _knobRadius,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      container: true,
      toggled: value,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.targetMin),
          child: Row(
            spacing: AppSpacing.space4,
            children: [
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    label,
                    style: AppTextStyles.body.copyWith(color: colors.ink),
                  ),
                ),
              ),
              FocusRing(
                radius: _trackRadius,
                child: FocusableActionDetector(
                  mouseCursor: SystemMouseCursors.click,
                  actions: {
                    ActivateIntent: CallbackAction<ActivateIntent>(
                      onInvoke: (_) => _toggle(),
                    ),
                  },
                  child: track,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
