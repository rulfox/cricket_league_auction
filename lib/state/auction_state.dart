import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/auction_settings.dart';
import '../models/auction_snapshot.dart';
import '../models/jackpot_override.dart';
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
  int _jackpotDrawCount = 0;
  List<JackpotOverride> _jackpotOverrides = [];
  final math.Random _random = math.Random();

  List<Player> get players => List.unmodifiable(_players);
  List<Team> get teams => List.unmodifiable(_teams);
  AuctionSettings get settings => _settings;
  bool get isLoaded => _isLoaded;
  int get jackpotDrawCount => _jackpotDrawCount;
  List<JackpotOverride> get jackpotOverrides => List.unmodifiable(_jackpotOverrides);

  List<Player> get availablePlayers =>
      _players.where((p) => recordFor(keyFor(p)).status == AuctionStatus.available).toList();

  List<Player> get unsoldPlayers =>
      _players.where((p) => recordFor(keyFor(p)).status == AuctionStatus.unsold).toList();

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
      _jackpotDrawCount = snapshot.jackpotDrawCount;
      _jackpotOverrides = List.of(snapshot.jackpotOverrides);
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _persist() => _persistence.save(
        AuctionSnapshot(
          settings: _settings,
          teams: _teams,
          records: Map.of(_records),
          jackpotDrawCount: _jackpotDrawCount,
          jackpotOverrides: List.of(_jackpotOverrides),
        ),
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
    required String playerId,
    required String teamId,
    required int bidAmount,
    required bool allowExtraBidChecked,
  }) {
    final currentRecord = recordFor(playerId);
    final isSameTeamReassignment =
        currentRecord.status == AuctionStatus.sold && currentRecord.teamId == teamId;
    // Excluding the player's own current record when they're already sold to
    // this same team means the resulting summary reflects the team as if
    // this player's prior sale didn't exist yet — so both the squad-count
    // cap and Strict Purse's reserve math are correct when editing an
    // existing sale's bid amount, instead of double-counting it.
    final relevantRecords = isSameTeamReassignment
        ? _records.entries.where((e) => e.key != playerId).map((e) => e.value)
        : _records.values;
    final purseSummary = computeTeamPurseSummary(
      teamId: teamId,
      records: relevantRecords,
      settings: _settings,
    );
    return evaluateBid(
      bidAmount: bidAmount,
      purseSummaryBeforeThisSale: purseSummary,
      settings: _settings,
      allowExtraBidChecked: allowExtraBidChecked,
    );
  }

  Future<void> resetRecordsOnly() async {
    _records.clear();
    notifyListeners();
    await _persist();
  }

  Future<void> resetEverything() async {
    _records.clear();
    _teams = [];
    _settings = AuctionSettings.defaults;
    _jackpotDrawCount = 0;
    _jackpotOverrides = [];
    notifyListeners();
    await _persist();
  }

  /// Draws the next random player for the Jackpot selector. If a hidden
  /// override is scheduled for this draw and its player is still available,
  /// returns that player instead of a true-random pick (falling back to
  /// random and dropping the stale override if that player was already
  /// sold/unsold through the normal bidding flow in the meantime). Returns
  /// `null`, without consuming a draw or any override, if no players remain.
  Future<Player?> drawRandomPlayer() async {
    final available = availablePlayers;
    if (available.isEmpty) return null;

    final nextDraw = _jackpotDrawCount + 1;

    JackpotOverride? overrideForThisDraw;
    for (final o in _jackpotOverrides) {
      if (o.drawIndex == nextDraw) {
        overrideForThisDraw = o;
        break;
      }
    }

    Player? chosen;
    if (overrideForThisDraw != null) {
      for (final p in available) {
        if (keyFor(p) == overrideForThisDraw.playerId) {
          chosen = p;
          break;
        }
      }
      // If not found: the overridden player is no longer available — falls
      // through to a true-random pick below.
    }
    chosen ??= available[_random.nextInt(available.length)];

    _jackpotDrawCount = nextDraw;
    // This draw's override slot is consumed either way — used or stale —
    // since it no longer applies to any future draw.
    _jackpotOverrides = _jackpotOverrides.where((o) => o.drawIndex != nextDraw).toList();

    notifyListeners();
    await _persist();
    return chosen;
  }

  /// Schedules [playerId] to be the deterministic outcome of draw
  /// [drawIndex], replacing any existing override for that same draw.
  Future<void> addJackpotOverride({required int drawIndex, required String playerId}) async {
    _jackpotOverrides = [
      ..._jackpotOverrides.where((o) => o.drawIndex != drawIndex),
      JackpotOverride(drawIndex: drawIndex, playerId: playerId),
    ];
    notifyListeners();
    await _persist();
  }

  Future<void> removeJackpotOverride(int drawIndex) async {
    _jackpotOverrides = _jackpotOverrides.where((o) => o.drawIndex != drawIndex).toList();
    notifyListeners();
    await _persist();
  }

  /// Moves every currently-unsold player back to Available in one batch, so
  /// the auctioneer can run another round over just the leftovers. Safe to
  /// call repeatedly — each call only touches records that are unsold
  /// *right now*, which is what makes unlimited re-auction rounds possible.
  Future<void> reauctionUnsoldPlayers() async {
    final unsoldIds = _players
        .map(keyFor)
        .where((id) => recordFor(id).status == AuctionStatus.unsold)
        .toList();
    for (final id in unsoldIds) {
      _records[id] = PlayerAuctionRecord.initial(id);
    }
    notifyListeners();
    await _persist();
  }
}
