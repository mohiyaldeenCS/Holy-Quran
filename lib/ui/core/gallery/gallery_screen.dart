import 'package:flutter/material.dart' hide Icon, IconButton, Switch, TabBar;

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/level_switch.dart';
import 'package:holyquran/ui/core/widgets/lockup.dart';
import 'package:holyquran/ui/core/widgets/mark.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/surah_header.dart';
import 'package:holyquran/ui/core/widgets/switch.dart';
import 'package:holyquran/ui/core/widgets/tab_bar.dart';

// The sample sizes of the identity's previews, which show the Mark's stroke
// steps and the components at their drawn sizes.
// Mark/preview.html: the paper marks, the emerald mark and the mono mark.
const List<double> _markSizes = [120, 64, 32, 24];
const double _markOnEmeraldSize = 104;
const double _markMonoSize = 64;
// Lockup/preview.html: the horizontal lockups; the stacked one is the default.
const double _lockupSize = 56;
// Icon/preview.html: every icon at 28.
const double _iconSampleSize = 28;
// AyahMarker/preview.html: the markers shown, in order.
const List<({int number, bool playing, double size})> _ayahMarkers = [
  (number: 5, playing: false, size: AppSizes.ayahMarker),
  (number: 42, playing: false, size: AppSizes.ayahMarker),
  (number: 255, playing: false, size: AppSizes.ayahMarker),
  (number: 1, playing: true, size: AppSizes.ayahMarker),
  (number: 286, playing: false, size: 36),
];

/// Debug-only review page: every M0.2 design-system widget, once in each
/// reading theme, laid out as the identity's previews show them.
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.space5),
              child: Semantics(
                header: true,
                child: Text(
                  AppLocalizations.of(context).galleryTitle,
                  style: AppTextStyles.screenTitle.copyWith(
                    color: context.colors.ink,
                  ),
                ),
              ),
            ),
            for (final theme in ReadingTheme.values)
              GalleryThemeBlock(theme: theme),
          ],
        ),
      ),
    ),
  );
}

/// The gallery's widgets in one [theme], on that theme's ground.
class GalleryThemeBlock extends StatelessWidget {
  const GalleryThemeBlock({required this.theme, super.key});

  final ReadingTheme theme;

  @override
  Widget build(BuildContext context) {
    final data = buildAppTheme(theme);
    return Theme(
      data: data,
      child: Builder(
        builder: (context) => ColoredBox(
          color: context.colors.ground,
          child: DefaultTextStyle(
            style: data.textTheme.bodyMedium!,
            child: _Sections(theme: theme),
          ),
        ),
      ),
    );
  }
}

class _Sections extends StatefulWidget {
  const _Sections({required this.theme});

  final ReadingTheme theme;

  @override
  State<_Sections> createState() => _SectionsState();
}

