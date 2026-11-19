import 'dart:math';

/// Interface for rolling a dice.
abstract class DiceRoller {
  int roll();
}

/// Pseudo-random dice roller used in local games (vs. AI / local multiplayer).
class RandomDiceRoller implements DiceRoller {
  final Random _random;
  RandomDiceRoller([Random? random]) : _random = random ?? Random();

  @override
  int roll() => _random.nextInt(6) + 1;
}

/// Deterministic dice roller — accepts a predefined sequence. Useful for tests.
class DeterministicDiceRoller implements DiceRoller {
  final List<int> _sequence;
  int _cursor = 0;
  DeterministicDiceRoller(this._sequence)
      : assert(_sequence.isNotEmpty);

  @override
  int roll() {
    final v = _sequence[_cursor % _sequence.length];
    _cursor++;
    if (v < 1 || v > 6) {
      throw ArgumentError('Dice value out of range: $v');
    }
    return v;
  }
}

/// A "rigged" roller always returns the same value. Tests only.
class ConstantDiceRoller implements DiceRoller {
  final int value;
  const ConstantDiceRoller(this.value)
      : assert(value >= 1 && value <= 6);

  @override
  int roll() => value;
}
