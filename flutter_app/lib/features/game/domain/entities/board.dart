import 'player_color.dart';

/// Static geometry of a Ludo board - the 52-cell outer track plus 4 home paths.
class Board {
  Board._();

  static const int outerCells = 52;
  static const int homePathCells = 6;
  static const int finalPosition = 57;

  /// Where each color enters the outer track when a 6 is rolled.
  static const Map<PlayerColor, int> startPosition = {
    PlayerColor.red:    0,
    PlayerColor.green:  13,
    PlayerColor.yellow: 26,
    PlayerColor.blue:   39,
  };

  /// The last outer-track index before the token turns into its colored home path.
  static const Map<PlayerColor, int> homeEntry = {
    PlayerColor.red:    50,
    PlayerColor.green:  11,
    PlayerColor.yellow: 24,
    PlayerColor.blue:   37,
  };

  /// Safe cells (stars + start cells). Tokens on these cannot be captured.
  static const List<int> safeCells = [0, 8, 13, 21, 26, 34, 39, 47];

  static bool isSafe(int position) {
    if (position < 0) return false;
    if (position >= 52) return true; // home path is always safe
    return safeCells.contains(position);
  }

  /// Distance (in cells) from `pos` to the home entry for `color`.
  /// Returns the count of outer-track steps remaining before turning into home path.
  static int stepsToHomeEntry(PlayerColor color, int pos) {
    if (pos < 0 || pos >= 52) return 0;
    final entry = homeEntry[color]!;
    return (entry - pos + outerCells) % outerCells;
  }
}
