import 'player_color.dart';

/// A single event that happened during a match - used for animations & logging.
class GameEvent {
  final GameEventType type;
  final PlayerColor? playerColor;
  final int? diceValue;
  final int? tokenIndex;
  final int? fromPosition;
  final int? toPosition;
  final PlayerColor? capturedColor;
  final List<int>? capturedTokenIndices;
  final String? message;
  final DateTime at;

  GameEvent({
    required this.type,
    this.playerColor,
    this.diceValue,
    this.tokenIndex,
    this.fromPosition,
    this.toPosition,
    this.capturedColor,
    this.capturedTokenIndices,
    this.message,
    DateTime? at,
  }) : at = at ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'playerColor': playerColor?.name,
    'diceValue': diceValue,
    'tokenIndex': tokenIndex,
    'fromPosition': fromPosition,
    'toPosition': toPosition,
    'capturedColor': capturedColor?.name,
    'capturedTokenIndices': capturedTokenIndices,
    'message': message,
    'at': at.toIso8601String(),
  };
}

enum GameEventType {
  matchStarted,
  turnStarted,
  diceRolled,
  noValidMove,
  moveStarted,
  moveFinished,
  capture,
  tokenReachedHome,
  extraTurn,
  threeSixesForfeit,
  win,
  matchFinished,
  turnAdvanced,
  disconnected,
  reconnected,
}
