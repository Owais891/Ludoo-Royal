import '../entities/board.dart';
import '../entities/move.dart';
import '../entities/player.dart';
import '../entities/player_color.dart';
import '../entities/token.dart';

/// Centralized rule validation. The UI NEVER decides whether a move is legal.
class RuleValidator {
  const RuleValidator();

  /// Returns the destination position for a token given its current pos and dice,
  /// or `null` if the move is illegal (overshoots home).
  int? destinationOf(PlayerColor color, int pos, int dice) {
    if (dice < 1 || dice > 6) return null;

    // At base - must roll 6 to enter.
    if (pos == -1) {
      return dice == 6 ? Board.startPosition[color]! : null;
    }

    // Outer track
    if (pos >= 0 && pos < 52) {
      final stepsBeforeHome = Board.stepsToHomeEntry(color, pos);
      if (dice <= stepsBeforeHome) {
        return (pos + dice) % 52;
      }
      final homeStep = dice - stepsBeforeHome - 1; // 0..5
      if (homeStep >= Board.homePathCells) return null;
      return 52 + homeStep;
    }

    // Home path
    if (pos >= 52 && pos <= 57) {
      final step = pos - 52;
      final newStep = step + dice;
      if (newStep >= Board.homePathCells) return null;
      return 52 + newStep;
    }
    return null;
  }

  /// Whether a specific move is legal.
  bool isMoveLegal(List<Player> players, PlayerColor color, int tokenIndex, int dice) {
    if (dice < 1 || dice > 6) return false;
    final player = players.firstWhere(
      (p) => p.color == color,
      orElse: () => throw StateError('Player $color not found'),
    );
    if (tokenIndex < 0 || tokenIndex >= player.tokens.length) return false;
    final token = player.tokens[tokenIndex];
    if (token.isHome) return false;
    if (token.isAtBase && dice != 6) return false;
    final dest = destinationOf(color, token.position, dice);
    return dest != null;
  }

  /// Evaluate a single token's move without applying it. Returns the resulting Move
  /// or `null` if illegal.
  Move? evaluateTokenMove(
    List<Player> players,
    PlayerColor color,
    int tokenIndex,
    int dice,
  ) {
    if (!isMoveLegal(players, color, tokenIndex, dice)) return null;
    final player = players.firstWhere((p) => p.color == color);
    final token = player.tokens[tokenIndex];
    final dest = destinationOf(color, token.position, dice)!;
    final (captureColor, _) = _captureInfo(players, color, dest);
    return Move(
      tokenIndex: tokenIndex,
      fromPosition: token.position,
      toPosition: dest,
      diceValue: dice,
      willCapture: captureColor != null,
      capturedColor: captureColor?.name,
    );
  }

  /// All legal moves for the current dice value.
  List<Move> getValidMoves(List<Player> players, PlayerColor color, int dice) {
    final player = players.firstWhere((p) => p.color == color);
    final moves = <Move>[];
    for (var i = 0; i < player.tokens.length; i++) {
      final m = evaluateTokenMove(players, color, i, dice);
      if (m != null) moves.add(m);
    }
    return moves;
  }

  /// Returns the color of a single opponent token sitting on `newPos`,
  /// or null if no capture happens. Same-color tokens and pairs (blocks)
  /// are NOT captured.
  (PlayerColor?, List<int>) _captureInfo(
    List<Player> players,
    PlayerColor movingColor,
    int newPos,
  ) {
    if (newPos < 0 || newPos >= 52) return (null, []);
    if (Board.isSafe(newPos)) return (null, []);

    for (final p in players) {
      if (p.color == movingColor) continue;
      final onCell = <int>[];
      for (var i = 0; i < p.tokens.length; i++) {
        if (p.tokens[i].position == newPos) onCell.add(i);
      }
      if (onCell.length == 1) {
        return (p.color, onCell);
      }
      // 2+ tokens = block; not capturable
    }
    return (null, []);
  }

  /// Returns the captured color (or null) if a token of `color` lands on `newPos`.
  PlayerColor? checkCapture(List<Player> players, PlayerColor color, int newPos) {
    final (capColor, _) = _captureInfo(players, color, newPos);
    return capColor;
  }

  /// Whether the player of `color` has won (all 4 tokens home).
  bool checkWin(List<Player> players, PlayerColor color) {
    final player = players.firstWhere((p) => p.color == color);
    return player.tokens.every((t) => t.isHome);
  }
}

/// Free function for ergonomic access from anywhere.
const ruleValidator = RuleValidator();
