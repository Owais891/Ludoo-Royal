import '../entities/board.dart';
import '../entities/game_event.dart';
import '../entities/game_state_snapshot.dart';
import '../entities/match_stats.dart';
import '../entities/move.dart';
import '../entities/player.dart';
import '../entities/player_color.dart';
import '../entities/token.dart';
import '../rules/rule_validator.dart';
import 'dice_roller.dart';
import '../../data/models/match_config.dart';

/// Centralized Ludo game engine. UI-independent.
///
/// Flow:
/// 1. startMatch() builds initial players.
/// 2. rollDice() emits a dice value; engine decides if the player has valid moves.
/// 3. moveToken(tokenIndex) applies the move; engine detects captures / wins / extra turn.
/// 4. advanceTurn() rotates to the next active seat (unless extra turn was granted).
class GameEngine {
  final RuleValidator rules;
  DiceRoller diceRoller;

  late MatchConfig config;
  late List<Player> players;
  late PlayerColor currentPlayer;
  int? diceValue;
  String phase; // waiting | rolling | moving | finished
  int turnNumber;
  int sixCounter;
  final MatchStats stats;
  final List<GameEvent> events = [];
  final List<PlayerColor> activeColors;

  GameEngine({RuleValidator? rules, DiceRoller? diceRoller})
      : rules = rules ?? const RuleValidator(),
        diceRoller = diceRoller ?? RandomDiceRoller(),
        phase = 'waiting',
        turnNumber = 0,
        sixCounter = 0,
        stats = MatchStats(),
        activeColors = [],
        currentPlayer = PlayerColor.red;

  /// Initialise a new match.
  void startMatch({
    required MatchConfig config,
    required List<Player> players,
  }) {
    this.config = config;
    this.players = players;
    activeColors
      ..clear()
      ..addAll(players.map((p) => p.color));
    currentPlayer = players.first.color;
    diceValue = null;
    phase = 'rolling';
    sixCounter = 0;
    turnNumber = 1;
    stats
      ..startedAt = DateTime.now()
      ..winner = null
      ..finishedAt = null
      ..totalTurns = 0
      ..totalCaptures = 0
      ..totalDiceRolls = 0
      ..capturesPerColor.clear()
      ..sixesRolled.clear()
      ..onesRolled.clear();
    events.clear();
    events.add(GameEvent(
      type: GameEventType.matchStarted,
      message: 'Match started with ${players.length} players.',
    ));
    events.add(GameEvent(
      type: GameEventType.turnStarted,
      playerColor: currentPlayer,
    ));
  }

  /// Rolls the dice for the current player. Returns the rolled value.
  /// Throws if called in the wrong phase.
  int rollDice() {
    if (phase != 'rolling') {
      throw StateError('Cannot roll in phase $phase');
    }
    final v = diceRoller.roll();
    diceValue = v;
    stats.recordRoll(currentPlayer, v);

    if (v == 6) {
      sixCounter++;
    } else {
      sixCounter = 0;
    }

    events.add(GameEvent(
      type: GameEventType.diceRolled,
      playerColor: currentPlayer,
      diceValue: v,
    ));

    // Three sixes -> forfeit turn.
    if (sixCounter >= 3) {
      events.add(GameEvent(
        type: GameEventType.threeSixesForfeit,
        playerColor: currentPlayer,
        message: 'Three consecutive sixes! Turn forfeited.',
      ));
      // Reset and advance turn.
      sixCounter = 0;
      diceValue = null;
      advanceTurn(extraTurn: false);
      return v;
    }

    final moves = getValidMoves(currentPlayer, v);
    if (moves.isEmpty) {
      // No valid move
      events.add(GameEvent(
        type: GameEventType.noValidMove,
        playerColor: currentPlayer,
        diceValue: v,
        message: 'No valid moves available.',
      ));
      // If rolled a 6 with no moves (e.g. all tokens at home needing exact), still extra turn by rule
      // but here we keep the same player if dice == 6; otherwise advance.
      diceValue = null;
      if (v != 6) {
        advanceTurn(extraTurn: false);
      }
      return v;
    }

    phase = 'moving';
    return v;
  }

  /// Returns the list of legal moves for the given color with the given dice
  /// (or the currently-rolled dice if `dice` is null).
  List<Move> getValidMoves(PlayerColor color, [int? dice]) {
    final d = dice ?? diceValue;
    if (d == null) return [];
    return rules.getValidMoves(players, color, d);
  }

