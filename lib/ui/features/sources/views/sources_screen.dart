import 'package:flutter/material.dart' hide IconButton;
import 'package:go_router/go_router.dart';

import 'package:holyquran/domain/models/source_credit.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/metrics/settings_metrics.dart';
import 'package:holyquran/ui/core/metrics/sources_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/features/sources/view_models/sources_view_model.dart';
import 'package:intl/intl.dart' show Bidi;

/// «المصادر والتراخيص» (PRD §7.1): each source of the installed packs with
/// its name, its link and its licence or credit text, as the pack carries
/// them. It follows the settings screen's header; a field the pack leaves
/// empty is not shown. A null [viewModel] means the app provides no installer
/// yet; the screen then shows its title alone.
class SourcesScreen extends StatelessWidget {
  const SourcesScreen({required this.viewModel, super.key});

  final SourcesViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final viewModel = this.viewModel;
    return ColoredBox(
      color: context.colors.ground,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: SettingsMetrics.header,
              child: Row(
                children: [
                  IconButton(
                    icon: IconName.previous,
                    label: l10n.back,
                    tone: IconButtonTone.tint,
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.sourcesTitle,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyStrong.copyWith(
                          color: context.colors.ink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.targetMin),
                ],
              ),
            ),
            Expanded(
              child: viewModel == null
                  ? const SizedBox.shrink()
                  : ListenableBuilder(
                      listenable: viewModel,
                      builder: (context, _) => SourcesList(
                        sources: viewModel.sources,
                        fontLicences: viewModel.fontLicences,
                        linkFailed: viewModel.linkFailed,
                        onOpen: viewModel.open,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The column of sources under the header.
class SourcesList extends StatelessWidget {
  const SourcesList({
    required this.sources,
    required this.fontLicences,
    required this.linkFailed,
    required this.onOpen,
    super.key,
  });

  final List<SourceCredit> sources;

  /// The OFL text of each font family, shown unchanged after the sources.
  final List<String> fontLicences;
  final bool linkFailed;
  final void Function(SourceCredit source) onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: SettingsMetrics.content,
      children: [
        if (linkFailed) ...[
          Semantics(
            container: true,
            liveRegion: true,
            child: IntegrityAlert(
              title: AppLocalizations.of(context).connectionFailed,
            ),
          ),
          const SizedBox(height: SettingsMetrics.contentGap),
        ],
        for (var i = 0; i < sources.length; i++)
          _SourceRow(
            source: sources[i],
            last: i == sources.length - 1 && fontLicences.isEmpty,
            onOpen: () => onOpen(sources[i]),
          ),
        for (var i = 0; i < fontLicences.length; i++)
          _LicenceRow(
            text: fontLicences[i],
            last: i == fontLicences.length - 1,
          ),
        const SizedBox(height: AppSpacing.space5),
      ],
    );
  }
}

class _LicenceRow extends StatelessWidget {
  const _LicenceRow({required this.text, required this.last});

  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _RowFrame(
      last: last,
      children: [
        // The licence is English and reads left to right.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            text,
            style: AppTextStyles.secondary.copyWith(color: colors.inkMuted),
          ),
        ),
      ],
    );
  }
}

class _RowFrame extends StatelessWidget {
  const _RowFrame({required this.last, required this.children});

  final bool last;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: context.colors.line)),
      ),
      child: Padding(
        padding: SourcesMetrics.rowPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: SourcesMetrics.rowGap,
          children: children,
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.source,
    required this.last,
    required this.onOpen,
  });

  final SourceCredit source;
  final bool last;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final licence = source.licenceText;
    final notice = source.notice;
    final secondary = AppTextStyles.secondary.copyWith(color: colors.inkMuted);
    final details = [
      ?source.publisher,
      ?source.version,
    ].join(AppLocalizations.of(context).dataSeparator);
    return _RowFrame(
      last: last,
      children: [
        Semantics(
          header: true,
          child: Text(
            source.name,
            style: AppTextStyles.bodyStrong.copyWith(color: colors.ink),
          ),
        ),
        if (details.isNotEmpty) Text(details, style: secondary),
        // A web address reads left to right inside the right-to-left screen.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Button(
              label: source.url,
              variant: ButtonVariant.text,
              onPressed: onOpen,
            ),
          ),
        ),
        if (licence != null) _OwnDirectionText(licence, style: secondary),
        if (notice != null) _OwnDirectionText(notice, style: secondary),
      ],
    );
  }
}

/// A text from a pack, laid out in the direction of its own words, so Latin
/// text ending in a full stop is not mirrored on this right-to-left screen.
class _OwnDirectionText extends StatelessWidget {
  const _OwnDirectionText(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: Bidi.detectRtlDirectionality(text)
        ? TextDirection.rtl
        : TextDirection.ltr,
    child: Text(text, style: style),
  );
}
