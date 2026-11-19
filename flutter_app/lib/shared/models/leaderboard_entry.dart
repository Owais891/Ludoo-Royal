/// A leaderboard row.
class LeaderboardEntry {
  final int userId;
  final String username;
  final String? avatarUrl;
  final int totalMatches;
  final int totalWins;
  final int totalLosses;
  final int totalCaptures;
  final int playerLevel;
  final double winRate;

  LeaderboardEntry({
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.totalMatches,
    required this.totalWins,
    required this.totalLosses,
    required this.totalCaptures,
    required this.playerLevel,
    required this.winRate,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
    userId: (j['id'] as num).toInt(),
    username: j['username'] as String? ?? 'Player',
    avatarUrl: j['avatar_url'] as String?,
    totalMatches: (j['total_matches'] as num?)?.toInt() ?? 0,
    totalWins: (j['total_wins'] as num?)?.toInt() ?? 0,
    totalLosses: (j['total_losses'] as num?)?.toInt() ?? 0,
    totalCaptures: (j['total_captures'] as num?)?.toInt() ?? 0,
    playerLevel: (j['player_level'] as num?)?.toInt() ?? 1,
    winRate: (j['win_rate'] as num?)?.toDouble() ?? 0.0,
  );
}
