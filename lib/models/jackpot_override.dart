/// A pending, secretly-scheduled outcome for the Jackpot random-player
/// selector: when the running draw counter reaches [drawIndex], the draw
/// deterministically resolves to [playerId] instead of a true-random pick
/// (falling back to random if that player is no longer available by then).
/// Set only via the hidden override screen.
class JackpotOverride {
  const JackpotOverride({required this.drawIndex, required this.playerId});

  final int drawIndex;
  final String playerId;

  factory JackpotOverride.fromJson(Map<String, dynamic> json) => JackpotOverride(
        drawIndex: json['drawIndex'] as int,
        playerId: json['playerId'] as String,
      );

  Map<String, dynamic> toJson() => {'drawIndex': drawIndex, 'playerId': playerId};
}
