import 'player_color.dart';

/// Lifecycle phase of a Ludo match.
enum GamePhase {
  waiting,    // not started
  rolling,    // current player must roll the dice
  moving,     // current player must pick a token to move
  animating,  // a capture/move animation is playing
  finished,   // match ended
}

/// A single token belonging to a player.
class Token {
  final PlayerColor color;
  final int index;       // 0..3 within the player's 4 tokens
  int position;          // -1 = at base, 0..51 = outer track, 52..57 = home path, 57 = home

  Token({
    required this.color,
    required this.index,
    this.position = -1,
  });

  bool get isAtBase => position == -1;
  bool get isOnOuterTrack => position >= 0 && position < 52;
  bool get isOnHomePath => position >= 52 && position <= 57;
  bool get isHome => position == 57;

  /// Clone for immutable updates.
  Token copyWith({int? position}) => Token(
    color: color,
    index: index,
    position: position ?? this.position,
  );

  Map<String, dynamic> toJson() => {
    'color': color.name,
    'index': index,
    'position': position,
  };

  factory Token.fromJson(Map<String, dynamic> json) => Token(
    color: PlayerColorX.fromName(json['color'] as String),
    index: (json['index'] as num).toInt(),
    position: (json['position'] as num).toInt(),
  );

  @override
  String toString() => 'Token(${color.name}#$index @ $position)';
}
