/// Player colors used throughout the engine.
enum PlayerColor { red, green, yellow, blue }

/// Convert between PlayerColor and the string the backend/API uses.
extension PlayerColorX on PlayerColor {
  String get name {
    switch (this) {
      case PlayerColor.red:    return 'red';
      case PlayerColor.green:  return 'green';
      case PlayerColor.yellow: return 'yellow';
      case PlayerColor.blue:   return 'blue';
    }
  }

  static PlayerColor fromName(String n) {
    switch (n) {
      case 'red':    return PlayerColor.red;
      case 'green':  return PlayerColor.green;
      case 'yellow': return PlayerColor.yellow;
      case 'blue':   return PlayerColor.blue;
      default: throw ArgumentError('Unknown color: $n');
    }
  }

  int get seatIndex {
    switch (this) {
      case PlayerColor.red:    return 0;
      case PlayerColor.green:  return 1;
      case PlayerColor.yellow: return 2;
      case PlayerColor.blue:   return 3;
    }
  }

  static PlayerColor fromSeat(int s) {
    switch (s) {
      case 0: return PlayerColor.red;
      case 1: return PlayerColor.green;
      case 2: return PlayerColor.yellow;
      case 3: return PlayerColor.blue;
      default: throw ArgumentError('Invalid seat $s');
    }
  }

  PlayerColor next(List<PlayerColor> activeColors) {
    if (activeColors.isEmpty) return this;
    final idx = activeColors.indexOf(this);
    final nextIdx = (idx + 1) % activeColors.length;
    return activeColors[nextIdx];
  }
}
