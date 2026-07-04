import 'package:flutter/material.dart';

import '../models/team_export_row.dart';

/// Renders a team's sold-players table as a real, laid-out widget so it can
/// be captured to an image the same way a player card is (RepaintBoundary
/// needs at least one real layout+paint pass before `toImage` works).
class TeamDataTableCard extends StatelessWidget {
  const TeamDataTableCard({super.key, required this.teamName, required this.rows});

  final String teamName;
  final List<TeamExportRow> rows;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(teamName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            DataTable(
              columns: const [
                DataColumn(label: Text('Sl No')),
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Phone')),
                DataColumn(label: Text('Points')),
              ],
              rows: rows
                  .map((row) => DataRow(cells: [
                        DataCell(Text(row.player.getPlayerId())),
                        DataCell(Text(row.player.getPlayerName())),
                        DataCell(Text(row.player.getPhoneNumber())),
                        DataCell(Text(row.bidAmount.toString())),
                      ]))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
