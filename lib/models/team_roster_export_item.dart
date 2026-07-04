import 'team_export_row.dart';

/// One team's worth of sold players, ready to render as a roster
/// image/Excel block — produced by `services/team_grouping.dart`.
class TeamRosterExportItem {
  const TeamRosterExportItem({
    required this.teamId,
    required this.teamName,
    required this.rows,
  });

  final String teamId;
  final String teamName;
  final List<TeamExportRow> rows;
}
