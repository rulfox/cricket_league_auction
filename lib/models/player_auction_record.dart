enum AuctionStatus { available, sold, unsold }

class PlayerAuctionRecord {
  PlayerAuctionRecord({
    required this.playerId,
    this.status = AuctionStatus.available,
    this.teamId,
    this.soldPoints,
    this.isExtraBid = false,
    this.auctionedAt,
  });

  final String playerId;
  AuctionStatus status;
  String? teamId;
  int? soldPoints;
  bool isExtraBid;
  DateTime? auctionedAt;

  factory PlayerAuctionRecord.initial(String playerId) =>
      PlayerAuctionRecord(playerId: playerId);

  PlayerAuctionRecord copyWith({
    AuctionStatus? status,
    String? teamId,
    int? soldPoints,
    bool? isExtraBid,
    DateTime? auctionedAt,
    bool clearTeamAndBid = false,
  }) =>
      PlayerAuctionRecord(
        playerId: playerId,
        status: status ?? this.status,
        teamId: clearTeamAndBid ? null : (teamId ?? this.teamId),
        soldPoints: clearTeamAndBid ? null : (soldPoints ?? this.soldPoints),
        isExtraBid: clearTeamAndBid ? false : (isExtraBid ?? this.isExtraBid),
        auctionedAt: clearTeamAndBid ? null : (auctionedAt ?? this.auctionedAt),
      );

  factory PlayerAuctionRecord.fromJson(String playerId, Map<String, dynamic> json) =>
      PlayerAuctionRecord(
        playerId: playerId,
        status: AuctionStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => AuctionStatus.available,
        ),
        teamId: json['teamId'] as String?,
        soldPoints: json['soldPoints'] as int?,
        isExtraBid: json['isExtraBid'] as bool? ?? false,
        auctionedAt: json['auctionedAt'] != null
            ? DateTime.tryParse(json['auctionedAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'teamId': teamId,
        'soldPoints': soldPoints,
        'isExtraBid': isExtraBid,
        'auctionedAt': auctionedAt?.toIso8601String(),
      };
}
