import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player_auction_record.dart';
import '../models/team_export_row.dart';
import '../services/capture_service.dart';
import '../services/excel_export_service.dart';
import '../services/file_naming.dart';
import '../services/web_download.dart';
import '../state/auction_state.dart';
import '../theme.dart';
import '../widgets/confirm_export_dialog.dart';
import '../widgets/export_progress_overlay.dart';
import '../widgets/sold_player_card.dart';
import '../widgets/team_data_table_card.dart';

const String _allTeamsScope = '__all__';

/// Teamwise auction-results export: pick a team (or all teams) and export
/// Minimal (name/sl no/phone/points) or Complete (+ team + photo) as Excel
/// or as an image/zip.
class TeamsExportScreen extends StatefulWidget {
  const TeamsExportScreen({super.key});

  @override
  State<TeamsExportScreen> createState() => _TeamsExportScreenState();
}

class _TeamsExportScreenState extends State<TeamsExportScreen> {
  String _selectedScope = _allTeamsScope;
  final GlobalKey _captureKey = GlobalKey();
  final CaptureService _captureService = const CaptureService();
  final ExcelExportService _excelService = ExcelExportService();

  Widget? _captureContent;
  bool _isCapturing = false;
  bool _packaging = false;
  int _captureProgress = 0;
  int _captureTotal = 0;

  List<TeamExportRow> _rowsForScope(AuctionState state) {
    final rows = <TeamExportRow>[];
    for (final player in state.players) {
      final record = state.recordFor(state.keyFor(player));
      if (record.status != AuctionStatus.sold) continue;
      if (_selectedScope != _allTeamsScope && record.teamId != _selectedScope) continue;
      rows.add(TeamExportRow(
        teamName: state.teamNameFor(record.teamId) ?? 'Unknown',
        player: player,
        bidAmount: record.soldPoints ?? 0,
      ));
    }
    return rows;
  }

  String _scopeFileLabel(AuctionState state) {
    if (_selectedScope == _allTeamsScope) return 'all_teams';
    return sanitizeFileSegment(state.teamNameFor(_selectedScope) ?? 'team');
  }

  Future<void> _exportMinimalExcel() async {
    if (!await confirmExport(context) || !mounted) return;
    final auctionState = context.read<AuctionState>();
    final bytes = _excelService.buildMinimalWorkbook(_rowsForScope(auctionState));
    await downloadBytes(bytes, '${_scopeFileLabel(auctionState)}_minimal.xlsx');
  }

  Future<void> _exportCompleteExcel() async {
    if (!await confirmExport(context) || !mounted) return;
    final auctionState = context.read<AuctionState>();
    final bytes = _excelService.buildCompleteWorkbook(_rowsForScope(auctionState));
    await downloadBytes(bytes, '${_scopeFileLabel(auctionState)}_complete.xlsx');
  }

