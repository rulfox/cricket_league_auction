import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player.dart';
import '../state/auction_state.dart';
import 'players_popup.dart';

/// Hidden admin screen — never linked from any visible menu, reachable only
/// via the secret keyboard gesture (`SecretJackpotGestureDetector`). Lets the
/// auctioneer schedule a specific player to be the deterministic outcome of
/// a future Jackpot draw, while the shuffle animation still plays normally.
/// Deliberately plain/utilitarian — this is an admin tool, not a polished
/// user-facing screen.
class JackpotOverrideScreen extends StatefulWidget {
  const JackpotOverrideScreen({super.key});

  @override
  State<JackpotOverrideScreen> createState() => _JackpotOverrideScreenState();
}

class _JackpotOverrideScreenState extends State<JackpotOverrideScreen> {
  final TextEditingController _relativeDrawController = TextEditingController(text: '1');
  Player? _pendingPlayer;

  @override
  void dispose() {
    _relativeDrawController.dispose();
    super.dispose();
  }

  Player? _findPlayer(AuctionState state, String playerId) {
    for (final p in state.players) {
      if (state.keyFor(p) == playerId) return p;
    }
    return null;
  }

  Future<void> _pickPlayer(AuctionState auctionState) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayersPopup(
          players: auctionState.availablePlayers,
          setPlayer: (player) => setState(() => _pendingPlayer = player),
        ),
      ),
    );
  }

  Future<void> _addOverride(AuctionState auctionState) async {
    final relative = int.tryParse(_relativeDrawController.text);
    final player = _pendingPlayer;
    if (relative == null || relative < 1 || player == null) return;
    final drawIndex = auctionState.jackpotDrawCount + relative;
    await auctionState.addJackpotOverride(
      drawIndex: drawIndex,
      playerId: auctionState.keyFor(player),
    );
    if (!mounted) return;
    setState(() {
      _pendingPlayer = null;
      _relativeDrawController.text = '1';
    });
  }

  @override
  Widget build(BuildContext context) {
    final auctionState = context.watch<AuctionState>();
    final overrides = List.of(auctionState.jackpotOverrides)
      ..sort((a, b) => a.drawIndex.compareTo(b.drawIndex));

    return Scaffold(
      appBar: AppBar(title: const Text('Jackpot Overrides')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Draws so far: ${auctionState.jackpotDrawCount}. '
            'Next draw is #${auctionState.jackpotDrawCount + 1}.',
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add override'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _relativeDrawController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Trigger on draw N from now'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _pendingPlayer == null
                            ? const Text('No player selected')
                            : Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundImage:
                                        AssetImage(_pendingPlayer!.getPlayerPhoto()),
                                    onBackgroundImageError: (_, __) {},
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(_pendingPlayer!.getPlayerName())),
                                  IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => setState(() => _pendingPlayer = null),
                                  ),
                                ],
                              ),
                      ),
                      TextButton(
                        onPressed: () => _pickPlayer(auctionState),
                        child: const Text('Choose Player'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _pendingPlayer == null ? null : () => _addOverride(auctionState),
                    child: const Text('Add override'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Pending overrides', style: Theme.of(context).textTheme.titleMedium),
          if (overrides.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('None'),
            )
          else
            for (final override in overrides)
              Builder(builder: (context) {
                final player = _findPlayer(auctionState, override.playerId);
                return ListTile(
                  leading: player == null
                      ? const Icon(Icons.person_off_outlined)
                      : CircleAvatar(
                          backgroundImage: AssetImage(player.getPlayerPhoto()),
                          onBackgroundImageError: (_, __) {},
                        ),
                  title: Text(
                    'Draw #${override.drawIndex} '
                    '(in ${override.drawIndex - auctionState.jackpotDrawCount})',
                  ),
                  subtitle: Text(player?.getPlayerName() ?? 'Unknown player'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => auctionState.removeJackpotOverride(override.drawIndex),
                  ),
                );
              }),
        ],
      ),
    );
  }
}
