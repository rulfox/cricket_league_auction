import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auction_settings.dart';
import '../models/player.dart';
import '../models/player_auction_record.dart';
import '../services/bidding_rules.dart';
import '../state/auction_state.dart';
import '../theme.dart';
import 'auction_status_pill.dart';

/// Bidding controls for the currently displayed player: team dropdown, bid
/// amount, mode-aware validation, and Mark Sold/Unsold/Reopen actions.
/// Opened on demand from the home screen's Bid/Edit FAB inside a
/// `showModalBottomSheet`, so it never reserves permanent screen space and
/// stays structurally outside the card's capture boundary.
class BidControlBar extends StatefulWidget {
  const BidControlBar({super.key, required this.playerId, this.player});

  final String playerId;

  /// Optional — purely for the header (photo/name/category). All state
  /// mutations key off [playerId], never off this object.
  final Player? player;

  @override
  State<BidControlBar> createState() => _BidControlBarState();
}

class _BidControlBarState extends State<BidControlBar> {
  String? _selectedTeamId;
  final TextEditingController _bidController = TextEditingController();
  bool _allowExtraBid = false;

  @override
  void initState() {
    super.initState();
    _resetForCurrentPlayer();
  }

  @override
  void didUpdateWidget(covariant BidControlBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playerId != widget.playerId) {
      _resetForCurrentPlayer();
    }
  }

  @override
  void dispose() {
    _bidController.dispose();
    super.dispose();
  }

  void _resetForCurrentPlayer() {
    final auctionState = context.read<AuctionState>();
    final record = auctionState.recordFor(widget.playerId);
    _selectedTeamId = record.teamId;
    _bidController.text =
        (record.soldPoints ?? auctionState.settings.minBasePoint).toString();
    _allowExtraBid = false;
  }

  Widget _dragHandle(ColorScheme colorScheme) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _sheetContainer(BuildContext context, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auctionState = context.watch<AuctionState>();
    final record = auctionState.recordFor(widget.playerId);
    final teams = auctionState.teams;
    final bidAmount = int.tryParse(_bidController.text) ?? 0;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    BidValidationResult? validation;
    if (_selectedTeamId != null) {
      validation = auctionState.evaluateBidFor(
        playerId: widget.playerId,
        teamId: _selectedTeamId!,
        bidAmount: bidAmount,
        allowExtraBidChecked: _allowExtraBid,
      );
    }

    if (teams.isEmpty) {
      return _sheetContainer(
        context,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dragHandle(colorScheme),
            Icon(Icons.groups_outlined, size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('No teams yet', style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Add at least one team in Settings to start bidding.',
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final teamName = auctionState.teamNameFor(record.teamId);
    final player = widget.player;

    return _sheetContainer(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dragHandle(colorScheme),
          if (player != null) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: AssetImage(player.getPlayerPhoto()),
                  onBackgroundImageError: (_, __) {},
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(player.getPlayerName(), style: textTheme.titleLarge),
                      Text(
                        '#${player.getPlayerId()} · ${player.getCategory()}',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AuctionStatusPill(
                  status: record.status,
                  teamName: teamName,
                  bidAmount: record.soldPoints,
                  isExtraBid: record.isExtraBid,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  // Re-seeds `initialValue` whenever the displayed player
                  // changes (DropdownButtonFormField only reads
                  // initialValue once per FormField instance).
                  key: ValueKey(widget.playerId),
                  initialValue: _selectedTeamId,
                  decoration: const InputDecoration(
                    labelText: 'Team',
                    prefixIcon: Icon(Icons.groups_outlined),
                  ),
                  items: teams
                      .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedTeamId = value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _bidController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Bid',
                    prefixIcon: Icon(Icons.paid_outlined),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          if (validation?.blockReason != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (validation!.isAllowed ? kStatusWarning : kStatusDanger)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (validation.isAllowed ? kStatusWarning : kStatusDanger)
                      .withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    validation.isAllowed ? Icons.info_outline : Icons.error_outline,
                    color: validation.isAllowed ? kStatusWarning : kStatusDanger,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      validation.blockReason!,
                      style: textTheme.bodySmall?.copyWith(
                        color: validation.isAllowed ? kStatusWarning : kStatusDanger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (validation?.requiresExtraBidCheckbox ?? false)
            CheckboxListTile(
              value: _allowExtraBid,
              onChanged: (value) => setState(() => _allowExtraBid = value ?? false),
              title: const Text('Allow extra bidding'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          if (auctionState.settings.mode == AuctionMode.strictPurse &&
              validation?.maxAllowedBid != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'Max bid: ${validation!.maxAllowedBid}',
                    style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  onPressed: (_selectedTeamId != null && (validation?.isAllowed ?? false))
                      ? () async {
                          final navigator = Navigator.of(context);
                          await auctionState.markSold(
                            playerId: widget.playerId,
                            teamId: _selectedTeamId!,
                            bidAmount: bidAmount,
                            isExtraBid: validation!.requiresExtraBidCheckbox && _allowExtraBid,
                          );
                          if (!mounted) return;
                          navigator.pop();
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: kStatusSold,
                    minimumSize: const Size(0, 48),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(record.status == AuctionStatus.sold ? 'Update Sale' : 'Mark Sold'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    await auctionState.markUnsold(widget.playerId);
                    if (!mounted) return;
                    navigator.pop();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kStatusWarning,
                    side: const BorderSide(color: kStatusWarning),
                    minimumSize: const Size(0, 48),
                  ),
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Mark Unsold'),
                ),
              ),
              if (record.status != AuctionStatus.available) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextButton.icon(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      await auctionState.resetToAvailable(widget.playerId);
                      if (!mounted) return;
                      navigator.pop();
                    },
                    style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                    icon: const Icon(Icons.replay),
                    label: const Text('Reopen'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
