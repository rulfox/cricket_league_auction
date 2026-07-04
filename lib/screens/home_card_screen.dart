import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/player.dart';
import '../models/player_auction_record.dart';
import '../services/capture_service.dart';
import '../services/web_download.dart';
import '../state/auction_state.dart';
import '../widgets/auction_status_pill.dart';
import '../widgets/bid_control_bar.dart';
import '../widgets/confirm_export_dialog.dart';
import '../widgets/export_progress_overlay.dart';
import '../widgets/overlay_icon_button.dart';
import '../widgets/player_card_layout.dart';
import 'auction_summary_screen.dart';
import 'full_screen_image_screen.dart';
import 'players_popup.dart';
import 'settings_screen.dart';
import 'teams_export_screen.dart';

enum _ExportAction { single, all }

/// The main "auction card" browsing screen: one player at a time, using the
/// full screen height (no permanent AppBar/bottomNavigationBar — every other
/// action lives in overlay icons or on-demand sheets/menus instead), with
/// search, single/all card export, live bidding, and navigation to Settings
/// and the teamwise results export screen.
class HomeCardScreen extends StatefulWidget {
  const HomeCardScreen({super.key, required this.title});

  final String title;

  @override
  State<HomeCardScreen> createState() => _HomeCardScreenState();
}

class _HomeCardScreenState extends State<HomeCardScreen> {
  late Player _player;

  final GlobalKey _captureKey = GlobalKey();
  final CaptureService _captureService = const CaptureService();
  bool _isCapturing = false;
  bool _packaging = false;
  int _captureProgress = 0;
  int _captureTotal = 0;

  @override
  void initState() {
    super.initState();
    _player = context.read<AuctionState>().players[0];
  }

  Future<void> _exportCurrentCard() async {
    if (!await confirmExport(context, message: 'Export this player card as an image?')) {
      return;
    }
    final bytes = await _captureService.captureBoundary(_captureKey);
    await downloadBytes(bytes, '${_player.getPlayerId()}.png');
  }

  Future<void> _captureAllPlayers() async {
    final players = context.read<AuctionState>().players;
    if (!await confirmExport(context, message: 'Export all ${players.length} player cards as a ZIP?')) {
      return;
    }

    setState(() {
      _isCapturing = true;
      _packaging = false;
      _captureProgress = 0;
      _captureTotal = players.length;
    });

    final zip = await _captureService.captureSequenceAsZip<Player>(
      items: players,
      boundaryKey: _captureKey,
      prepareFrame: (player) async {
        if (!mounted) return;
        // Decode the photo into the image cache FIRST, while the previous
        // card is still on screen, so the frame we capture paints the photo
        // on its first build instead of a blank placeholder. Tolerate
        // undecodable assets (e.g. .HEIC on web) so one bad image can't
        // abort the whole export.
        try {
          await precacheImage(AssetImage(player.getPlayerPhoto()), context);
        } catch (_) {}
        if (!mounted) return;
        setState(() => _player = player);
        await WidgetsBinding.instance.endOfFrame;
        WidgetsBinding.instance.scheduleFrame();
        await WidgetsBinding.instance.endOfFrame;
      },
      fileNameFor: (player) => '${player.getPlayerId()}.png',
      onProgress: (completed, total) {
        if (mounted) setState(() => _captureProgress = completed);
      },
    );

    if (!mounted) return;
    setState(() => _packaging = true);
    await WidgetsBinding.instance.endOfFrame;

    await downloadBytes(zip, 'players.zip');

    if (!mounted) return;
    setState(() {
      _isCapturing = false;
      _packaging = false;
    });
  }

  void _setPlayer(Player player) {
    setState(() => _player = player);
  }

  void _navigatePlayer(int direction) {
    final players = context.read<AuctionState>().players;
    final currentIndex = players.indexOf(_player);
    final nextIndex = currentIndex + direction;
    if (nextIndex >= 0 && nextIndex < players.length) {
      _setPlayer(players[nextIndex]);
    }
  }

  void _openSearch(List<Player> players) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayersPopup(players: players, setPlayer: _setPlayer),
      ),
    );
  }

  void _openBidSheet(String playerId, Player player) {
    showModalBottomSheet(
      context: context,
      // The default bottom sheet caps at ~half screen height; BidControlBar's
      // content (dropdown + bid field + validation + checkbox + 3 buttons)
      // can exceed that.
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        // BidControlBar's own SafeArea(top: false) only covers the bottom
        // *system* inset, not the on-screen keyboard — showModalBottomSheet
        // doesn't add that automatically, so the caller must.
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: SingleChildScrollView(
          child: BidControlBar(playerId: playerId, player: player),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auctionState = context.watch<AuctionState>();
    final playerId = auctionState.keyFor(_player);
    final record = auctionState.recordFor(playerId);
    final teamName = auctionState.teamNameFor(record.teamId);
    final isDecided = record.status != AuctionStatus.available;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _navigatePlayer(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _navigatePlayer(-1),
        const SingleActivator(LogicalKeyboardKey.space): () =>
            _openSearch(auctionState.players),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Stack(
            children: <Widget>[
              RepaintBoundary(
                key: _captureKey,
                child: PlayerCardLayout(
                  player: _player,
                  lines: [
                    CardLine("#${_player.getPlayerId()}", 70),
                    CardLine(_player.getPlayerName(), 85),
                    CardLine(_player.getTeam(), 60),
                    CardLine(_player.getCategory(), 48),
                    CardLine(
                      "${_player.getBattingStyle()} Batsman | ${_player.getBowlingArm()} ${_player.getBowlingStyle()} Bowler",
                      38,
                    ),
                    CardLine(_player.getPhoneNumber(), 36),
                  ],
                  onPhotoTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          FullScreenImageScreen(imagePath: _player.getPlayerPhoto()),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AuctionStatusPill(
                          status: record.status,
                          teamName: teamName,
                          bidAmount: record.soldPoints,
                          isExtraBid: record.isExtraBid,
                        ),
                        Row(
                          children: [
                            OverlayIconButton(
                              icon: Icons.dashboard_outlined,
                              tooltip: 'Auction Summary',
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const AuctionSummaryScreen()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OverlayIconButton(
                              icon: Icons.leaderboard,
                              tooltip: 'Auction Results',
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const TeamsExportScreen()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OverlayIconButton(
                              icon: Icons.settings,
                              tooltip: 'Settings',
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const SettingsScreen()),
                              ),
                            ),
                          ],
                        ),
                      ],
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
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                PopupMenuButton<_ExportAction>(
                  tooltip: 'Export',
                  enabled: !_isCapturing,
                  onSelected: (action) => action == _ExportAction.single
                      ? _exportCurrentCard()
                      : _captureAllPlayers(),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _ExportAction.single,
                      child: ListTile(
                        leading: Icon(Icons.image),
                        title: Text('Export this card'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _ExportAction.all,
                      child: ListTile(
                        leading: Icon(Icons.photo_library),
                        title: Text('Export all as ZIP'),
                      ),
                    ),
                  ],
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Icon(
                      Icons.ios_share,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  heroTag: 'search',
                  shape: const CircleBorder(),
                  onPressed: () => _openSearch(auctionState.players),
                  tooltip: 'Search',
                  child: const Icon(Icons.search),
                ),
                const SizedBox(width: 16),
                FloatingActionButton.extended(
                  heroTag: 'bid',
                  onPressed: () => _openBidSheet(playerId, _player),
                  icon: Icon(isDecided ? Icons.edit : Icons.gavel),
                  label: Text(isDecided ? 'Edit' : 'Bid'),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
