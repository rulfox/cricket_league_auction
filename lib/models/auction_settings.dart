enum AuctionMode {
  /// Teams can go over their remaining purse if the auctioneer explicitly
  /// allows "extra bidding" for that sale.
  standard,

  /// Purse is a hard cap. No extra bidding is ever allowed, and the maximum
  /// bid for the current player is capped so enough points remain reserved
  /// (at the minimum base point) for every player slot still needed.
  strictPurse,
}

class AuctionSettings {
  const AuctionSettings({
    required this.totalPurse,
    required this.minBasePoint,
    required this.playersPerTeam,
    required this.mode,
    this.jackpotDurationSeconds = 5,
  });

  final int totalPurse;
  final int minBasePoint;
  final int playersPerTeam;
  final AuctionMode mode;

  /// Duration (seconds) of the shuffle/reveal animation on the Jackpot
  /// random-player-selection screen.
  final int jackpotDurationSeconds;

  static const defaults = AuctionSettings(
    totalPurse: 20000,
    minBasePoint: 100,
    playersPerTeam: 15,
    mode: AuctionMode.standard,
    jackpotDurationSeconds: 5,
  );

  AuctionSettings copyWith({
    int? totalPurse,
    int? minBasePoint,
    int? playersPerTeam,
    AuctionMode? mode,
    int? jackpotDurationSeconds,
  }) =>
      AuctionSettings(
        totalPurse: totalPurse ?? this.totalPurse,
        minBasePoint: minBasePoint ?? this.minBasePoint,
        playersPerTeam: playersPerTeam ?? this.playersPerTeam,
        mode: mode ?? this.mode,
        jackpotDurationSeconds: jackpotDurationSeconds ?? this.jackpotDurationSeconds,
      );

  factory AuctionSettings.fromJson(Map<String, dynamic> json) => AuctionSettings(
        totalPurse: json['totalPurse'] as int,
        minBasePoint: json['minBasePoint'] as int,
        playersPerTeam: json['playersPerTeam'] as int,
        mode: AuctionMode.values.firstWhere(
          (m) => m.name == json['mode'],
          orElse: () => AuctionMode.standard,
        ),
        jackpotDurationSeconds: json['jackpotDurationSeconds'] as int? ?? 5,
      );

  Map<String, dynamic> toJson() => {
        'totalPurse': totalPurse,
        'minBasePoint': minBasePoint,
        'playersPerTeam': playersPerTeam,
        'mode': mode.name,
        'jackpotDurationSeconds': jackpotDurationSeconds,
      };
}
