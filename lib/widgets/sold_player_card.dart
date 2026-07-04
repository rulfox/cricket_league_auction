import 'package:flutter/material.dart';

import '../models/player.dart';
import 'player_card_layout.dart';

/// The "complete" per-player export card: photo, name, assigned team, bid
/// amount, and phone — used to build the per-team card ZIP export.
class SoldPlayerCard extends StatelessWidget {
  const SoldPlayerCard({
    super.key,
    required this.player,
    required this.teamName,
    required this.bidAmount,
  });

  final Player player;
  final String teamName;
  final int bidAmount;

  @override
  Widget build(BuildContext context) {
    return PlayerCardLayout(
      player: player,
      lines: [
        CardLine("#${player.getPlayerId()}", 70),
        CardLine(player.getPlayerName(), 85),
        CardLine(teamName, 60),
        CardLine("$bidAmount points", 55),
        CardLine(player.getPhoneNumber(), 36),
      ],
    );
  }
}
