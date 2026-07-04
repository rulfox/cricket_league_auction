import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player.dart';
import '../models/player_auction_record.dart';
import '../models/team_export_row.dart';
import '../services/bidding_rules.dart';
import '../services/team_grouping.dart';
import '../state/auction_state.dart';
import '../theme.dart';
import '../widgets/auction_player_tile.dart';
import '../widgets/team_purse_summary_card.dart';
import 'settings_screen.dart';

/// Live, read-only overview of the entire auction: every team's roster with
/// purse stats, unsold players, and players still to be auctioned. Reacts
/// automatically to bids made anywhere else in the app (via
/// `context.watch<AuctionState>()`) — no manual refresh needed, making it
/// suitable to leave open on a second monitor/projector during a live
/// auction.
class AuctionSummaryScreen extends StatelessWidget {
  const AuctionSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auctionState = context.watch<AuctionState>();
    final teams = auctionState.teams;

    final rowsByTeamId = <String, List<TeamExportRow>>{};
    for (final row in allSoldRows(auctionState)) {
      (rowsByTeamId[row.teamId] ??= []).add(row);
    }
    for (final rows in rowsByTeamId.values) {
      rows.sort((a, b) => b.bidAmount.compareTo(a.bidAmount));
    }

    final unsold = <Player>[];
    final notAuctioned = <Player>[];
    for (final player in auctionState.players) {
      final record = auctionState.recordFor(auctionState.keyFor(player));
      switch (record.status) {
        case AuctionStatus.unsold:
          unsold.add(player);
        case AuctionStatus.available:
          notAuctioned.add(player);
        case AuctionStatus.sold:
          break;
      }
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final totalSold = rowsByTeamId.values.fold(0, (sum, rows) => sum + rows.length);
    final totalRemainingPurse = teams.fold(
      0,
      (sum, t) => sum + auctionState.purseSummaryFor(t.id).remainingPurse,
    );
    final totalPlayers = auctionState.players.length;
    final decidedPlayers = totalSold + unsold.length;
    final completionPercent =
        totalPlayers == 0 ? 0 : ((decidedPlayers / totalPlayers) * 100).round();

    return Scaffold(
      appBar: AppBar(title: const Text('Auction Summary')),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _KpiStat(
                        icon: Icons.emoji_events_outlined,
                        value: '$totalSold',
                        label: 'Players Sold',
                      ),
                      _KpiStat(
                        icon: Icons.savings_outlined,
                        value: '$totalRemainingPurse',
                        label: 'Purse Remaining',
                      ),
                      _KpiStat(
                        icon: Icons.pending_actions_outlined,
                        value: '$completionPercent%',
                        label: 'Complete',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          if (teams.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _EmptyTeamsCard(),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    for (final team in teams)
                      _TeamSection(
                        teamName: team.name,
                        summary: auctionState.purseSummaryFor(team.id),
                        targetPlayerCount: auctionState.settings.playersPerTeam,
                        rows: rowsByTeamId[team.id] ?? const [],
                        auctionState: auctionState,
                      ),
                  ],
                ),
              ),
            ),
          if (unsold.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.remove_circle_outline, color: kStatusDanger),
                            const SizedBox(width: 8),
                            Text('Unsold Players', style: textTheme.titleLarge),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final player in unsold)
                              AuctionPlayerTile(
                                key: ValueKey(auctionState.keyFor(player)),
                                player: player,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.pending_actions_outlined, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Players Not Auctioned (${notAuctioned.length})',
                    style: textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ),
          if (notAuctioned.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: kStatusSold),
                    const SizedBox(width: 8),
                    Text('All players have been auctioned.', style: textTheme.bodyMedium),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 110,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.68,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final player = notAuctioned[index];
                    return AuctionPlayerTile(
                      key: ValueKey(auctionState.keyFor(player)),
                      player: player,
                      compact: true,
                    );
                  },
                  childCount: notAuctioned.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _TeamSection extends StatelessWidget {
  const _TeamSection({
    required this.teamName,
    required this.summary,
    required this.targetPlayerCount,
    required this.rows,
    required this.auctionState,
  });

  final String teamName;
  final TeamPurseSummary summary;
  final int targetPlayerCount;
  final List<TeamExportRow> rows;
  final AuctionState auctionState;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TeamPurseSummaryCard(
              teamName: teamName,
              summary: summary,
              targetPlayerCount: targetPlayerCount,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    'No players sold yet',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final (index, row) in rows.indexed)
                    AuctionPlayerTile(
                      key: ValueKey(auctionState.keyFor(row.player)),
                      player: row.player,
                      bidAmount: row.bidAmount,
                      isTopBid: index == 0,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _KpiStat extends StatelessWidget {
  const _KpiStat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: textTheme.bodySmall),
      ],
    );
  }
}

class _EmptyTeamsCard extends StatelessWidget {
  const _EmptyTeamsCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.groups_outlined, size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'No teams yet. Add teams in Settings to begin the auction.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ),
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
