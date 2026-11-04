import 'package:flutter/material.dart' hide IconButton;

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/metrics/resources_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/features/resources/view_models/recitation_section_view_model.dart';
import 'package:holyquran/ui/features/resources/view_models/resources_view_model.dart';
import 'package:holyquran/ui/features/resources/views/sections/pack_category_section.dart';
import 'package:holyquran/ui/features/resources/views/sections/recitation_section.dart';

/// «مدير الموارد» (`OF-01`), laid out as «خطة الحفظ» of the Search board:
/// a back button and the title, then a section per category that holds
/// packs.
/// A null [viewModel] means the app provides no catalogue or installer
/// yet; the screen then shows its title alone. [recitations] is the
/// recitations section (`AU-13`), null while the app provides no downloads
/// of audio.
class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({required this.viewModel, this.recitations, super.key});

  final ResourcesViewModel? viewModel;
  final RecitationSectionViewModel? recitations;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final viewModel = this.viewModel;
    return ColoredBox(
      color: colors.ground,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: resourcesHeaderPadding,
              child: Row(
                spacing: resourcesHeaderGap,
                children: [
                  IconButton(
                    icon: IconName.previous,
                    label: l10n.back,
                    tone: IconButtonTone.tint,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.resourceManagerTitle,
                        style: resourcesTitleStyle.copyWith(color: colors.ink),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: viewModel == null
                  ? const SizedBox.shrink()
                  : ListenableBuilder(
                      listenable: viewModel,
                      builder: (context, _) =>
                          _Body(viewModel: viewModel, recitations: recitations),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.viewModel, required this.recitations});

  final ResourcesViewModel viewModel;
  final RecitationSectionViewModel? recitations;

  @override
  Widget build(BuildContext context) {
    final storageBytes = viewModel.storageBytes;
    return ListView(
      padding: resourcesBodyPadding,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: resourcesBlockGap,
          children: [
            if (viewModel.unreachable)
              IntegrityAlert(
                title: AppLocalizations.of(context).connectionFailed,
              ),
            if (recitations case final recitations?)
              RecitationSection(
                viewModel: recitations,
                storageBytes: storageBytes,
              ),
            for (final section in viewModel.sections)
              PackCategorySection(
                key: ValueKey(section.kind),
                section: section,
                storageBytes: storageBytes,
                viewModel: viewModel,
              ),
          ],
        ),
      ],
    );
  }
}
