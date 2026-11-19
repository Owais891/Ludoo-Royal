import 'match_stats.dart';
import 'player.dart';
import 'player_color.dart';
import '../../data/models/match_config.dart';

/// Snapshot of an entire match state at a point in time.
/// Used for save/restore and for syncing between client and server.
class GameStateSnapshot {
  final String matchId;
  final MatchConfig config;
  final List<Player> players;
  final PlayerColor currentPlayer;
  final int? diceValue;
  final String phase;          // 'waiting'|'rolling'|'moving'|'finished'
  final int turnNumber;
  final int sixCounter;
  final MatchStats stats;
  final List<String> activeColors;
  final DateTime savedAt;

  const GameStateSnapshot({
    required this.matchId,
    required this.config,
    required this.players,
    required this.currentPlayer,
    this.diceValue,
    required this.phase,
    required this.turnNumber,
    required this.sixCounter,
    required this.stats,
    required this.activeColors,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'config': config.toJson(),
    'players': players.map((p) => p.toJson()).toList(),
    'currentPlayer': currentPlayer.name,
    'diceValue': diceValue,
    'phase': phase,
    'turnNumber': turnNumber,
    'sixCounter': sixCounter,
    'stats': stats.toJson(),
    'activeColors': activeColors,
    'savedAt': savedAt.toIso8601String(),
  };

  factory GameStateSnapshot.fromJson(Map<String, dynamic> j) => GameStateSnapshot(
    matchId: j['matchId'] as String,
    config: MatchConfig.fromJson(j['config'] as Map<String, dynamic>),
    players: (j['players'] as List)
        .map((e) => Player.fromJson(e as Map<String, dynamic>))
        .toList(),
    currentPlayer: PlayerColorX.fromName(j['currentPlayer'] as String),
    diceValue: j['diceValue'] as int?,
    phase: j['phase'] as String? ?? 'rolling',
    turnNumber: (j['turnNumber'] as num?)?.toInt() ?? 0,
    sixCounter: (j['sixCounter'] as num?)?.toInt() ?? 0,
    stats: MatchStats.fromJson(j['stats'] as Map<String, dynamic>? ?? {}),
    activeColors: (j['activeColors'] as List? ?? [])
        .map((e) => e.toString())
        .toList(),
    savedAt: j['savedAt'] != null ? DateTime.parse(j['savedAt']) : DateTime.now(),
  );
}
