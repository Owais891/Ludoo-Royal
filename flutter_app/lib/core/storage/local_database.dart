import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';
import '../constants/app_constants.dart';
import '../../features/game/domain/entities/game_state_snapshot.dart';

/// SQLite storage for offline game states, history and cached user data.
class LocalDatabase {
  static Database? _db;

  static Future<Database> get instance async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, AppConstants.localDbName);
    _db = await openDatabase(
      path,
      version: AppConstants.localDbVersion,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE local_matches (
            match_id TEXT PRIMARY KEY,
            mode TEXT NOT NULL,
            status TEXT NOT NULL,
            snapshot_json TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE local_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            match_id TEXT NOT NULL,
            mode TEXT NOT NULL,
            winner TEXT,
            player_count INTEGER NOT NULL,
            total_turns INTEGER NOT NULL,
            total_captures INTEGER NOT NULL,
            duration_sec INTEGER NOT NULL,
            players_json TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE cache_kv (
            k TEXT PRIMARY KEY,
            v TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  // ---------- Local match state (offline games) ----------
  static Future<void> saveMatchSnapshot(GameStateSnapshot snap) async {
    final db = await instance;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('local_matches', {
      'match_id': snap.matchId,
      'mode': snap.config.mode.apiName,
      'status': snap.phase,
      'snapshot_json': jsonEncode(snap.toJson()),
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<GameStateSnapshot?> loadMatchSnapshot(String matchId) async {
    final db = await instance;
    final rows = await db.query('local_matches',
        where: 'match_id = ?', whereArgs: [matchId], limit: 1);
    if (rows.isEmpty) return null;
    final j = jsonDecode(rows.first['snapshot_json'] as String) as Map<String, dynamic>;
    return GameStateSnapshot.fromJson(j);
  }

  static Future<List<GameStateSnapshot>> loadUnfinishedMatches() async {
    final db = await instance;
    final rows = await db.query('local_matches',
        where: "status != 'finished'",
        orderBy: 'updated_at DESC',
        limit: 20);
    return rows
        .map((r) => GameStateSnapshot.fromJson(
              jsonDecode(r['snapshot_json'] as String) as Map<String, dynamic>,
            ))
        .toList();
  }

  static Future<void> deleteMatchSnapshot(String matchId) async {
    final db = await instance;
    await db.delete('local_matches', where: 'match_id = ?', whereArgs: [matchId]);
  }

  // ---------- Local history ----------
  static Future<void> saveHistory({
    required String matchId,
    required String mode,
    required String? winner,
    required int playerCount,
    required int totalTurns,
    required int totalCaptures,
    required int durationSec,
    required List<Map<String, dynamic>> players,
  }) async {
    final db = await instance;
    await db.insert('local_history', {
      'match_id': matchId,
      'mode': mode,
      'winner': winner,
      'player_count': playerCount,
      'total_turns': totalTurns,
      'total_captures': totalCaptures,
      'duration_sec': durationSec,
      'players_json': jsonEncode(players),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<List<Map<String, dynamic>>> loadHistory({int limit = 50}) async {
    final db = await instance;
    final rows = await db.query('local_history',
        orderBy: 'created_at DESC', limit: limit);
    return rows.map((r) {
      final m = Map<String, dynamic>.from(r);
      m['players'] = jsonDecode(m.remove('players_json') as String);
      return m;
    }).toList();
  }

  // ---------- KV cache ----------
  static Future<void> put(String key, String value) async {
    final db = await instance;
    await db.insert('cache_kv', {
      'k': key,
      'v': value,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<String?> get(String key) async {
    final db = await instance;
    final rows = await db.query('cache_kv',
        where: 'k = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['v'] as String;
  }
}
