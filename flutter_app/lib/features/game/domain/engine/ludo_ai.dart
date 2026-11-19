import 'dart:math';
import '../entities/board.dart';
import '../entities/move.dart';
import '../entities/player.dart';
import '../entities/player_color.dart';
import '../entities/token.dart';
import '../rules/rule_validator.dart';

/// AI opponent for "Play with Computer" mode. Three difficulty levels.
class LudoAI {
  final String level; // easy | medium | hard
  final RuleValidator rules;
  final Random _rng;

  LudoAI({
    required this.level,
    RuleValidator? rules,
    Random? rng,
  })  : rules = rules ?? const RuleValidator(),
        _rng = rng ?? Random();

  /// Picks the token to move given the current `players`, `color`, and `dice`.
  /// Returns null if no valid move.
  int? chooseMove(List<Player> players, PlayerColor color, int dice) {
    final moves = rules.getValidMoves(players, color, dice);
    if (moves.isEmpty) return null;
    if (moves.length == 1) return moves.first.tokenIndex;

    switch (level.toLowerCase()) {
      case 'easy':
        return _pickEasy(moves);
      case 'medium':
        return _pickMedium(players, color, moves);
      case 'hard':
        return _pickHard(players, color, moves);
      default:
        return _pickMedium(players, color, moves);
    }
  }

  int _pickEasy(List<Move> moves) {
    // Random selection.
    return moves[_rng.nextInt(moves.length)].tokenIndex;
  }

  int _pickMedium(List<Player> players, PlayerColor color, List<Move> moves) {
    // Heuristics:
    // 1) Prefer captures
    // 2) Prefer moves that bring tokens out of base (on 6)
    // 3) Prefer moving tokens closest to home
    final captureMoves = moves.where((m) => m.willCapture).toList();
    if (captureMoves.isNotEmpty) {
      return captureMoves.first.tokenIndex;
    }
    final releaseMoves = moves.where((m) => m.fromPosition == -1).toList();
    if (releaseMoves.isNotEmpty) {
      return releaseMoves.first.tokenIndex;
    }
    // Sort by destination descending - the closer to home the better.
    moves.sort((a, b) => b.toPosition.compareTo(a.toPosition));
    return moves.first.tokenIndex;
  }

  int _pickHard(List<Player> players, PlayerColor color, List<Move> moves) {
    // Smarter heuristics + look-ahead danger check.
    final captureMoves = moves.where((m) => m.willCapture).toList();
    if (captureMoves.isNotEmpty) {
      // Best capture = the one that captures the most-advanced opponent token
      captureMoves.sort((a, b) {
        final aOpp = _findOpponent(players, color, a.toPosition);
        final bOpp = _findOpponent(players, color, b.toPosition);
        return (bOpp?.position ?? 0).compareTo(aOpp?.position ?? 0);
      });
      return captureMoves.first.tokenIndex;
    }

    // Bring tokens out of base if any are still there.
    final me = players.firstWhere((p) => p.color == color);
    final atBase = me.tokens.where((t) => t.isAtBase).length;
    if (atBase > 0) {
      final releaseMoves = moves.where((m) => m.fromPosition == -1).toList();
      if (releaseMoves.isNotEmpty && atBase >= 2) {
        return releaseMoves.first.tokenIndex;
      }
    }

    // Prefer moves that put a token into the home path (very safe).
    final homePathMoves = moves.where((m) => m.toPosition >= 52).toList();
    if (homePathMoves.isNotEmpty) {
      homePathMoves.sort((a, b) => b.toPosition.compareTo(a.toPosition));
      return homePathMoves.first.tokenIndex;
    }

    // Score each remaining move by:
    //  - progression (closer to home is better)
    //  - landing on safe cell is better
    //  - landing in danger zone (within 6 of an opponent) is worse
    var best = moves.first;
    var bestScore = -1 << 30;
    for (final m in moves) {
      var score = m.toPosition; // progression
      if (Board.isSafe(m.toPosition)) score += 30;
      // Danger: is there an opponent within 6 cells behind this token on the outer track?
      if (m.toPosition < 52) {
        final danger = _dangerScore(players, color, m.toPosition);
        score -= danger * 5;
      }
      if (score > bestScore) {
        bestScore = score;
        best = m;
      }
    }
    return best.tokenIndex;
  }

  Token? _findOpponent(List<Player> players, PlayerColor me, int pos) {
    for (final p in players) {
      if (p.color == me) continue;
      for (final t in p.tokens) {
        if (t.position == pos) return t;
      }
    }
    return null;
  }

  int _dangerScore(List<Player> players, PlayerColor me, int pos) {
    int danger = 0;
    if (pos < 0 || pos >= 52) return 0;
    for (final p in players) {
      if (p.color == me) continue;
      for (final t in p.tokens) {
        if (t.position < 0 || t.position >= 52) continue;
        final dist = (pos - t.position + 52) % 52;
        if (dist >= 1 && dist <= 6) danger++;
      }
    }
    return danger;
  }
}
