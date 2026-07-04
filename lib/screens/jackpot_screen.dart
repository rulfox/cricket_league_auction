import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player.dart';
import '../state/auction_state.dart';
import '../widgets/player_card_layout.dart';

enum _JackpotStage { idle, shuffling, revealed, empty }

/// Randomly selects the next player to auction, with a slot-machine-style
/// shuffle before the reveal. The real outcome is decided immediately (via
/// `AuctionState.drawRandomPlayer`) when "Draw" is tapped — the animation
/// that follows is purely cosmetic suspense over already-decided data, not a
/// live process, so there's no way for a second concurrent draw to race with
/// it and no observable difference from "deciding" only at the end.
class JackpotScreen extends StatefulWidget {
  const JackpotScreen({super.key});

  @override
  State<JackpotScreen> createState() => _JackpotScreenState();
}

class _JackpotScreenState extends State<JackpotScreen> {
  _JackpotStage _stage = _JackpotStage.idle;
  Player? _displayedPlayer;
  Player? _decidedPlayer;
  final math.Random _random = math.Random();

  Future<void> _startDraw() async {
    final auctionState = context.read<AuctionState>();
    final decoyPool = auctionState.availablePlayers;
    if (decoyPool.isEmpty) {
      setState(() => _stage = _JackpotStage.empty);
      return;
    }

    final decided = await auctionState.drawRandomPlayer();
    if (!mounted) return;
    if (decided == null) {
      setState(() => _stage = _JackpotStage.empty);
      return;
    }
    _decidedPlayer = decided;
    setState(() => _stage = _JackpotStage.shuffling);

    final totalMs = auctionState.settings.jackpotDurationSeconds * 1000;
    final stopwatch = Stopwatch()..start();

    void tick() {
      if (!mounted) return;
      final progress = (stopwatch.elapsedMilliseconds / totalMs).clamp(0.0, 1.0);
      if (progress >= 1.0) {
        setState(() {
          _displayedPlayer = _decidedPlayer;
          _stage = _JackpotStage.revealed;
        });
        return;
      }
      setState(() => _displayedPlayer = decoyPool[_random.nextInt(decoyPool.length)]);
      final delayMs = lerpDouble(60, 450, Curves.easeOut.transform(progress))!.round();
      Timer(Duration(milliseconds: delayMs), tick);
    }

    tick();
  }

  void _drawAgain() {
    setState(() {
      _stage = _JackpotStage.idle;
      _displayedPlayer = null;
      _decidedPlayer = null;
    });
    _startDraw();
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
    final isShuffling = _stage == _JackpotStage.shuffling;
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !isShuffling,
      child: Scaffold(
        appBar: AppBar(title: const Text('Jackpot')),
        body: switch (_stage) {
          _JackpotStage.idle => Center(
              child: FilledButton.icon(
                onPressed: _startDraw,
                icon: const Icon(Icons.casino),
                label: const Text('Draw'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  textStyle: const TextStyle(fontSize: 20),
                ),
              ),
            ),
          _JackpotStage.empty => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  const Text('No players left to draw'),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          _JackpotStage.shuffling => AnimatedSwitcher(
              duration: const Duration(milliseconds: 100),
              child: _displayedPlayer == null
                  ? const SizedBox.shrink()
                  : PlayerCardLayout(
                      key: ValueKey(_displayedPlayer!.getPlayerId()),
                      player: _displayedPlayer!,
                      lines: _linesFor(_displayedPlayer!),
                    ),
            ),
          _JackpotStage.revealed => Column(
              children: [
                Expanded(
                  child: PlayerCardLayout(
                    player: _decidedPlayer!,
                    lines: _linesFor(_decidedPlayer!),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _drawAgain,
                          icon: const Icon(Icons.replay),
                          label: const Text('Draw Again'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.pop(context, _decidedPlayer),
                          icon: const Icon(Icons.gavel),
                          label: const Text('Send to Auction'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        },
      ),
    );
  }
}
