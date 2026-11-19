/// Game mode identifiers used in the engine and stored in the database.
enum GameMode {
  classic,
  quick,
  private,
  offlineAI,
  local;

  String get label {
    switch (this) {
      case GameMode.classic:   return 'Classic Ludo';
      case GameMode.quick:     return 'Quick Ludo';
      case GameMode.private:   return 'Private Room';
      case GameMode.offlineAI: return 'Play with Computer';
      case GameMode.local:     return 'Local Multiplayer';
    }
  }

  String get apiName {
    switch (this) {
      case GameMode.classic:   return 'classic';
      case GameMode.quick:     return 'quick';
      case GameMode.private:   return 'private';
      case GameMode.offlineAI: return 'offline_ai';
      case GameMode.local:     return 'local';
    }
  }

  static GameMode fromApi(String s) {
    switch (s) {
      case 'classic':    return GameMode.classic;
      case 'quick':      return GameMode.quick;
      case 'private':    return GameMode.private;
      case 'offline_ai': return GameMode.offlineAI;
      case 'local':      return GameMode.local;
      default:           return GameMode.classic;
    }
  }
}

/// Difficulty for AI opponents.
enum AILevel { easy, medium, hard }

/// Configuration of a Ludo match.
class MatchConfig {
  final String matchId;
  final GameMode mode;
  final int maxPlayers;
  final int entryFee;
  final AILevel? aiLevel;
  final int winningScoreCoins;

  const MatchConfig({
    required this.matchId,
    required this.mode,
    required this.maxPlayers,
    this.entryFee = 0,
    this.aiLevel,
    this.winningScoreCoins = 200,
  });

  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'mode': mode.apiName,
    'maxPlayers': maxPlayers,
    'entryFee': entryFee,
    'aiLevel': aiLevel?.name,
    'winningScoreCoins': winningScoreCoins,
  };

  factory MatchConfig.fromJson(Map<String, dynamic> j) => MatchConfig(
    matchId: j['matchId']?.toString() ?? '',
    mode: GameMode.fromApi(j['mode'] as String? ?? 'classic'),
    maxPlayers: (j['maxPlayers'] as num?)?.toInt() ?? 4,
    entryFee: (j['entryFee'] as num?)?.toInt() ?? 0,
    aiLevel: j['aiLevel'] != null
        ? AILevel.values.firstWhere(
            (e) => e.name == j['aiLevel'],
            orElse: () => AILevel.medium,
          )
        : null,
    winningScoreCoins: (j['winningScoreCoins'] as num?)?.toInt() ?? 200,
  );
}
