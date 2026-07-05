import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/team_export_row.dart';
import '../models/team_roster_export_item.dart';
import '../services/capture_service.dart';
import '../services/excel_export_service.dart';
import '../services/face_crop_service.dart';
import '../services/file_naming.dart';
import '../services/team_grouping.dart';
import '../services/web_download.dart';
import '../state/auction_state.dart';
import '../widgets/confirm_export_dialog.dart';
import '../widgets/export_progress_overlay.dart';
import '../widgets/team_roster_card.dart';

/// Teamwise auction-results export: every team's complete roster, as an
/// Excel workbook or as a roster-image ZIP. Viewing a single team's detail
/// lives on the Auction Summary dashboard — this screen is export-only.
class TeamsExportScreen extends StatefulWidget {
  const TeamsExportScreen({super.key});

  @override
  State<TeamsExportScreen> createState() => _TeamsExportScreenState();
}

class _TeamsExportScreenState extends State<TeamsExportScreen> {
  final GlobalKey _captureKey = GlobalKey();
  final CaptureService _captureService = const CaptureService();
  final ExcelExportService _excelService = ExcelExportService();

  Widget? _captureContent;
  double _captureHeight = 900;
  bool _isCapturing = false;
  bool _packaging = false;
  int _captureProgress = 0;
  int _captureTotal = 0;
  bool _showPhone = true;
  bool _showPoints = true;

  Future<Map<String, Alignment>> _alignmentsFor(List<TeamExportRow> rows) async {
    final entries = await Future.wait(rows.map((r) async => MapEntry(
          r.player.getPlayerId(),
          await FaceCropService.instance.alignmentFor(r.player),
        )));
    return Map.fromEntries(entries);
  }

  Future<void> _awaitPaintedFrame() async {
    await WidgetsBinding.instance.endOfFrame;
    WidgetsBinding.instance.scheduleFrame();
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _exportCompleteExcel() async {
    if (!await confirmExport(context) || !mounted) return;
    final auctionState = context.read<AuctionState>();
    final teams = groupRowsByTeam(allSoldRows(auctionState), auctionState);
    final bytes = _excelService.buildCompleteWorkbook(teams);
    await downloadBytes(bytes, 'all_teams_complete.xlsx');
  }

  Future<void> _exportCompletePhoto() async {
    if (!await confirmExport(context) || !mounted) return;
    final auctionState = context.read<AuctionState>();
    final teams = groupRowsByTeam(allSoldRows(auctionState), auctionState);
    if (teams.isEmpty) return;

    setState(() {
      _isCapturing = true;
      _packaging = false;
      _captureProgress = 0;
      _captureTotal = teams.length;
    });

    final zipBytes = await _captureService.captureSequenceAsZip<TeamRosterExportItem>(
      items: teams,
      boundaryKey: _captureKey,
      prepareFrame: (team) async {
        // Decode every photo into the image cache BEFORE swapping in this
        // team's card, so the first (and only) paint we capture shows real
        // photos instead of blank placeholders. Tolerate undecodable assets
        // so one bad image can't blank out an otherwise-good export.
        for (final row in team.rows) {
          if (!mounted) return;
          try {
            await precacheImage(TeamRosterCard.photoProviderFor(row.player), context);
          } catch (_) {}
        }
        if (!mounted) return;
        final alignments = await _alignmentsFor(team.rows);
        setState(() {
          _captureContent = TeamRosterCard(
            teamName: team.teamName,
            rows: team.rows,
            alignments: alignments,
            showPhone: _showPhone,
            showPoints: _showPoints,
          );
          _captureHeight = TeamRosterCard.heightFor(team.rows.length);
        });
        await _awaitPaintedFrame();
      },
      fileNameFor: (team) => '${sanitizeFileSegment(team.teamName)}.png',
      onProgress: (completed, total) => setState(() => _captureProgress = completed),
    );

    setState(() => _packaging = true);
    await WidgetsBinding.instance.endOfFrame;

    await downloadBytes(zipBytes, 'all_teams_complete.zip');

    setState(() {
      _isCapturing = false;
      _packaging = false;
      _captureContent = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auctionState = context.watch<AuctionState>();
    final rows = allSoldRows(auctionState);

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Auction Results Export')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
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
                          Icon(Icons.image_outlined, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text('Roster image options', style: textTheme.titleMedium),
                        ],
                      ),
                      CheckboxListTile(
                        value: _showPhone,
                        onChanged: (value) => setState(() => _showPhone = value ?? true),
                        title: const Text('Show phone number'),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        value: _showPoints,
                        onChanged: (value) => setState(() => _showPoints = value ?? true),
                        title: const Text('Show bid points'),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
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
                          Text('Team Rosters', style: textTheme.titleMedium),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 28),
                        child: Text(
                          'Excel: one sheet, teamwise · Photo: one roster image per team, zipped',
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
                              label: const Text('All teams (ZIP)'),
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
          // viewport and outside every visible export control. Height is
          // dynamic (see TeamRosterCard.heightFor) since a roster grid's size
          // depends on how many players are on the team being captured.
          Positioned(
            left: -5000,
            top: 0,
            child: SizedBox(
              width: 1600,
              height: _captureHeight,
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
