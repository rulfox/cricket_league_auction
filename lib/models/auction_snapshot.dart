import 'auction_settings.dart';
import 'player_auction_record.dart';
import 'team.dart';

/// Persistence DTO bundling everything that needs to survive an app restart.
/// [schemaVersion] is the single hook for future `migrateSnapshot` logic.
class AuctionSnapshot {
  const AuctionSnapshot({
    required this.settings,
    required this.teams,
    required this.records,
  });

  static const currentSchemaVersion = 1;

  final AuctionSettings settings;
  final List<Team> teams;
  final Map<String, PlayerAuctionRecord> records;

  static AuctionSnapshot empty() => const AuctionSnapshot(
        settings: AuctionSettings.defaults,
        teams: [],
        records: {},
      );

  factory AuctionSnapshot.fromJson(Map<String, dynamic> json) {
    final recordsJson = (json['records'] as Map<String, dynamic>?) ?? {};
    return AuctionSnapshot(
      settings: json['settings'] != null
          ? AuctionSettings.fromJson(json['settings'] as Map<String, dynamic>)
          : AuctionSettings.defaults,
      teams: ((json['teams'] as List?) ?? [])
          .map((t) => Team.fromJson(t as Map<String, dynamic>))
          .toList(),
      records: recordsJson.map(
        (playerId, value) => MapEntry(
          playerId,
          PlayerAuctionRecord.fromJson(playerId, value as Map<String, dynamic>),
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': currentSchemaVersion,
        'settings': settings.toJson(),
        'teams': teams.map((t) => t.toJson()).toList(),
        'records': records.map((playerId, record) => MapEntry(playerId, record.toJson())),
      };
}
