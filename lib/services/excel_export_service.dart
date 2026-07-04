import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/team_export_row.dart';

/// Builds simple, data-only .xlsx workbooks for teamwise auction exports —
/// no embedded photos, kept intentionally fast and dependency-light.
class ExcelExportService {
  static const _sheetName = 'Sheet1';

  Uint8List buildMinimalWorkbook(List<TeamExportRow> rows) {
    final excel = Excel.createExcel();
    final sheet = excel[_sheetName];
    sheet.appendRow([
      TextCellValue('Sl No'),
      TextCellValue('Name'),
      TextCellValue('Phone'),
      TextCellValue('Points'),
    ]);
    for (final row in rows) {
      sheet.appendRow([
        TextCellValue(row.player.getPlayerId()),
        TextCellValue(row.player.getPlayerName()),
        TextCellValue(row.player.getPhoneNumber()),
        IntCellValue(row.bidAmount),
      ]);
    }
    return Uint8List.fromList(excel.encode()!);
  }

  Uint8List buildCompleteWorkbook(List<TeamExportRow> rows) {
    final excel = Excel.createExcel();
    final sheet = excel[_sheetName];
    sheet.appendRow([
      TextCellValue('Team'),
      TextCellValue('Sl No'),
      TextCellValue('Name'),
      TextCellValue('Phone'),
      TextCellValue('Points'),
    ]);
    for (final row in rows) {
      sheet.appendRow([
        TextCellValue(row.teamName),
        TextCellValue(row.player.getPlayerId()),
        TextCellValue(row.player.getPlayerName()),
        TextCellValue(row.player.getPhoneNumber()),
        IntCellValue(row.bidAmount),
      ]);
    }
    return Uint8List.fromList(excel.encode()!);
  }
}
