import 'package:flutter/material.dart';

import '../models/player.dart';
import '../services/face_crop_service.dart';
import '../theme.dart';

/// One player tile for the read-only Auction Summary dashboard — reused for
/// team rosters (with a bid-amount pill), the Unsold section (no pill), and
/// the Not-Auctioned grid (smaller, `compact: true`, no pill regardless of
/// [bidAmount]). Deliberately has no `onTap` — this screen is read-only.
class AuctionPlayerTile extends StatelessWidget {
  const AuctionPlayerTile({
    super.key,
    required this.player,
    this.bidAmount,
    this.compact = false,
    this.isTopBid = false,
  });

  final Player player;

  /// Null hides the price pill entirely (Unsold / Not-Auctioned players).
  final int? bidAmount;

  /// Smaller tile, used only by the Not-Auctioned grid.
  final bool compact;

  /// True for a team's single most expensive sale — shows a small badge.
  final bool isTopBid;

  static const double _standardWidth = 148;
  static const double _compactWidth = 92;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final width = compact ? _compactWidth : _standardWidth;

    return Container(
      width: width,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _FaceAlignedPlayerPhoto(player: player),
                ),
              ),
              if (isTopBid)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: kStatusWarning,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.star, size: 14, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            player.getPlayerName(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: compact ? textTheme.bodySmall : textTheme.titleSmall,
          ),
          Text(
            '#${player.getPlayerId()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          if (!compact && bidAmount != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kStatusSold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.payments_outlined, size: 14, color: kStatusSold),
                    const SizedBox(width: 4),
                    Text(
                      '$bidAmount',
                      style: textTheme.bodySmall?.copyWith(
                        color: kStatusSold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Loads this player's face-biased alignment lazily (once per mount, cached
/// thereafter by `FaceCropService`) so building many tiles at once never
/// blocks on face detection — starts centered, swaps in once resolved.
class _FaceAlignedPlayerPhoto extends StatefulWidget {
  const _FaceAlignedPlayerPhoto({required this.player});

  final Player player;

  @override
  State<_FaceAlignedPlayerPhoto> createState() => _FaceAlignedPlayerPhotoState();
}

class _FaceAlignedPlayerPhotoState extends State<_FaceAlignedPlayerPhoto> {
  Alignment _alignment = Alignment.center;

  @override
  void initState() {
    super.initState();
    FaceCropService.instance.alignmentFor(widget.player).then((alignment) {
      if (mounted) setState(() => _alignment = alignment);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      widget.player.getPlayerPhoto(),
      fit: BoxFit.cover,
      alignment: _alignment,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.black26,
        child: const Icon(Icons.person, color: Colors.white70),
      ),
    );
  }
}
