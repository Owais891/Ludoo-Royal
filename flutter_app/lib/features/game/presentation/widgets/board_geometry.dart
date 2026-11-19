import '../../domain/entities/player_color.dart';

/// Geometric mapping of the 15x15 Ludo board.
///
/// Position numbering (0..51 = outer track, 52..57 = home path):
///
///   0..12  top arm + first corner
///   13..25 right arm + second corner
///   26..38 bottom arm + third corner
///   39..51 left arm + fourth corner
///
/// Each color's home path (52..57) goes from the side toward the center.
class BoardGeometry {
  BoardGeometry._();

  static const int gridSize = 15;

  /// (col, row) for each outer-track position 0..51.
  /// Index = position, value = (col, row) on the 15x15 grid.
  static const List<(int, int)> outerCells = [
    // 0..12 - red start, going right along row 6 then up col 6 to top-right corner
    (1, 6),  (2, 6),  (3, 6),  (4, 6),  (5, 6),     // 0..4
    (6, 5),  (6, 4),  (6, 3),  (6, 2),  (6, 1),     // 5..9
    (6, 0),  (7, 0),  (8, 0),                          // 10..12
    // 13..25 - green start, going down col 8 then right along row 6 to bottom-right corner
    (8, 1),  (8, 2),  (8, 3),  (8, 4),  (8, 5),     // 13..17
    (9, 6),  (10, 6), (11, 6), (12, 6), (13, 6),    // 18..22
    (14, 6), (14, 7), (14, 8),                          // 23..25
    // 26..38 - yellow start, going left along row 8 then down col 8 to bottom-left corner
    (13, 8), (12, 8), (11, 8), (10, 8), (9, 8),     // 26..30
    (8, 9),  (8, 10), (8, 11), (8, 12), (8, 13),    // 31..35
    (8, 14), (7, 14), (6, 14),                          // 36..38
    // 39..51 - blue start, going up col 6 then left along row 8 to top-left corner
    (6, 13), (6, 12), (6, 11), (6, 10), (6, 9),     // 39..43
    (5, 8),  (4, 8),  (3, 8),  (2, 8),  (1, 8),     // 44..48
    (0, 8),  (0, 7),  (0, 6),                          // 49..51
  ];

  /// Home path cells (52..57) for each color.
  static const Map<PlayerColor, List<(int, int)>> homePaths = {
    PlayerColor.red:    [(1, 7), (2, 7), (3, 7), (4, 7), (5, 7), (6, 7)],
    PlayerColor.green:  [(7, 1), (7, 2), (7, 3), (7, 4), (7, 5), (7, 6)],
    PlayerColor.yellow: [(13, 7), (12, 7), (11, 7), (10, 7), (9, 7), (8, 7)],
    PlayerColor.blue:   [(7, 13), (7, 12), (7, 11), (7, 10), (7, 9), (7, 8)],
  };

  /// Base yard token slots (where the 4 tokens of each color sit before
  /// entering the board). Coordinates are within the 6x6 corner base.
  /// The 4 spots are at (1.5,1.5), (1.5,3.5), (3.5,1.5), (3.5,3.5) within
  /// each base.
  static const Map<PlayerColor, List<(double, double)>> baseSlots = {
    PlayerColor.red:    [(1.5, 1.5), (1.5, 3.5), (3.5, 1.5), (3.5, 3.5)],
    PlayerColor.green:  [(10.5, 1.5), (10.5, 3.5), (12.5, 1.5), (12.5, 3.5)],
    PlayerColor.yellow: [(10.5, 10.5), (10.5, 12.5), (12.5, 10.5), (12.5, 12.5)],
    PlayerColor.blue:   [(1.5, 10.5), (1.5, 12.5), (3.5, 10.5), (3.5, 12.5)],
  };

  /// Top-left (col, row) of each color's 6x6 base yard.
  static const Map<PlayerColor, (int, int)> baseOrigin = {
    PlayerColor.red:    (0, 0),
    PlayerColor.green:  (9, 0),
    PlayerColor.yellow: (9, 9),
    PlayerColor.blue:   (0, 9),
  };

  /// Returns the (col, row) cell coordinate for a given token position.
  /// position = -1 means "at base" (use baseSlots[color][tokenIndex]).
  /// position = 0..51 = outer track
  /// position = 52..57 = home path
  static (double, double) cellFor({
    required PlayerColor color,
    required int tokenIndex,
    required int position,
  }) {
    if (position == -1) {
      final slot = baseSlots[color]![tokenIndex];
      return slot;
    }
    if (position >= 0 && position < 52) {
      final (col, row) = outerCells[position];
      return (col.toDouble(), row.toDouble());
    }
    if (position >= 52 && position <= 57) {
      final hp = homePaths[color]!;
      final (col, row) = hp[position - 52];
      return (col.toDouble(), row.toDouble());
    }
    return (7.5, 7.5); // fallback center
  }

  /// Safe cells on the outer track (4 start cells + 4 star cells).
  static const List<int> safeCells = [0, 8, 13, 21, 26, 34, 39, 47];

  /// Whether a position is a safe cell on the outer track.
  static bool isOuterSafe(int pos) =>
      pos >= 0 && pos < 52 && safeCells.contains(pos);

  /// Whether a position is on a home path (always safe).
  static bool isOnHomePath(int pos) => pos >= 52 && pos <= 57;
}
