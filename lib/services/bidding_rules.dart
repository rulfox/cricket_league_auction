import 'dart:math';

import '../models/auction_settings.dart';
import '../models/player_auction_record.dart';

/// Purse math for one team, always derived fresh from the full records list
/// plus current settings — never stored/incremented, so reassigning or
/// reopening a sale can never leave stale counters behind.
class TeamPurseSummary {
  const TeamPurseSummary({
    required this.totalSpent,
    required this.remainingPurse,
    required this.extraPointsUsed,
    required this.playersBought,
  });

  /// Sum of soldPoints across this team's sold records. Can exceed the purse
  /// (that's exactly what an extra-bid sale means).
  final int totalSpent;

  /// max(0, purse - totalSpent) — the real, meaningful "points remaining"
  /// figure, even after an extra-bid sale has technically overspent.
  final int remainingPurse;

  /// max(0, totalSpent - purse) — how far over purse this team currently is.
  final int extraPointsUsed;

  final int playersBought;

  static const zero = TeamPurseSummary(
    totalSpent: 0,
    remainingPurse: 0,
    extraPointsUsed: 0,
    playersBought: 0,
  );
}

TeamPurseSummary computeTeamPurseSummary({
  required String teamId,
  required Iterable<PlayerAuctionRecord> records,
  required AuctionSettings settings,
}) {
  int totalSpent = 0;
  int playersBought = 0;
  for (final record in records) {
    if (record.status == AuctionStatus.sold && record.teamId == teamId) {
      totalSpent += record.soldPoints ?? 0;
      playersBought += 1;
    }
  }
  final remainingPurse = max(0, settings.totalPurse - totalSpent);
  final extraPointsUsed = max(0, totalSpent - settings.totalPurse);
  return TeamPurseSummary(
    totalSpent: totalSpent,
    remainingPurse: remainingPurse,
    extraPointsUsed: extraPointsUsed,
    playersBought: playersBought,
  );
}

class BidValidationResult {
  const BidValidationResult({
    required this.isAllowed,
    required this.requiresExtraBidCheckbox,
    required this.remainingPurseBeforeBid,
    this.maxAllowedBid,
    this.blockReason,
  });

  final bool isAllowed;

  /// Standard mode only: true when the bid exceeds the team's remaining
  /// purse, meaning the "Allow extra bidding" checkbox must be shown/ticked
  /// for the sale to proceed.
  final bool requiresExtraBidCheckbox;

  final int remainingPurseBeforeBid;

  /// Strict Purse Mode only: the hard cap for this bid. Null in standard
  /// mode, where there is no cap once extra bidding is allowed.
  final int? maxAllowedBid;

  final String? blockReason;
}

/// Strict Purse Mode: caps the current bid so enough points stay reserved
/// (at [AuctionSettings.minBasePoint] each) for every player slot still
/// needed after this one.
int computeMaxAllowedBid({
  required TeamPurseSummary purseSummaryBeforeThisSale,
  required AuctionSettings settings,
}) {
  final slotsRemainingAfterThis =
      settings.playersPerTeam - purseSummaryBeforeThisSale.playersBought - 1;
  final reserve = max(0, slotsRemainingAfterThis) * settings.minBasePoint;
  return max(0, purseSummaryBeforeThisSale.remainingPurse - reserve);
}

BidValidationResult evaluateBid({
  required int bidAmount,
  required TeamPurseSummary purseSummaryBeforeThisSale,
  required AuctionSettings settings,
  required bool allowExtraBidChecked,
}) {
  final remaining = purseSummaryBeforeThisSale.remainingPurse;

  if (bidAmount < 0) {
    return BidValidationResult(
      isAllowed: false,
      requiresExtraBidCheckbox: false,
      remainingPurseBeforeBid: remaining,
      blockReason: 'Bid amount cannot be negative.',
    );
  }

  if (settings.mode == AuctionMode.strictPurse) {
    final maxAllowedBid = computeMaxAllowedBid(
      purseSummaryBeforeThisSale: purseSummaryBeforeThisSale,
      settings: settings,
    );
    final isAllowed = bidAmount <= maxAllowedBid;
    return BidValidationResult(
      isAllowed: isAllowed,
      requiresExtraBidCheckbox: false,
      remainingPurseBeforeBid: remaining,
      maxAllowedBid: maxAllowedBid,
      blockReason: isAllowed
          ? null
          : 'Bid exceeds the max allowed bid of $maxAllowedBid (points must stay reserved for remaining player slots).',
    );
  }

  // Standard mode.
  if (bidAmount <= remaining) {
    return BidValidationResult(
      isAllowed: true,
      requiresExtraBidCheckbox: false,
      remainingPurseBeforeBid: remaining,
    );
  }

  return BidValidationResult(
    isAllowed: allowExtraBidChecked,
    requiresExtraBidCheckbox: true,
    remainingPurseBeforeBid: remaining,
    blockReason: allowExtraBidChecked
        ? null
        : 'Team has only $remaining points left, bid is $bidAmount. Check "Allow extra bidding" to proceed.',
  );
}
