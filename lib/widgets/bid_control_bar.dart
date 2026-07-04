import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auction_settings.dart';
import '../models/player_auction_record.dart';
import '../services/bidding_rules.dart';
import '../state/auction_state.dart';

/// Bidding controls for the currently displayed player: team dropdown, bid
/// amount, mode-aware validation, and Mark Sold/Unsold/Reopen actions.
/// Opened on demand from the home screen's Bid/Edit FAB inside a
/// `showModalBottomSheet`, so it never reserves permanent screen space and
/// stays structurally outside the card's capture boundary.
class BidControlBar extends StatefulWidget {
  const BidControlBar({super.key, required this.playerId});

  final String playerId;

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

  @override
  Widget build(BuildContext context) {
    final auctionState = context.watch<AuctionState>();
    final record = auctionState.recordFor(widget.playerId);
    final teams = auctionState.teams;
    final bidAmount = int.tryParse(_bidController.text) ?? 0;

    BidValidationResult? validation;
    if (_selectedTeamId != null) {
      validation = auctionState.evaluateBidFor(
        teamId: _selectedTeamId!,
        bidAmount: bidAmount,
        allowExtraBidChecked: _allowExtraBid,
      );
    }

    if (teams.isEmpty) {
      return const Material(
        elevation: 8,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Add at least one team in Settings to start bidding.'),
        ),
      );
    }

    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      // Re-seeds `initialValue` whenever the displayed player
                      // changes (DropdownButtonFormField only reads
                      // initialValue once per FormField instance).
                      key: ValueKey(widget.playerId),
                      initialValue: _selectedTeamId,
                      decoration: const InputDecoration(labelText: 'Team'),
                      items: teams
                          .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedTeamId = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _bidController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Bid'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              if (validation?.blockReason != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    validation!.blockReason!,
                    style: TextStyle(color: validation.isAllowed ? Colors.orange : Colors.red),
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Max bid: ${validation!.maxAllowedBid}',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_selectedTeamId != null && (validation?.isAllowed ?? false))
                          ? () async {
                              await auctionState.markSold(
                                playerId: widget.playerId,
                                teamId: _selectedTeamId!,
                                bidAmount: bidAmount,
                                isExtraBid: validation!.requiresExtraBidCheckbox && _allowExtraBid,
                              );
                              setState(() => _allowExtraBid = false);
                            }
                          : null,
                      child: Text(record.status == AuctionStatus.sold ? 'Update Sale' : 'Mark Sold'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => auctionState.markUnsold(widget.playerId),
                      child: const Text('Mark Unsold'),
                    ),
                  ),
                  if (record.status != AuctionStatus.available) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        onPressed: () => auctionState.resetToAvailable(widget.playerId),
                        child: const Text('Reopen'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
