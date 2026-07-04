import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auction_snapshot.dart';

/// Persists the entire auction state (settings + teams + records) as a
/// single JSON blob. shared_preferences is backed by localStorage on web and
/// simple files/plist elsewhere, so the same code path works on every
/// platform target without a schema or code-gen step.
class AuctionPersistenceService {
  static const _storageKey = 'auction_state_v1';

  Future<AuctionSnapshot?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AuctionSnapshot.fromJson(json);
    } catch (e) {
      // ignore: avoid_print
      print('Warning: failed to parse persisted auction state: $e');
      return null;
    }
  }

  Future<void> save(AuctionSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(snapshot.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
