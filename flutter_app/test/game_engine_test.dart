import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_royale/features/game/data/models/match_config.dart';
import 'package:ludo_royale/features/game/domain/engine/dice_roller.dart';
import 'package:ludo_royale/features/game/domain/engine/game_engine.dart';
import 'package:ludo_royale/features/game/domain/engine/ludo_ai.dart';
import 'package:ludo_royale/features/game/domain/entities/board.dart';
import 'package:ludo_royale/features/game/domain/entities/game_state_snapshot.dart';
import 'package:ludo_royale/features/game/domain/entities/player.dart';
import 'package:ludo_royale/features/game/domain/entities/player_color.dart';
import 'package:ludo_royale/features/game/domain/entities/token.dart';
import 'package:ludo_royale/features/game/domain/rules/rule_validator.dart';

Player _makePlayer(PlayerColor c, List<int> positions) {
  return Player(
    id: c.name,
    username: c.name.toUpperCase(),
    color: c,
    tokens: List.generate(4, (i) => Token(color: c, index: i, position: positions[i])),
  );
}

List<Player> _twoPlayers({
  List<int> redPositions = const [-1, -1, -1, -1],
  List<int> greenPositions = const [-1, -1, -1, -1],
}) {
  return [
    _makePlayer(PlayerColor.red, redPositions),
    _makePlayer(PlayerColor.green, greenPositions),
  ];
}

