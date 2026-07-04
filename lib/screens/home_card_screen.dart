import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

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

enum _JackpotUiState { none, shuffling, revealed }

/// The main "auction card" browsing screen: one player at a time, using the
/// full screen height (no permanent AppBar/bottomNavigationBar — every other
/// action lives in overlay icons or on-demand sheets/menus instead), with
/// search, single/all card export, live bidding, an in-place Jackpot draw,
/// and navigation to Settings and the teamwise results export screen.
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

  late final AuctionState _auctionState;
  bool _poolWasEmpty = false;
  bool _completionFlowActive = false;

  _JackpotUiState _jackpotState = _JackpotUiState.none;
  Player? _jackpotDecoy;
  Player? _jackpotDecided;
  final math.Random _jackpotRandom = math.Random();

  @override
  void initState() {
    super.initState();
    _auctionState = context.read<AuctionState>();
    _player = _auctionState.players[0];
    // Seed from whatever's already true, so reopening an already-finished
    // auction doesn't immediately re-show the completion dialog.
    _poolWasEmpty = _auctionState.availablePlayers.isEmpty;
    _auctionState.addListener(_handlePoolTransition);
  }

  @override
  void dispose() {
    _auctionState.removeListener(_handlePoolTransition);
    super.dispose();
  }

  /// Detects the exact false→true edge of "no players left to auction" and
  /// kicks off the completion flow — not `context.watch`, which is for
  /// rebuild-triggering, not one-shot side effects like showing a dialog.
  /// Updating `_poolWasEmpty` synchronously (before the dialog even opens) is
  /// what lets this fire again for a second/third re-auction round: once
  /// `reauctionUnsoldPlayers()` refills the pool, the next empty-transition
  /// is a fresh edge this same listener will catch later.
  void _handlePoolTransition() {
    final isEmptyNow = _auctionState.availablePlayers.isEmpty;
    final justEmptied = isEmptyNow && !_poolWasEmpty;
    _poolWasEmpty = isEmptyNow;
    if (!justEmptied || _completionFlowActive) return;
    _completionFlowActive = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _completionFlowActive = false;
        return;
      }
      try {
        await _handleAuctionPoolEmptied();
      } finally {
        if (mounted) _completionFlowActive = false;
      }
    });
  }

  Future<void> _handleAuctionPoolEmptied() async {
    final unsoldCount = _auctionState.unsoldPlayers.length;
    var wantsReauction = false;
    if (unsoldCount > 0) {
      wantsReauction = await _confirmReauction(unsoldCount);
    }
    if (!mounted) return;
    if (wantsReauction) {
      await _auctionState.reauctionUnsoldPlayers();
      return; // auctioneer just continues as normal — no completion dialog
    }
    await _showAuctionCompletedDialog();
  }

  Future<bool> _confirmReauction(int unsoldCount) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('All Players Auctioned'),
        content: Text(
          '$unsoldCount player${unsoldCount == 1 ? '' : 's'} unsold — auction them now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showAuctionCompletedDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Auction Completed'),
        content: const Text('All players have been auctioned.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Stay on Home'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AuctionSummaryScreen()),
              );
            },
            child: const Text('View Summary'),
          ),
        ],
      ),
    );
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

  /// Starts the Jackpot draw in place — no separate screen/route. Auto-runs
  /// the shuffle/reveal sequence the instant it's called (mirrors the old
  /// dedicated screen's auto-start-on-open behavior) and replaces the
  /// currently-displayed card until finalized or cancelled.
  Future<void> _startJackpot() async {
    final auctionState = context.read<AuctionState>();
    final decoyPool = auctionState.availablePlayers;
    if (decoyPool.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No players left to draw.')));
      return;
    }

    setState(() {
      _jackpotDecoy = decoyPool[_jackpotRandom.nextInt(decoyPool.length)];
      _jackpotState = _JackpotUiState.shuffling;
    });

    final decided = await auctionState.drawRandomPlayer();
    if (!mounted) return;
    if (decided == null) {
      setState(() => _jackpotState = _JackpotUiState.none);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No players left to draw.')));
      return;
    }
    _jackpotDecided = decided;

    final totalMs = auctionState.settings.jackpotDurationSeconds * 1000;
    final stopwatch = Stopwatch()..start();

    void tick() {
      if (!mounted) return;
      final progress = (stopwatch.elapsedMilliseconds / totalMs).clamp(0.0, 1.0);
      if (progress >= 1.0) {
        setState(() {
          _jackpotDecoy = _jackpotDecided;
          _jackpotState = _JackpotUiState.revealed;
        });
        return;
      }
      setState(() => _jackpotDecoy = decoyPool[_jackpotRandom.nextInt(decoyPool.length)]);
      final delayMs = lerpDouble(60, 450, Curves.easeOut.transform(progress))!.round();
      Timer(Duration(milliseconds: delayMs), tick);
    }

    tick();
  }

  /// Commits the drawn player onto Home and exits Jackpot mode. The draw
  /// itself already consumed a real `drawRandomPlayer()` call/count when it
  /// started — this only decides what's displayed.
  void _finalizeJackpot() {
    setState(() {
      _player = _jackpotDecided!;
      _jackpotState = _JackpotUiState.none;
      _jackpotDecoy = null;
      _jackpotDecided = null;
    });
  }

  /// Exits Jackpot mode without changing what Home displays.
  void _cancelJackpot() {
    setState(() {
      _jackpotState = _JackpotUiState.none;
      _jackpotDecoy = null;
      _jackpotDecided = null;
    });
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

  List<CardLine> _linesFor(Player player) => [
        CardLine("#${player.getPlayerId()}", 70),
        CardLine(player.getPlayerName(), 85),
        CardLine(player.getTeam(), 60),
        CardLine(player.getCategory(), 48),
        CardLine(
          "${player.getBattingStyle()} Batsman | ${player.getBowlingArm()} ${player.getBowlingStyle()} Bowler",
          38,
        ),
        CardLine(player.getPhoneNumber(), 36),
      ];

  @override
  Widget build(BuildContext context) {
    final auctionState = context.watch<AuctionState>();
    final playerId = auctionState.keyFor(_player);
    final record = auctionState.recordFor(playerId);
    final teamName = auctionState.teamNameFor(record.teamId);
    final isDecided = record.status != AuctionStatus.available;

    final isJackpotActive = _jackpotState != _JackpotUiState.none;
    final isJackpotShuffling = _jackpotState == _JackpotUiState.shuffling;
    final displayedPlayer = isJackpotActive ? (_jackpotDecoy ?? _player) : _player;

    return PopScope(
      canPop: !isJackpotShuffling,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.arrowRight): () {
            if (!isJackpotActive) _navigatePlayer(1);
          },
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
            if (!isJackpotActive) _navigatePlayer(-1);
          },
          const SingleActivator(LogicalKeyboardKey.space): () {
            if (!isJackpotActive) _openSearch(auctionState.players);
          },
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Stack(
              children: <Widget>[
                RepaintBoundary(
                  key: _captureKey,
                  child: isJackpotShuffling
                      ? AnimatedSwitcher(
                          duration: const Duration(milliseconds: 100),
                          child: PlayerCardLayout(
                            key: ValueKey('jackpot_${displayedPlayer.getPlayerId()}'),
                            player: displayedPlayer,
                            lines: _linesFor(displayedPlayer),
                          ),
                        )
                      : PlayerCardLayout(
                          player: displayedPlayer,
                          lines: _linesFor(displayedPlayer),
                          onPhotoTap: isJackpotActive
                              ? null
                              : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FullScreenImageScreen(
                                          imagePath: displayedPlayer.getPlayerPhoto()),
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
                      child: isJackpotActive
                          ? Row(
                              children: [
                                if (!isJackpotShuffling)
                                  OverlayIconButton(
                                    icon: Icons.arrow_back,
                                    tooltip: 'Back',
                                    onPressed: _cancelJackpot,
                                  ),
                              ],
                            )
                          : Row(
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
                                      icon: Icons.casino,
                                      tooltip: 'Jackpot',
                                      onPressed: _startJackpot,
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
            floatingActionButton: !isJackpotActive
                ? Padding(
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
                  )
                : (_jackpotState == _JackpotUiState.revealed
                    ? FloatingActionButton(
                        heroTag: 'jackpot_finalize',
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        tooltip: 'Send to Auction',
                        onPressed: _finalizeJackpot,
                        child: const Icon(Icons.check),
                      )
                    : null),
          ),
        ),
      ),
    );
  }
}
