import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/metrics/search_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/button.dart';

/// The recent queries (`SR-10`), newest first, under their title and the
/// button that clears them. A query is the user's own text, so it is shown
/// as typed. Choosing one calls [onChoose] with it.
class SearchHistorySliver extends StatelessWidget {
  const SearchHistorySliver({
    required this.queries,
    required this.onChoose,
    required this.onClear,
    super.key,
  });

  final List<String> queries;
  final ValueChanged<String> onChoose;
  final VoidCallback? onClear;

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
