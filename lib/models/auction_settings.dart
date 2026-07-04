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
  });

  final int totalPurse;
  final int minBasePoint;
  final int playersPerTeam;
  final AuctionMode mode;

  static const defaults = AuctionSettings(
    totalPurse: 20000,
    minBasePoint: 100,
    playersPerTeam: 15,
    mode: AuctionMode.standard,
  );

  AuctionSettings copyWith({
    int? totalPurse,
    int? minBasePoint,
    int? playersPerTeam,
    AuctionMode? mode,
  }) =>
      AuctionSettings(
        totalPurse: totalPurse ?? this.totalPurse,
        minBasePoint: minBasePoint ?? this.minBasePoint,
        playersPerTeam: playersPerTeam ?? this.playersPerTeam,
        mode: mode ?? this.mode,
      );

  factory AuctionSettings.fromJson(Map<String, dynamic> json) => AuctionSettings(
        totalPurse: json['totalPurse'] as int,
        minBasePoint: json['minBasePoint'] as int,
        playersPerTeam: json['playersPerTeam'] as int,
        mode: AuctionMode.values.firstWhere(
          (m) => m.name == json['mode'],
          orElse: () => AuctionMode.standard,
        ),
      );

  Map<String, dynamic> toJson() => {
        'totalPurse': totalPurse,
        'minBasePoint': minBasePoint,
        'playersPerTeam': playersPerTeam,
        'mode': mode.name,
      };
}
