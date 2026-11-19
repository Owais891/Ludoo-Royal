/// A row in the game history table.
class MatchHistoryEntry {
  final int matchId;
  final String code;
  final String mode;
  final int? winnerId;
  final String? winnerName;
  final int playerCount;
  final int totalTurns;
  final int totalCaptures;
  final int durationSec;
  final List<dynamic> players;
  final DateTime createdAt;

  MatchHistoryEntry({
    required this.matchId,
    required this.code,
    required this.mode,
    required this.winnerId,
    required this.winnerName,
    required this.playerCount,
    required this.totalTurns,
    required this.totalCaptures,
    required this.durationSec,
    required this.players,
    required this.createdAt,
  });

  factory MatchHistoryEntry.fromJson(Map<String, dynamic> j) => MatchHistoryEntry(
    matchId: (j['match_id'] as num).toInt(),
    code: j['code'] as String? ?? '',
    mode: j['mode'] as String? ?? 'classic',
    winnerId: j['winner_id'] != null ? (j['winner_id'] as num).toInt() : null,
    winnerName: j['winner_name'] as String?,
    playerCount: (j['player_count'] as num?)?.toInt() ?? 0,
    totalTurns: (j['total_turns'] as num?)?.toInt() ?? 0,
    totalCaptures: (j['total_captures'] as num?)?.toInt() ?? 0,
    durationSec: (j['duration_sec'] as num?)?.toInt() ?? 0,
    players: j['players'] as List? ?? const [],
    createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
  );

  String get modeLabel {
    switch (mode) {
      case 'classic':   return 'Classic';
      case 'quick':     return 'Quick';
      case 'private':   return 'Private';
      case 'offline_ai':return 'vs Computer';
      case 'local':     return 'Local';
      default:          return mode;
    }
  }

  String get durationLabel {
    final m = durationSec ~/ 60;
    final s = durationSec % 60;
    return '${m}m ${s}s';
  }
}