  Future<void> _awaitPaintedFrame() async {
    await WidgetsBinding.instance.endOfFrame;
    WidgetsBinding.instance.scheduleFrame();
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _exportMinimalPhoto() async {
    if (_selectedScope == _allTeamsScope) return; // guarded by a disabled button
    if (!await confirmExport(context) || !mounted) return;
    final auctionState = context.read<AuctionState>();
    final teamName = auctionState.teamNameFor(_selectedScope);
    if (teamName == null) return;
    final rows = _rowsForScope(auctionState);

    setState(() => _captureContent = TeamDataTableCard(teamName: teamName, rows: rows));
    await _awaitPaintedFrame();
    final bytes = await _captureService.captureBoundary(_captureKey);
    setState(() => _captureContent = null);

    await downloadBytes(bytes, '${sanitizeFileSegment(teamName)}_minimal.png');
  }

  Future<void> _exportCompletePhoto() async {
    if (!await confirmExport(context) || !mounted) return;
    final auctionState = context.read<AuctionState>();
    final rows = _rowsForScope(auctionState);
    if (rows.isEmpty) return;

    setState(() {
      _isCapturing = true;
      _packaging = false;
      _captureProgress = 0;
      _captureTotal = rows.length;
    });

    final zipBytes = await _captureService.captureSequenceAsZip<TeamExportRow>(
      items: rows,
      boundaryKey: _captureKey,
      prepareFrame: (row) async {
        setState(() => _captureContent = SoldPlayerCard(
              player: row.player,
              teamName: row.teamName,
              bidAmount: row.bidAmount,
            ));
        await _awaitPaintedFrame();
      },
      fileNameFor: (row) => _selectedScope == _allTeamsScope
          ? '${sanitizeFileSegment(row.teamName)}/${row.player.getPlayerId()}.png'
          : '${row.player.getPlayerId()}.png',
      onProgress: (completed, total) => setState(() => _captureProgress = completed),
    );

    setState(() => _packaging = true);
    await WidgetsBinding.instance.endOfFrame;

    await downloadBytes(zipBytes, '${_scopeFileLabel(auctionState)}_complete.zip');

    setState(() {
      _isCapturing = false;
      _packaging = false;
      _captureContent = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auctionState = context.watch<AuctionState>();
    final teams = auctionState.teams;

    // Guard against a stale scope pointing at a since-deleted team.
    if (_selectedScope != _allTeamsScope && !teams.any((t) => t.id == _selectedScope)) {
      _selectedScope = _allTeamsScope;
    }

    final rows = _rowsForScope(auctionState);
    final summary = _selectedScope == _allTeamsScope
        ? null
        : auctionState.purseSummaryFor(_selectedScope);

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final purseIsHealthy = summary != null && summary.extraPointsUsed == 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Auction Results Export')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey(_selectedScope),
                initialValue: _selectedScope,
                decoration: const InputDecoration(
                  labelText: 'Team',
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
                items: [
                  const DropdownMenuItem(value: _allTeamsScope, child: Text('All Teams')),
                  ...teams.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                ],
                onChanged: (value) => setState(() => _selectedScope = value ?? _allTeamsScope),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: summary != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.account_balance_wallet_outlined,
                                    color: colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  auctionState.teamNameFor(_selectedScope) ?? '',
                                  style: textTheme.titleMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '${summary.playersBought} / ${auctionState.settings.playersPerTeam} players bought',
                              style: textTheme.bodySmall,
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: auctionState.settings.playersPerTeam == 0
                                    ? 0
                                    : summary.playersBought / auctionState.settings.playersPerTeam,
                                minHeight: 8,
                                backgroundColor: colorScheme.surfaceContainerHighest,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(Icons.savings_outlined, color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 8),
                                const Text('Remaining purse'),
                                const Spacer(),
                                Text(
                                  '${summary.remainingPurse}',
                                  style: textTheme.titleMedium?.copyWith(
                                    color: purseIsHealthy ? kStatusSold : kStatusWarning,
                                  ),
                                ),
                              ],
                            ),
                            if (summary.extraPointsUsed > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: kStatusWarning.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.trending_up, size: 16, color: kStatusWarning),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Extra points used: ${summary.extraPointsUsed}',
                                        style: textTheme.bodySmall?.copyWith(color: kStatusWarning),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        )
                      : Row(
                          children: [
                            Icon(Icons.emoji_events_outlined, color: colorScheme.primary, size: 32),
                            const SizedBox(width: 12),
                            Text('${rows.length}', style: textTheme.headlineSmall),
                            const SizedBox(width: 8),
                            const Expanded(child: Text('sold player(s) across all teams')),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.description_outlined, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text('Minimal', style: textTheme.titleMedium),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 28),
                        child: Text('Name, sl no, phone number, points', style: textTheme.bodySmall),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: rows.isEmpty ? null : _exportMinimalExcel,
                              icon: const Icon(Icons.grid_on),
                              label: const Text('Excel'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: (_selectedScope == _allTeamsScope || rows.isEmpty)
                                  ? null
                                  : _exportMinimalPhoto,
                              icon: const Icon(Icons.image_outlined),
                              label: const Text('Photo'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.fact_check_outlined, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text('Complete', style: textTheme.titleMedium),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 28),
                        child: Text(
                          'Team name, player photo, name, phone number, bid amount',
                          style: textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: rows.isEmpty ? null : _exportCompleteExcel,
                              icon: const Icon(Icons.grid_on),
                              label: const Text('Excel'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: rows.isEmpty ? null : _exportCompletePhoto,
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Photo (ZIP)'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Off-screen capture host: must be laid out/painted at least once for
          // RepaintBoundary.toImage to work, but stays outside the visible
          // viewport and outside every visible export control.
          Positioned(
            left: -5000,
            top: 0,
            child: SizedBox(
              width: 1600,
              height: 900,
              child: Material(
                child: RepaintBoundary(
                  key: _captureKey,
                  child: _captureContent ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          if (_isCapturing)
            ExportProgressOverlay(
              completed: _captureProgress,
              total: _captureTotal,
              packaging: _packaging,
            ),
        ],
      ),
    );
  }
}
