import 'package:flutter/material.dart';

import '../models/player_auction_record.dart';

/// Small overlay badge showing a player's current auction status. Placed as
/// a Positioned sibling of the capture boundary on the home screen, so it's
/// visible while browsing but excluded from exported card images.
class AuctionStatusPill extends StatelessWidget {
  const AuctionStatusPill({
    super.key,
    required this.status,
    this.teamName,
    this.bidAmount,
    this.isExtraBid = false,
  });

  final AuctionStatus status;
  final String? teamName;
  final int? bidAmount;
  final bool isExtraBid;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    switch (status) {
      case AuctionStatus.available:
        label = 'Available';
        color = Colors.blueGrey;
        break;
      case AuctionStatus.sold:
        final teamPart = teamName != null ? ' to $teamName' : '';
        final bidPart = bidAmount != null ? ' for $bidAmount' : '';
        final extraPart = isExtraBid ? ' (extra)' : '';
        label = 'Sold$teamPart$bidPart$extraPart';
        color = Colors.green;
        break;
      case AuctionStatus.unsold:
        label = 'Unsold';
        color = Colors.redAccent;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}