void main() {
  group('RuleValidator', () {
    final r = const RuleValidator();

    test('Token at base requires a 6 to leave', () {
      final players = _twoPlayers();
      expect(r.isMoveLegal(players, PlayerColor.red, 0, 5), isFalse);
      expect(r.isMoveLegal(players, PlayerColor.red, 0, 6), isTrue);
    });

    test('Token already at home cannot move', () {
      final players = _twoPlayers(redPositions: [57, -1, -1, -1]);
      expect(r.isMoveLegal(players, PlayerColor.red, 0, 3), isFalse);
    });

    test('Move overshooting home is illegal', () {
      // Red token on last home cell (pos 56), rolling 2 would overshoot
      final players = _twoPlayers(redPositions: [56, -1, -1, -1]);
      expect(r.isMoveLegal(players, PlayerColor.red, 0, 2), isFalse);
      expect(r.isMoveLegal(players, PlayerColor.red, 0, 1), isTrue);
    });

    test('getValidMoves returns only legal token indices', () {
      final players = _twoPlayers(redPositions: [-1, 57, 50, 57]);
      // Only token #2 (at pos 50) can move with dice=1
      final moves = r.getValidMoves(players, PlayerColor.red, 1);
      expect(moves.length, 1);
      expect(moves.first.tokenIndex, 2);
    });

    test('A 6 lets a token leave base AND moves other tokens', () {
      final players = _twoPlayers(redPositions: [-1, 0, 0, 0]);
      final moves = r.getValidMoves(players, PlayerColor.red, 6);
      // 4 valid: leave base + 3 on board
      expect(moves.length, 4);
    });

    test('Safe cell prevents capture', () {
      // Red at pos 0 (safe start), green at pos 0 too - no capture
      final players = _twoPlayers(redPositions: [0, -1, -1, -1],
                                  greenPositions: [0, -1, -1, -1]);
      final cap = r.checkCapture(players, PlayerColor.red, 0);
      expect(cap, isNull);
    });

    test('Single opponent on non-safe cell gets captured', () {
      // Red moves to pos 5, green is on pos 5 -> capture
      final players = _twoPlayers(redPositions: [0, -1, -1, -1],
                                  greenPositions: [5, -1, -1, -1]);
      final cap = r.checkCapture(players, PlayerColor.red, 5);
      expect(cap, PlayerColor.green);
    });

    test('Pair on same cell forms block - not captured', () {
      final players = _twoPlayers(
        redPositions: [-1, -1, -1, -1],
        greenPositions: [5, 5, -1, -1],
      );
      final cap = r.checkCapture(players, PlayerColor.red, 5);
      expect(cap, isNull);
    });

    test('Win is detected when all 4 tokens are home', () {
      final players = _twoPlayers(redPositions: [57, 57, 57, 57]);
      expect(r.checkWin(players, PlayerColor.red), isTrue);
      final players2 = _twoPlayers(redPositions: [57, 57, 57, 56]);
      expect(r.checkWin(players2, PlayerColor.red), isFalse);
    });
  });

  group('Board geometry', () {
    test('Safe cells include the 4 starts + 4 stars', () {
      expect(Board.safeCells.length, 8);
      expect(Board.safeCells.contains(0), isTrue);
      expect(Board.safeCells.contains(13), isTrue);
      expect(Board.safeCells.contains(26), isTrue);
      expect(Board.safeCells.contains(39), isTrue);
      // Stars
      expect(Board.safeCells.contains(8), isTrue);
      expect(Board.safeCells.contains(21), isTrue);
      expect(Board.safeCells.contains(34), isTrue);
      expect(Board.safeCells.contains(47), isTrue);
    });

    test('stepsToHomeEntry is correct', () {
      // Red starts at 0, home entry at 50 -> 50 steps
      expect(Board.stepsToHomeEntry(PlayerColor.red, 0), 50);
      // Green starts at 13, home entry at 11 -> 50 steps (13 -> 11 around)
      expect(Board.stepsToHomeEntry(PlayerColor.green, 13), 50);
      // Yellow starts at 26, home entry at 24 -> 50 steps
      expect(Board.stepsToHomeEntry(PlayerColor.yellow, 26), 50);
      // Blue starts at 39, home entry at 37 -> 50 steps
      expect(Board.stepsToHomeEntry(PlayerColor.blue, 39), 50);
    });
  });

  group('GameEngine end-to-end', () {
    test('Rolling a 6 brings a token out of base', () {
      final engine = GameEngine(
        diceRoller: DeterministicDiceRoller([6]),
      );
      final players = _twoPlayers(redPositions: [-1, 57, 57, 57]);
      engine.startMatch(
        config: MatchConfig(matchId: 't1', mode: GameMode.classic, maxPlayers: 2),
        players: players,
      );
      final v = engine.rollDice();
      expect(v, 6);
      expect(engine.phase, 'moving');
      final moves = engine.getValidMoves(PlayerColor.red);
      expect(moves.length, 1);
      expect(moves.first.fromPosition, -1);
      engine.moveToken(moves.first.tokenIndex);
      expect(engine.players.first.tokens.first.position, 0);
    });

    test('Three consecutive sixes forfeits the turn', () {
      final engine = GameEngine(
        diceRoller: DeterministicDiceRoller([6, 6, 6, 1]),
      );
      final players = _twoPlayers();
      engine.startMatch(
        config: MatchConfig(matchId: 't2', mode: GameMode.classic, maxPlayers: 2),
        players: players,
      );
      engine.rollDice(); // 6
      engine.moveToken(0); // bring first token out
      engine.rollDice(); // 6 - extra turn
      engine.moveToken(1); // bring 2nd out
      engine.rollDice(); // 6 - third six, forfeit
      // After 3 sixes, turn should advance to next player (green)
      expect(engine.currentPlayer, PlayerColor.green);
    });

    test('Capture grants extra turn to attacker', () {
      // Red at pos 4, green at pos 5 (non-safe). Red rolls 1 -> captures green.
      final players = _twoPlayers(
        redPositions: [4, -1, -1, -1],
        greenPositions: [5, -1, -1, -1],
      );
      final engine = GameEngine(diceRoller: DeterministicDiceRoller([1]));
      engine.startMatch(
        config: MatchConfig(matchId: 't3', mode: GameMode.classic, maxPlayers: 2),
        players: players,
      );
      engine.rollDice();
      engine.moveToken(0);
      // Red should still be the current player (extra turn from capture)
      expect(engine.currentPlayer, PlayerColor.red);
      // Green token should be back at base
      expect(engine.players[1].tokens[0].position, -1);
    });

    test('Win detection when all tokens reach home', () {
      final players = _twoPlayers(
        redPositions: [56, 57, 57, 57],
      );
      final engine = GameEngine(diceRoller: DeterministicDiceRoller([1]));
      engine.startMatch(
        config: MatchConfig(matchId: 't4', mode: GameMode.classic, maxPlayers: 2),
        players: players,
      );
      engine.rollDice();
      engine.moveToken(0); // moves to 57
      expect(engine.phase, 'finished');
      expect(engine.stats.winner, PlayerColor.red);
    });

    test('Snapshot round-trips through JSON', () {
      final players = _twoPlayers(redPositions: [10, -1, -1, -1],
                                   greenPositions: [20, -1, -1, -1]);
      final engine = GameEngine();
      engine.startMatch(
        config: MatchConfig(matchId: 't5', mode: GameMode.classic, maxPlayers: 2),
        players: players,
      );
      engine.rollDice();
      final snap = engine.snapshot();
      final json = snap.toJson();
      final restored = GameStateSnapshot.fromJson(json);
      final engine2 = GameEngine();
      engine2.restoreFromSnapshot(restored);
      expect(engine2.players.first.tokens.first.position, 10);
      expect(engine2.players.last.tokens.first.position, 20);
    });
  });

  group('LudoAI', () {
    test('Easy AI returns a valid move when moves exist', () {
      final players = _twoPlayers();
      final ai = LudoAI(level: 'easy');
      final move = ai.chooseMove(players, PlayerColor.red, 6);
      expect(move, isNotNull);
      expect(move, inInclusiveRange(0, 3));
    });

    test('Hard AI prefers captures when available', () {
      // Red at pos 4, green at pos 5. Red rolls 1 -> capture available.
      final players = _twoPlayers(
        redPositions: [4, 0, 0, 0],
        greenPositions: [5, -1, -1, -1],
      );
      final ai = LudoAI(level: 'hard');
      final move = ai.chooseMove(players, PlayerColor.red, 1);
      expect(move, 0); // token 0 is the one that can capture
    });

    test('AI returns null when no valid moves', () {
      final players = _twoPlayers();
      final ai = LudoAI(level: 'medium');
      // No 6, all tokens at base -> no valid moves
      final move = ai.chooseMove(players, PlayerColor.red, 3);
      expect(move, isNull);
    });
  });

  group('DiceRoller', () {
    test('DeterministicDiceRoller returns sequence then loops', () {
      final r = DeterministicDiceRoller([1, 3, 5]);
      expect(r.roll(), 1);
      expect(r.roll(), 3);
      expect(r.roll(), 5);
      expect(r.roll(), 1); // wraps
    });

    test('RandomDiceRoller returns values in 1..6', () {
      final r = RandomDiceRoller();
      for (var i = 0; i < 100; i++) {
        final v = r.roll();
        expect(v, inInclusiveRange(1, 6));
      }
    });
  });
}
