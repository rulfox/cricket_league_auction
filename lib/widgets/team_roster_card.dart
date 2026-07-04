import 'package:flutter/material.dart';

import '../models/team_export_row.dart';
import 'card_styled_text.dart';

/// A team's roster poster: branded header (logo + team name) followed by a
/// fixed-column grid of sold players (face-aligned photo, name, and
/// optionally phone/bid points). Captured as one static PNG via
/// `RepaintBoundary`, so the grid is built from literal `Row`s/`Column`s
/// (not a scrollable `GridView`) and [heightFor] lets the capture host size
/// itself correctly for any roster size.
class TeamRosterCard extends StatelessWidget {
  const TeamRosterCard({
    super.key,
    required this.teamName,
    required this.rows,
    required this.alignments,
    required this.showPhone,
    required this.showPoints,
  });

  final String teamName;
  final List<TeamExportRow> rows;

  /// Face-detection-biased alignment per player, keyed by [Player.getPlayerId].
  final Map<String, Alignment> alignments;
  final bool showPhone;
  final bool showPoints;

  static const int columns = 5;
  static const double _headerHeight = 180;
  static const double _tileWidth = 280;
  static const double _tileHeight = 360;
  static const double _photoHeight = 220;
  static const double _rowSpacing = 16;
  static const double _outerPadding = 24;

  /// Total canvas height needed to render a roster of [playerCount] players
  /// without clipping — used by the capture host to size its off-screen
  /// `SizedBox` before capturing (this widget's own width is always the
  /// fixed capture-canvas width, only height varies with roster size).
  static double heightFor(int playerCount) {
    if (playerCount <= 0) return _headerHeight + _outerPadding * 2;
    final rowCount = (playerCount / columns).ceil();
    final gridHeight = rowCount * _tileHeight + (rowCount - 1) * _rowSpacing;
    return _headerHeight + _outerPadding * 2 + gridHeight;
  }

  @override
  Widget build(BuildContext context) {
    final rowCount = (rows.length / columns).ceil();

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/images/background.png"),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
      ),
      padding: const EdgeInsets.all(_outerPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _headerHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  "assets/images/msl_logo.png",
                  height: 80,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 8),
                CardStyledText(teamName, fontSize: 64),
              ],
            ),
          ),
          const SizedBox(height: _rowSpacing),
          for (int r = 0; r < rowCount; r++) ...[
            if (r > 0) const SizedBox(height: _rowSpacing),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: _rowSpacing),
                  _tileOrFiller(r * columns + c),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _tileOrFiller(int index) {
    if (index >= rows.length) {
      return const SizedBox(width: _tileWidth);
    }
    final row = rows[index];
    return _RosterTile(
      row: row,
      alignment: alignments[row.player.getPlayerId()] ?? Alignment.center,
      showPhone: showPhone,
      showPoints: showPoints,
    );
  }
}

class _RosterTile extends StatelessWidget {
  const _RosterTile({
    required this.row,
    required this.alignment,
    required this.showPhone,
    required this.showPoints,
  });

  final TeamExportRow row;
  final Alignment alignment;
  final bool showPhone;
  final bool showPoints;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: TeamRosterCard._tileWidth,
      height: TeamRosterCard._tileHeight,
      // Defensive safety net: any residual overflow (e.g. an edge case not
      // fully covered by the maxLines/ellipsis below) is silently clipped
      // rather than painting the debug overflow stripes into the captured
      // export image.
      child: ClipRect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: TeamRosterCard._photoHeight,
                child: Image.asset(
                  row.player.getPlayerPhoto(),
                  fit: BoxFit.cover,
                  alignment: alignment,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.black26,
                    child: const Icon(Icons.person, color: Colors.white70, size: 48),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            CardStyledText(
              row.player.getPlayerName(),
              fontSize: 28,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (showPhone) ...[
              const SizedBox(height: 4),
              CardStyledText(
                row.player.getPhoneNumber(),
                fontSize: 18,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (showPoints) ...[
              const SizedBox(height: 4),
              CardStyledText(
                "${row.bidAmount} points",
                fontSize: 20,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
