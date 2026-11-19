import 'token.dart';
import 'player_color.dart';

/// A player in a Ludo match. May be a human or an AI.
class Player {
  final String id;          // backend user id or "ai-red" etc.
  final String username;
  final PlayerColor color;
  final bool isAI;
  final String? aiLevel;    // 'easy' | 'medium' | 'hard' | null
  final String? avatarUrl;
  List<Token> tokens;
  bool isReady;
  bool isConnected;
  int? finalRank;
  int captures;

  Player({
    required this.id,
    required this.username,
    required this.color,
    this.isAI = false,
    this.aiLevel,
    this.avatarUrl,
    List<Token>? tokens,
    this.isReady = false,
    this.isConnected = true,
    this.finalRank,
    this.captures = 0,
  }) : tokens = tokens ?? _initialTokens(color);

  static List<Token> _initialTokens(PlayerColor c) =>
      List.generate(4, (i) => Token(color: c, index: i, position: -1));

  bool get isLocalAI => isAI;
  bool get hasWon => tokens.every((t) => t.isHome);
  int get tokensHome => tokens.where((t) => t.isHome).length;
  int get tokensOnBoard => tokens.where((t) => !t.isAtBase && !t.isHome).length;

  Player copyWith({
    List<Token>? tokens,
    bool? isReady,
    bool? isConnected,
    int? finalRank,
    int? captures,
  }) => Player(
    id: id,
    username: username,
    color: color,
    isAI: isAI,
    aiLevel: aiLevel,
    avatarUrl: avatarUrl,
    tokens: tokens ?? this.tokens,
    isReady: isReady ?? this.isReady,
    isConnected: isConnected ?? this.isConnected,
    finalRank: finalRank ?? this.finalRank,
    captures: captures ?? this.captures,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'color': color.name,
    'isAI': isAI,
    'aiLevel': aiLevel,
    'avatarUrl': avatarUrl,
    'tokens': tokens.map((t) => t.toJson()).toList(),
    'isReady': isReady,
    'isConnected': isConnected,
    'finalRank': finalRank,
    'captures': captures,
  };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
    id: json['id']?.toString() ?? '',
    username: json['username'] as String? ?? 'Player',
    color: PlayerColorX.fromName(json['color'] as String? ?? 'red'),
    isAI: (json['isAI'] as bool?) ?? false,
    aiLevel: json['aiLevel'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
    tokens: (json['tokens'] as List<dynamic>?)
        ?.map((e) => Token.fromJson(e as Map<String, dynamic>))
        .toList(),
    isReady: (json['isReady'] as bool?) ?? false,
    isConnected: (json['isConnected'] as bool?) ?? true,
    finalRank: json['finalRank'] as int?,
    captures: (json['captures'] as num?)?.toInt() ?? 0,
  );
}
