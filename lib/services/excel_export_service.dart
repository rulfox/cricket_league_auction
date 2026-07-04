import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/team_export_row.dart';
import '../models/team_roster_export_item.dart';

/// Builds simple, data-only .xlsx workbooks for teamwise auction exports —
/// no embedded photos, kept intentionally fast and dependency-light.
class ExcelExportService {
  static const _sheetName = 'Sheet1';
  static List<CellValue> get _columnHeaders => [
        TextCellValue('Sl No'),
        TextCellValue('Name'),
        TextCellValue('Phone'),
        TextCellValue('Points'),
      ];

  void _appendPlayerRows(Sheet sheet, List<TeamExportRow> rows) {
    for (final row in rows) {
      sheet.appendRow([
        TextCellValue(row.player.getPlayerId()),
        TextCellValue(row.player.getPlayerName()),
        TextCellValue(row.player.getPhoneNumber()),
        IntCellValue(row.bidAmount),
      ]);
    }
  }

  /// One sheet, all teams, "teamwise categorized": a bold team-name header
  /// row precedes each team's column-header row + player rows, with a
  /// blank spacer row before the next team.
  Uint8List buildCompleteWorkbook(List<TeamRosterExportItem> teams) {
    final excel = Excel.createExcel();
    final sheet = excel[_sheetName];

    for (final team in teams) {
      final headerRow = sheet.maxRows;
      sheet.appendRow([TextCellValue(team.teamName)]);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: headerRow))
          .cellStyle = CellStyle(bold: true);

      sheet.appendRow(_columnHeaders);
      _appendPlayerRows(sheet, team.rows);
      sheet.appendRow(const []);
    }

    return Uint8List.fromList(excel.encode()!);
  }
}
