import 'package:flutter/foundation.dart';

import '../models/auction_settings.dart';
import '../models/auction_snapshot.dart';
import '../models/player.dart';
import '../models/player_auction_record.dart';
import '../models/team.dart';
import '../services/bidding_rules.dart';
import '../services/persistence_service.dart';

class TeamRemovalResult {
  const TeamRemovalResult._({required this.wasRemoved, this.blockedByCount});

  factory TeamRemovalResult.removed() => const TeamRemovalResult._(wasRemoved: true);

  factory TeamRemovalResult.blocked(int soldCount) =>
      TeamRemovalResult._(wasRemoved: false, blockedByCount: soldCount);

  final bool wasRemoved;
  final int? blockedByCount;
}

/// Single source of truth for teams, settings, and per-player auction
/// records. Every mutation updates in-memory state, calls [notifyListeners]
/// immediately (optimistic UI), then persists — no debouncing, since the
/// serialized state is small and cheap to write every time.
class AuctionState extends ChangeNotifier {
  AuctionState({required List<Player> players, required AuctionPersistenceService persistence})
      : _players = players,
        _persistence = persistence {
    _assignPlayerKeys();
  }

  final List<Player> _players;
  final AuctionPersistenceService _persistence;

  late final List<String> _playerKeys; // parallel to _players, by index
  final Map<String, PlayerAuctionRecord> _records = {};
  List<Team> _teams = [];
  AuctionSettings _settings = AuctionSettings.defaults;
  bool _isLoaded = false;

  List<Player> get players => List.unmodifiable(_players);
  List<Team> get teams => List.unmodifiable(_teams);
  AuctionSettings get settings => _settings;
  bool get isLoaded => _isLoaded;

  /// Guards against two roster entries with a missing/duplicate sl_no
  /// silently sharing (and corrupting) the same auction record.
  void _assignPlayerKeys() {
    final seen = <String>{};
    _playerKeys = List.generate(_players.length, (i) {
      final id = _players[i].getPlayerId();
      if (id.isEmpty || seen.contains(id)) {
        if (id.isNotEmpty) {
          // ignore: avoid_print
          print('Warning: duplicate player id "$id" at roster index $i; using a synthetic key');
        }
        final synthetic = 'idx_$i';
        seen.add(synthetic);
        return synthetic;
      }
      seen.add(id);
      return id;
    });
  }

  String keyFor(Player player) {
    final index = _players.indexOf(player);
    return index >= 0 ? _playerKeys[index] : player.getPlayerId();
  }

  String? teamNameFor(String? teamId) {
    if (teamId == null) return null;
    for (final t in _teams) {
      if (t.id == teamId) return t.name;
    }
    return null;
  }

  PlayerAuctionRecord recordFor(String playerId) =>
      _records[playerId] ?? PlayerAuctionRecord.initial(playerId);

  Future<void> load() async {
    final snapshot = await _persistence.load();
    if (snapshot != null) {
      _settings = snapshot.settings;
      _teams = List.of(snapshot.teams);
      _records
        ..clear()
        ..addAll(snapshot.records);
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _persist() => _persistence.save(
        AuctionSnapshot(settings: _settings, teams: _teams, records: Map.of(_records)),
      );

  Future<void> updateSettings(AuctionSettings next) async {
    _settings = next;
    notifyListeners();
    await _persist();
  }

  Future<void> addTeam(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _teams = [
      ..._teams,
      Team(id: 'team_${DateTime.now().microsecondsSinceEpoch}', name: trimmed),
    ];
    notifyListeners();
    await _persist();
  }

  Future<void> renameTeam(String teamId, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    _teams = _teams.map((t) => t.id == teamId ? t.copyWith(name: trimmed) : t).toList();
    notifyListeners();
    await _persist();
  }

  /// Blocks deletion if the team already has sold players, rather than
  /// silently orphaning their records.
  Future<TeamRemovalResult> removeTeam(String teamId) async {
    final soldCount = _records.values
        .where((r) => r.status == AuctionStatus.sold && r.teamId == teamId)
        .length;
    if (soldCount > 0) {
      return TeamRemovalResult.blocked(soldCount);
    }
    _teams = _teams.where((t) => t.id != teamId).toList();
    notifyListeners();
    await _persist();
    return TeamRemovalResult.removed();
  }

  Future<void> markSold({
    required String playerId,
    required String teamId,
    required int bidAmount,
    required bool isExtraBid,
  }) async {
    _records[playerId] = recordFor(playerId).copyWith(
      status: AuctionStatus.sold,
      teamId: teamId,
      soldPoints: bidAmount,
      isExtraBid: isExtraBid,
      auctionedAt: DateTime.now(),
    );
    notifyListeners();
    await _persist();
  }

  Future<void> markUnsold(String playerId) async {
    _records[playerId] = recordFor(playerId).copyWith(
      status: AuctionStatus.unsold,
      clearTeamAndBid: true,
    );
    notifyListeners();
    await _persist();
  }

  /// Reopens a Sold or Unsold player back to Available (e.g. to re-auction
  /// or reassign).
  Future<void> resetToAvailable(String playerId) async {
    _records[playerId] = PlayerAuctionRecord.initial(playerId);
    notifyListeners();
    await _persist();
  }

  TeamPurseSummary purseSummaryFor(String teamId) => computeTeamPurseSummary(
        teamId: teamId,
        records: _records.values,
        settings: _settings,
      );

  BidValidationResult evaluateBidFor({
    required String teamId,
    required int bidAmount,
    required bool allowExtraBidChecked,
  }) =>
      evaluateBid(
        bidAmount: bidAmount,
        purseSummaryBeforeThisSale: purseSummaryFor(teamId),
        settings: _settings,
        allowExtraBidChecked: allowExtraBidChecked,
      );

  Future<void> resetRecordsOnly() async {
    _records.clear();
    notifyListeners();
    await _persist();
  }

  Future<void> resetEverything() async {
    _records.clear();
    _teams = [];
    _settings = AuctionSettings.defaults;
    notifyListeners();
    await _persist();
  }
}
