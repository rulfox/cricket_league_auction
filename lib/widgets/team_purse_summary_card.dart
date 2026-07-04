import 'package:flutter/material.dart';

import '../services/bidding_rules.dart';
import '../theme.dart';

/// Content-only purse/roster stat block for one team — team name, a
/// players-bought progress bar, a color-coded remaining-purse row, and an
/// extra-points-used pill when applicable. Callers own their own container
/// (a standalone `Card` in `TeamsExportScreen`, combined with a roster grid
/// inside one `Card` in `AuctionSummaryScreen`).
class TeamPurseSummaryCard extends StatelessWidget {
  const TeamPurseSummaryCard({
    super.key,
    required this.teamName,
    required this.summary,
    required this.targetPlayerCount,
  });

  final String teamName;
  final TeamPurseSummary summary;
  final int targetPlayerCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final purseIsHealthy = summary.extraPointsUsed == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(teamName, style: textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '${summary.playersBought} / $targetPlayerCount players bought',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: targetPlayerCount == 0 ? 0 : summary.playersBought / targetPlayerCount,
            minHeight: 8,
            backgroundColor: colorScheme.surfaceContainerHighest,
            color: summary.playersBought >= targetPlayerCount ? kStatusSold : null,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.payments_outlined, size: 16, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text('Spent', style: textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('${summary.totalSpent}', style: textTheme.titleLarge),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: VerticalDivider(width: 24, color: colorScheme.outlineVariant),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.savings_outlined, size: 16, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text('Remaining', style: textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${summary.remainingPurse}',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: purseIsHealthy ? kStatusSold : kStatusWarning,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (summary.extraPointsUsed > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kStatusWarning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.trending_up, size: 16, color: kStatusWarning),
                  const SizedBox(width: 6),
                  Text(
                    'Extra points used: ${summary.extraPointsUsed}',
                    style: textTheme.bodySmall?.copyWith(color: kStatusWarning),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
