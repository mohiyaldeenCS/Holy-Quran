import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/metrics/search_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';

/// The recent queries (`SR-10`), newest first, under their title and the
/// button that clears them. A query is the user's own text, so it is shown
/// as typed. Choosing one calls [onChoose] with it.
class SearchHistorySliver extends StatelessWidget {
  const SearchHistorySliver({
    required this.queries,
    required this.onChoose,
    required this.onClear,
    required this.clearFailed,
    super.key,
  });

  final List<String> queries;
  final ValueChanged<String> onChoose;
  final VoidCallback? onClear;

  /// Whether the last clearing failed, which the list says in words.
  final bool clearFailed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final onClear = this.onClear;
    return SliverPadding(
      padding: SearchMetrics.history,
      sliver: SliverList.list(
        children: [
          Row(
            spacing: AppSpacing.space3,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.searchHistoryTitle,
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: context.colors.ink,
                    ),
                  ),
                ),
              ),
              if (onClear != null)
                Button(
                  label: l10n.searchHistoryClear,
                  variant: ButtonVariant.text,
                  onPressed: onClear,
                ),
            ],
          ),
          if (clearFailed) ...[
            const SizedBox(height: SearchMetrics.historyGap),
            Semantics(
              liveRegion: true,
              container: true,
              child: IntegrityAlert(body: l10n.changeNotSaved),
            ),
          ],
          for (final query in queries) ...[
            const SizedBox(height: SearchMetrics.historyGap),
            Button(
              label: query,
              variant: ButtonVariant.outline,
              onPressed: () => onChoose(query),
            ),
          ],
        ],
      ),
    );
  }
}