class _SectionsState extends State<_Sections> {
  bool _tajweed = true;
  bool _keepAwake = false;
  int _level = 0;
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.space5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.space6,
        children: [
          Semantics(
            header: true,
            child: Text(
              _themeName(l10n, widget.theme),
              style: AppTextStyles.sectionTitle.copyWith(color: colors.ink),
            ),
          ),
          _Section(
            title: l10n.gallerySectionMark,
            child: _row([
              for (final size in _markSizes) Mark(size: size),
              const _Backdrop(
                color: Ramps.emerald700,
                child: Mark(
                  size: _markOnEmeraldSize,
                  variant: MarkVariant.emerald,
                ),
              ),
              const _Backdrop(
                color: Ramps.emerald950,
                child: Mark(
                  size: _markOnEmeraldSize,
                  variant: MarkVariant.dark,
                ),
              ),
              IconTheme.merge(
                data: IconThemeData(color: colors.brandInk),
                child: const Mark(
                  size: _markMonoSize,
                  variant: MarkVariant.mono,
                ),
              ),
            ]),
          ),
          _Section(
            title: l10n.gallerySectionLockup,
            child: _row([
              const Lockup(size: _lockupSize),
              const _Backdrop(
                color: Ramps.emerald700,
                padding: AppSpacing.space4,
                child: Lockup(size: _lockupSize, onEmerald: true),
              ),
              const Lockup(stacked: true),
            ]),
          ),
          _Section(
            title: l10n.gallerySectionIcons,
            child: IconTheme.merge(
              data: IconThemeData(color: colors.primary),
              child: Wrap(
                spacing: AppSpacing.space4,
                runSpacing: AppSpacing.space4,
                children: [
                  for (final name in IconName.values)
                    Icon(name, size: _iconSampleSize),
                ],
              ),
            ),
          ),
          _Section(
            title: l10n.gallerySectionButtons,
            child: _row([
              Button(label: l10n.galleryButtonPrimary, onPressed: _none),
              Button(
                label: l10n.galleryButtonOutline,
                variant: ButtonVariant.outline,
                onPressed: _none,
              ),
              Button(
                label: l10n.galleryButtonTonal,
                variant: ButtonVariant.tonal,
                onPressed: _none,
              ),
              Button(
                label: l10n.galleryButtonText,
                variant: ButtonVariant.text,
                onPressed: _none,
              ),
              Button(label: l10n.galleryButtonDisabled, onPressed: null),
            ]),
          ),
          _Section(
            title: l10n.gallerySectionIconButtons,
            child: _row([
              IconButton(
                icon: IconName.play,
                label: l10n.galleryIconButtonPlayFromHere,
                onPressed: _none,
              ),
              IconButton(
                icon: IconName.bookmark,
                label: l10n.galleryIconButtonBookmark,
                onPressed: _none,
              ),
              IconButton(
                icon: IconName.study,
                label: l10n.galleryIconButtonStudy,
                onPressed: _none,
              ),
              IconButton(
                icon: IconName.search,
                label: l10n.galleryIconButtonSearch,
                tone: IconButtonTone.tint,
                onPressed: _none,
              ),
              IconButton(
                icon: IconName.play,
                label: l10n.galleryIconButtonPlay,
                tone: IconButtonTone.solid,
                size: AppSizes.buttonHeight,
                onPressed: _none,
              ),
            ]),
          ),
          _Section(
            title: l10n.gallerySectionSwitches,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Switch(
                  label: l10n.gallerySwitchTajweed,
                  value: _tajweed,
                  onChanged: (value) => setState(() => _tajweed = value),
                ),
                Switch(
                  label: l10n.gallerySwitchKeepAwake,
                  value: _keepAwake,
                  onChanged: (value) => setState(() => _keepAwake = value),
                ),
              ],
            ),
          ),
          _Section(
            title: l10n.gallerySectionLevelSwitch,
            child: LevelSwitch(
              options: [l10n.levelSimple, l10n.levelMedium, l10n.levelStudy],
              selectedIndex: _level,
              onChanged: (index) => setState(() => _level = index),
              semanticLabel: l10n.levelLabel,
            ),
          ),
          _Section(
            title: l10n.gallerySectionTabBar,
            child: TabBar(
              items: [
                TabBarItem(IconName.home, l10n.tabHome),
                TabBarItem(IconName.mushaf, l10n.tabMushaf),
                TabBarItem(IconName.listen, l10n.tabListen),
                TabBarItem(IconName.study, l10n.tabStudy),
                TabBarItem(IconName.more, l10n.tabMore),
              ],
              currentIndex: _tab,
              onSelected: (index) => setState(() => _tab = index),
              semanticLabel: l10n.mainNavigationLabel,
            ),
          ),
          _Section(
            title: l10n.gallerySectionQuranText,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.space3,
              children: [
                for (final size in QuranTextSize.values)
                  QuranText(l10n.sampleText, size: size),
              ],
            ),
          ),
          _Section(
            title: l10n.gallerySectionAyahMarker,
            child: _row([
              for (final (:number, :playing, :size) in _ayahMarkers)
                AyahMarker(number: number, playing: playing, size: size),
            ]),
          ),
          _Section(
            title: l10n.gallerySectionSurahHeader,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.space4,
              children: [
                SurahHeader(
                  name: l10n.sampleSurahName,
                  size: SurahHeaderSize.lg,
                  info: l10n.sampleInfo,
                ),
                SurahHeader(name: l10n.sampleSurahName),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _none() {}

String _themeName(AppLocalizations l10n, ReadingTheme theme) => switch (theme) {
  ReadingTheme.paper => l10n.themePaper,
  ReadingTheme.night => l10n.themeNight,
  ReadingTheme.sepia => l10n.themeSepia,
  ReadingTheme.contrast => l10n.themeContrast,
};

// .qk-row: a wrapping row, space-3 apart, centred across.
Widget _row(List<Widget> children) => Wrap(
  spacing: AppSpacing.space3,
  runSpacing: AppSpacing.space3,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: children,
);

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: AppSpacing.space3,
    children: [
      Semantics(
        header: true,
        child: Text(
          title,
          style: AppTextStyles.bodyStrong.copyWith(
            color: context.colors.inkMuted,
          ),
        ),
      ),
      child,
    ],
  );
}

/// The emerald surface the previews draw the brand variants on
/// (Mark/preview.html, Lockup/preview.html): fixed brand colours, radius 24.
class _Backdrop extends StatelessWidget {
  const _Backdrop({
    required this.color,
    required this.child,
    this.padding = AppSpacing.space2,
  });

  final Color color;
  final double padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppRadius.radiusCard),
    ),
    child: Padding(padding: EdgeInsets.all(padding), child: child),
  );
}
