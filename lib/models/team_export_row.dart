import 'player.dart';

/// Flat, export-ready view of one sold player, used by both the Excel and
/// photo/zip export services so they don't need to know about [AuctionState].
class TeamExportRow {
  const TeamExportRow({
    required this.teamId,
    required this.teamName,
    required this.player,
    required this.bidAmount,
  });

  final String teamId;
  final String teamName;
  final Player player;
  final int bidAmount;
}
