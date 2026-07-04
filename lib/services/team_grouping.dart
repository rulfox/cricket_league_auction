import '../models/player_auction_record.dart';
import '../models/team_export_row.dart';
import '../models/team_roster_export_item.dart';
import '../state/auction_state.dart';

/// Every sold player across every team, no scope filter — the shared source
/// for every "all teams" export path (Complete Excel, Complete Photo).
List<TeamExportRow> allSoldRows(AuctionState state) {
  final rows = <TeamExportRow>[];
  for (final player in state.players) {
    final record = state.recordFor(state.keyFor(player));
    if (record.status != AuctionStatus.sold) continue;
    final teamId = record.teamId;
    if (teamId == null) continue;
    rows.add(TeamExportRow(
      teamId: teamId,
      teamName: state.teamNameFor(teamId) ?? 'Unknown',
      player: player,
      bidAmount: record.soldPoints ?? 0,
    ));
  }
  return rows;
}

/// Groups [rows] by team, ordered to match [AuctionState.teams], skipping
/// any team with zero sold players entirely (never emitted as an empty item).
List<TeamRosterExportItem> groupRowsByTeam(List<TeamExportRow> rows, AuctionState state) {
  final byTeamId = <String, List<TeamExportRow>>{};
  for (final row in rows) {
    (byTeamId[row.teamId] ??= []).add(row);
  }

  final items = <TeamRosterExportItem>[];
  for (final team in state.teams) {
    final teamRows = byTeamId[team.id];
    if (teamRows == null || teamRows.isEmpty) continue;
    items.add(TeamRosterExportItem(teamId: team.id, teamName: team.name, rows: teamRows));
  }
  return items;
}
