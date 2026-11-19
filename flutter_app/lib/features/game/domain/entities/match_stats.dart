import 'player.dart';
import 'player_color.dart';
import 'token.dart';

/// Match statistics tracked for display & persistence.
class MatchStats {
  int totalTurns;
  int totalCaptures;
  int totalDiceRolls;
  Map<PlayerColor, int> capturesPerColor;
  Map<PlayerColor, int> sixesRolled;
  Map<PlayerColor, int> onesRolled;
  PlayerColor? winner;
  DateTime? startedAt;
  DateTime? finishedAt;

  MatchStats({
    this.totalTurns = 0,
    this.totalCaptures = 0,
    this.totalDiceRolls = 0,
    Map<PlayerColor, int>? capturesPerColor,
    Map<PlayerColor, int>? sixesRolled,
    Map<PlayerColor, int>? onesRolled,
    this.winner,
    this.startedAt,
    this.finishedAt,
  })  : capturesPerColor = capturesPerColor ?? {},
        sixesRolled = sixesRolled ?? {},
        onesRolled = onesRolled ?? {};

  void recordRoll(PlayerColor color, int value) {
    totalDiceRolls++;
    if (value == 6) {
      sixesRolled[color] = (sixesRolled[color] ?? 0) + 1;
    } else if (value == 1) {
      onesRolled[color] = (onesRolled[color] ?? 0) + 1;
    }
  }

  void recordCapture(PlayerColor byColor) {
    totalCaptures++;
    capturesPerColor[byColor] = (capturesPerColor[byColor] ?? 0) + 1;
  }

  Map<String, dynamic> toJson() => {
    'totalTurns': totalTurns,
    'totalCaptures': totalCaptures,
    'totalDiceRolls': totalDiceRolls,
    'capturesPerColor': capturesPerColor.map((k, v) => MapEntry(k.name, v)),
    'sixesRolled': sixesRolled.map((k, v) => MapEntry(k.name, v)),
    'onesRolled': onesRolled.map((k, v) => MapEntry(k.name, v)),
    'winner': winner?.name,
    'startedAt': startedAt?.toIso8601String(),
    'finishedAt': finishedAt?.toIso8601String(),
  };

  factory MatchStats.fromJson(Map<String, dynamic> j) => MatchStats(
    totalTurns: (j['totalTurns'] as num?)?.toInt() ?? 0,
    totalCaptures: (j['totalCaptures'] as num?)?.toInt() ?? 0,
    totalDiceRolls: (j['totalDiceRolls'] as num?)?.toInt() ?? 0,
    capturesPerColor: (j['capturesPerColor'] as Map?)?.map(
        (k, v) => MapEntry(PlayerColorX.fromName(k), v as int)) ?? {},
    sixesRolled: (j['sixesRolled'] as Map?)?.map(
        (k, v) => MapEntry(PlayerColorX.fromName(k), v as int)) ?? {},
    onesRolled: (j['onesRolled'] as Map?)?.map(
        (k, v) => MapEntry(PlayerColorX.fromName(k), v as int)) ?? {},
    winner: j['winner'] != null ? PlayerColorX.fromName(j['winner']) : null,
    startedAt: j['startedAt'] != null ? DateTime.tryParse(j['startedAt']) : null,
    finishedAt: j['finishedAt'] != null ? DateTime.tryParse(j['finishedAt']) : null,
  );
}
