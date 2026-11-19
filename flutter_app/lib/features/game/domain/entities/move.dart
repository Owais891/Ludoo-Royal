/// A dice value 1..6 (immutable).
class DiceValue {
  final int value;
  const DiceValue(this.value)
      : assert(value >= 1 && value <= 6);

  @override
  bool operator ==(Object other) => other is DiceValue && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => 'DiceValue($value)';
}

/// Describes a single move a player can make with the dice value.
class Move {
  final int tokenIndex;       // 0..3
  final int fromPosition;    // -1, 0..51, 52..57
  final int toPosition;      // -1, 0..51, 52..57 (57 = home)
  final int diceValue;
  final bool willCapture;
  final String? capturedColor; // color of the token that would be captured

  const Move({
    required this.tokenIndex,
    required this.fromPosition,
    required this.toPosition,
    required this.diceValue,
    this.willCapture = false,
    this.capturedColor,
  });

  Map<String, dynamic> toJson() => {
    'tokenIndex': tokenIndex,
    'fromPosition': fromPosition,
    'toPosition': toPosition,
    'diceValue': diceValue,
    'willCapture': willCapture,
    'capturedColor': capturedColor,
  };

  @override
  String toString() =>
      'Move(token#$tokenIndex $fromPosition->$toPosition, dice=$diceValue, capture=$willCapture)';
}
