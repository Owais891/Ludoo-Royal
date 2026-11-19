/// Ludo Royale - Application-wide constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'Ludo Royale';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Roll. Race. Royale.';

  /// Local SQLite database file name.
  static const String localDbName = 'ludo_royale.db';
  static const int localDbVersion = 1;

  /// Default backend API base URL.
  /// For local development with XAMPP, this is typically your computer's IP.
  /// Use 10.0.2.2 from the Android emulator to reach host loopback.
  static const String defaultApiBaseUrl = 'http://10.0.2.2:8000';

  /// Match polling interval (ms) for online games when WebSockets aren't available.
  static const int onlinePollIntervalMs = 1500;

  /// Ludo engine constants.
  static const int tokensPerPlayer = 4;
  static const int outerTrackCells = 52;
  static const int homePathCells = 6; // 5 colored + 1 final
  static const int maxPlayers = 4;
  static const int threeSixesLimit = 3;

  /// Token states.
  static const int positionAtBase = -1;
  static const int positionAtHome = 57;

  /// Player colors (in turn order).
  static const List<String> colorNames = ['red', 'green', 'yellow', 'blue'];

  /// Safe cells (star squares) on the outer track.
  static const List<int> safeCells = [0, 8, 13, 21, 26, 34, 39, 47];

  /// Starting positions for each color on the outer track.
  static const Map<String, int> startPositions = {
    'red':    0,
    'green':  13,
    'yellow': 26,
    'blue':   39,
  };

  /// Home-entry position (last cell of outer track before turning into the
  /// colored home path) for each color.
  static const Map<String, int> homeEntry = {
    'red':    50,
    'green':  11,
    'yellow': 24,
    'blue':   37,
  };

  /// Rewards.
  static const int startingCoins = 500;
  static const int startingGems = 10;
  static const int matchWinBaseCoins = 200;
}

/// Ludo Royale color palette.
class AppColors {
  AppColors._();

  // Player tokens
  static const int redValue    = 0xFFE53935;
  static const int greenValue  = 0xFF43A047;
  static const int yellowValue = 0xFFFDD835;
  static const int blueValue   = 0xFF1E88E5;

  // Brand
  static const int deepPurple  = 0xFF4A148C;
  static const int royalBlue   = 0xFF1565C0;
  static const int goldenYellow = 0xFFFFC107;
  static const int darkNavy     = 0xFF0A0E27;
  static const int darkPurple   = 0xFF1A1033;
  static const int cardPurple   = 0xFF261845;
  static const int cardBlue     = 0xFF1B2154;
  static const int textPrimary  = 0xFFFFFFFF;
  static const int textSecondary= 0xFFB0B5D6;
}