  /// Applies the move for the current player. Returns the resulting Move.
  /// Throws if the move is illegal.
  Move moveToken(int tokenIndex) {
    if (phase != 'moving') {
      throw StateError('Cannot move in phase $phase');
    }
    final d = diceValue;
    if (d == null) throw StateError('No dice value to move with');

    final move = rules.evaluateTokenMove(players, currentPlayer, tokenIndex, d);
    if (move == null) {
      throw ArgumentError(
          'Illegal move: token #$tokenIndex for ${currentPlayer.name} with dice $d');
    }

    final player = players.firstWhere((p) => p.color == currentPlayer);
    final token = player.tokens[tokenIndex];
    final oldPos = token.position;

    // Detect capture
    PlayerColor? capturedColor;
    List<int> capturedIndices = [];
    if (move.willCapture && move.capturedColor != null) {
      capturedColor = PlayerColorX.fromName(move.capturedColor!);
      final victim = players.firstWhere((p) => p.color == capturedColor);
      capturedIndices = [];
      for (var i = 0; i < victim.tokens.length; i++) {
        if (victim.tokens[i].position == move.toPosition) {
          victim.tokens[i] = victim.tokens[i].copyWith(position: -1);
          capturedIndices.add(i);
        }
      }
      stats.recordCapture(currentPlayer);
      player.captures += 1;
      events.add(GameEvent(
        type: GameEventType.capture,
        playerColor: currentPlayer,
        tokenIndex: tokenIndex,
        toPosition: move.toPosition,
        capturedColor: capturedColor,
        capturedTokenIndices: capturedIndices,
        message:
            '${currentPlayer.name} captured ${capturedColor.name} token(s) $capturedIndices.',
      ));
    }

    // Apply move
    player.tokens[tokenIndex] = token.copyWith(position: move.toPosition);

    events.add(GameEvent(
      type: GameEventType.moveFinished,
      playerColor: currentPlayer,
      tokenIndex: tokenIndex,
      fromPosition: oldPos,
      toPosition: move.toPosition,
      diceValue: d,
    ));

    // Did the token reach home?
    if (move.toPosition == 57) {
      events.add(GameEvent(
        type: GameEventType.tokenReachedHome,
        playerColor: currentPlayer,
        tokenIndex: tokenIndex,
      ));
    }

    // Did the player win?
    if (rules.checkWin(players, currentPlayer)) {
      final rank = (stats.winner == null) ? 1 : (stats.winner == currentPlayer ? 1 : 2);
      player.finalRank = 1;
      stats.winner = currentPlayer;
      stats.finishedAt = DateTime.now();
      events.add(GameEvent(
        type: GameEventType.win,
        playerColor: currentPlayer,
        message: '${currentPlayer.name} won the match!',
      ));
      // Mark finished - if only one active color remains, end match
      final remainingActive = activeColors
          .where((c) => !players.firstWhere((p) => p.color == c).hasWon)
          .toList();
      if (remainingActive.length <= 1) {
        phase = 'finished';
        events.add(GameEvent(
          type: GameEventType.matchFinished,
          message: 'Match finished.',
        ));
        return move;
      }
      // Otherwise remove this player from active colors
      activeColors.remove(currentPlayer);
    }

    // Determine extra turn
    final extraTurn = (d == 6) || (capturedColor != null);
    if (extraTurn) {
      events.add(GameEvent(
        type: GameEventType.extraTurn,
        playerColor: currentPlayer,
        message: '${currentPlayer.name} gets an extra turn.',
      ));
    }

    // Reset dice
    diceValue = null;
    if (!extraTurn) {
      sixCounter = 0;
    } else {
      // Keep six counter if extra turn was from a 6 (already incremented).
      // Capture-based extra turns do not affect six counter.
    }

    phase = 'rolling';
    advanceTurn(extraTurn: extraTurn);
    return move;
  }

  /// Advance the turn (or keep current player on extra turn).
  void advanceTurn({required bool extraTurn}) {
    if (phase == 'finished') return;
    if (extraTurn) {
      events.add(GameEvent(
        type: GameEventType.turnStarted,
        playerColor: currentPlayer,
        message: '${currentPlayer.name} continues (extra turn).',
      ));
      return;
    }
    sixCounter = 0;
    final currentPlayerObj = players.firstWhere((p) => p.color == currentPlayer);
    if (currentPlayerObj.hasWon) {
      activeColors.remove(currentPlayer);
    }
    if (activeColors.isEmpty) {
      phase = 'finished';
      return;
    }
    currentPlayer = currentPlayer.next(activeColors);
    turnNumber++;
    stats.totalTurns = turnNumber;
    events.add(GameEvent(
      type: GameEventType.turnAdvanced,
      playerColor: currentPlayer,
    ));
  }

  /// Take a serialisable snapshot of the current state.
  GameStateSnapshot snapshot() => GameStateSnapshot(
        matchId: config.matchId,
        config: config,
        players: players.map((p) {
          // Create a deep copy
          return p.copyWith(
            tokens: p.tokens.map((t) => t.copyWith()).toList(),
          );
        }).toList(),
        currentPlayer: currentPlayer,
        diceValue: diceValue,
        phase: phase,
        turnNumber: turnNumber,
        sixCounter: sixCounter,
        stats: stats,
        activeColors: activeColors.map((c) => c.name).toList(),
        savedAt: DateTime.now(),
      );

  /// Restore engine state from a snapshot.
  void restoreFromSnapshot(GameStateSnapshot snap) {
    config = snap.config;
    players = snap.players;
    currentPlayer = snap.currentPlayer;
    diceValue = snap.diceValue;
    phase = snap.phase;
    turnNumber = snap.turnNumber;
    sixCounter = snap.sixCounter;
    // Note: stats is mutable - we replace the fields
    stats
      ..totalTurns = snap.stats.totalTurns
      ..totalCaptures = snap.stats.totalCaptures
      ..totalDiceRolls = snap.stats.totalDiceRolls
      ..winner = snap.stats.winner
      ..startedAt = snap.stats.startedAt
      ..finishedAt = snap.stats.finishedAt;
    stats.capturesPerColor
      ..clear()
      ..addAll(snap.stats.capturesPerColor);
    stats.sixesRolled
      ..clear()
      ..addAll(snap.stats.sixesRolled);
    stats.onesRolled
      ..clear()
      ..addAll(snap.stats.onesRolled);
    activeColors
      ..clear()
      ..addAll(snap.activeColors.map((n) => PlayerColorX.fromName(n)));
  }
}
