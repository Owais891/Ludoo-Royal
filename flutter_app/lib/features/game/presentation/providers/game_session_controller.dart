import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/storage/local_database.dart';
import '../../data/models/match_config.dart';
import '../../domain/engine/dice_roller.dart';
import '../../domain/engine/game_engine.dart';
import '../../domain/engine/ludo_ai.dart';
import '../../domain/entities/game_state_snapshot.dart';
import '../../domain/entities/match_stats.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/player_color.dart';
import '../../domain/entities/token.dart';

/// A Riverpod controller that wraps the [GameEngine] and exposes reactive
/// state for the UI. Handles offline AI auto-rolling, snapshot persistence,
/// and online sync hooks (when isOnline = true).
class GameSessionController extends ChangeNotifier {
  final GameEngine engine;
  final MatchConfig config;
  final List<Player> players;
  final bool isOnline;
  final LudoAI? ai;
  final String matchId;

  // UI state
  bool _isRolling = false;
  bool _isMoving = false;
  int _displayDice = 1;
  int? _selectedTokenIndex;
  List<int> _movableTokenIndices = [];
  String? _lastMessage;
  bool _finished = false;
  PlayerColor? _winner;

  GameSessionController({
    GameEngine? engine,
    required this.config,
    required this.players,
    this.isOnline = false,
    LudoAI? ai,
  })  : engine = engine ?? GameEngine(),
        ai = ai,
        matchId = config.matchId.isEmpty
            ? const Uuid().v4()
            : config.matchId {
    if (ai != null && config.aiLevel != null) {
      // Auto-play AI turns
      _maybeStartAiTurn();
    }
  }

  // ---------- Getters ----------
  PlayerColor get currentPlayer => engine.currentPlayer;
  String get phase => engine.phase;
  int? get diceValue => engine.diceValue;
  bool get isRolling => _isRolling;
  bool get isMoving => _isMoving;
  int get displayDice => _displayDice;
  int? get selectedTokenIndex => _selectedTokenIndex;
  List<int> get movableTokenIndices => _movableTokenIndices;
  String? get lastMessage => _lastMessage;
  bool get isFinished => _finished || engine.phase == 'finished';
  PlayerColor? get winner => _winner ?? engine.stats.winner;
  MatchStats get stats => engine.stats;
  List<Player> get activePlayers => players;

  bool get canRoll =>
      !isFinished && phase == 'rolling' && !_isRolling && _currentPlayerIsHuman;

  bool get _currentPlayerIsHuman {
    final p = players.firstWhere((p) => p.color == currentPlayer,
        orElse: () => players.first);
    return !p.isAI;
  }

  // ---------- Actions ----------

  /// Roll the dice. Online mode -> server rolls, we wait for the response.
  /// Offline mode -> engine rolls locally.
  Future<int> rollDice({Future<int> Function()? serverRoll}) async {
    if (phase != 'rolling' || _isRolling) return diceValue ?? 0;
    _isRolling = true;
    notifyListeners();

    int value;
    try {
      if (isOnline && serverRoll != null) {
        value = await serverRoll();
      } else {
        // Small artificial delay for nicer animation.
        await Future.delayed(const Duration(milliseconds: 700));
        value = engine.rollDice();
      }
    } catch (_) {
      _isRolling = false;
      notifyListeners();
      rethrow;
    }

    _displayDice = value;
    // Use engine.diceValue (which is null after a forfeit or no-moves skip)
    // rather than the local `value`, so we don't show invalid moves for the
    // next player using the previous player's dice.
    final effectiveDice = engine.diceValue;
    _movableTokenIndices = effectiveDice == null
        ? <int>[]
        : engine.getValidMoves(currentPlayer, effectiveDice)
            .map((m) => m.tokenIndex)
            .toList();
    _selectedTokenIndex = null;
    _lastMessage = _movableTokenIndices.isEmpty
        ? (effectiveDice == null
            ? 'Turn skipped (no moves / 3 sixes).'
            : 'No valid moves - turn skipped.')
        : 'Choose a token to move.';

    _isRolling = false;
    notifyListeners();

    if (_movableTokenIndices.isEmpty) {
      // Skip turn automatically after a short delay.
      await Future.delayed(const Duration(milliseconds: 800));
      _maybeStartAiTurn();
    } else if (!_currentPlayerIsHuman) {
      // AI picks a token automatically.
      await Future.delayed(const Duration(milliseconds: 600));
      _aiMove(effectiveDice!);
    }
    _persist();
    return value;
  }

  /// Move the given token index. Online mode -> server validates & moves.
  Future<void> moveToken(int tokenIndex,
      {Future<void> Function(int)? serverMove}) async {
    if (phase != 'moving' || _isMoving) return;
    if (!_movableTokenIndices.contains(tokenIndex)) return;

    _isMoving = true;
    _selectedTokenIndex = tokenIndex;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 250));

    if (isOnline && serverMove != null) {
      await serverMove(tokenIndex);
    } else {
      engine.moveToken(tokenIndex);
    }

    _movableTokenIndices = [];
    _selectedTokenIndex = null;
    _isMoving = false;
    _lastMessage = '${currentPlayer.name.toUpperCase()} turn';
    if (engine.phase == 'finished') {
      _finished = true;
      _winner = engine.stats.winner;
    }
    notifyListeners();

    if (!isFinished) {
      _maybeStartAiTurn();
    }
    _persist();
  }

  void _aiMove(int dice) {
    final p = players.firstWhere((p) => p.color == currentPlayer,
        orElse: () => players.first);
    if (!p.isAI || ai == null) return;
    final idx = ai!.chooseMove(players, currentPlayer, dice);
    if (idx != null) {
      moveToken(idx);
    }
  }

  void _maybeStartAiTurn() {
    if (isFinished) return;
    final p = players.firstWhere((p) => p.color == currentPlayer,
        orElse: () => players.first);
    if (p.isAI) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!isFinished && phase == 'rolling') rollDice();
      });
    }
  }

  void setMessage(String msg) {
    _lastMessage = msg;
    notifyListeners();
  }

  void selectToken(int index) {
    _selectedTokenIndex = index;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      if (isOnline) return; // server is authoritative
      final snap = engine.snapshot();
      await LocalDatabase.saveMatchSnapshot(snap);
    } catch (e) {
      debugPrint('Persist snapshot failed: $e');
    }
  }

  Future<void> saveHistoryIfFinished() async {
    if (!isFinished) return;
    try {
      final duration = stats.startedAt != null
          ? DateTime.now().difference(stats.startedAt!).inSeconds
          : 0;
      await LocalDatabase.saveHistory(
        matchId: matchId,
        mode: config.mode.apiName,
        winner: winner?.name,
        playerCount: players.length,
        totalTurns: stats.totalTurns,
        totalCaptures: stats.totalCaptures,
        durationSec: duration,
        players: players.map((p) => p.toJson()).toList(),
      );
    } catch (e) {
      debugPrint('Save history failed: $e');
    }
  }

  // ---------- Restore from snapshot ----------
  void restoreFromSnapshot(GameStateSnapshot snap) {
    engine.restoreFromSnapshot(snap);
    // Keep the controller's own players list in sync with the engine's.
    players
      ..clear()
      ..addAll(engine.players);
    if (engine.phase == 'finished') {
      _finished = true;
      _winner = engine.stats.winner;
    }
    notifyListeners();
    _maybeStartAiTurn();
  }

  /// When the server sends a fresh state, replace local players/turn/etc.
  void applyServerState({
    required List<Player> serverPlayers,
    required PlayerColor current,
    int? serverDice,
    required String phase,
    int? sixCounter,
    List<int>? serverValidMoves,
  }) {
    // Replace players entirely (server is authoritative).
    players
      ..clear()
      ..addAll(serverPlayers);
    engine
      ..players = serverPlayers
      ..currentPlayer = current
      ..diceValue = serverDice
      ..phase = phase
      ..sixCounter = sixCounter ?? 0;
    if (phase == 'finished') {
      _finished = true;
      _winner = engine.stats.winner;
    }
    _movableTokenIndices = serverDice == null
        ? []
        : serverValidMoves ??
            engine.getValidMoves(current, serverDice)
                .map((m) => m.tokenIndex)
                .toList();
    notifyListeners();
    if (!_currentPlayerIsHuman) _maybeStartAiTurn();
  }
}

/// Provider factory - creates a controller for a given match.
/// Usage in screen: final ctrl = ref.watch(gameSessionProvider(config, players));
final gameSessionProvider = ChangeNotifierProvider.family<GameSessionController,
    ({MatchConfig config, List<Player> players, bool isOnline})>(
  (ref, args) {
    final players = args.players;
    final aiLevel = args.config.aiLevel;
    final hasAI = players.any((p) => p.isAI);
    final ai = hasAI
        ? LudoAI(level: aiLevel?.name ?? 'medium')
        : null;
    return GameSessionController(
      config: args.config,
      players: players,
      isOnline: args.isOnline,
      ai: ai,
    );
  },
);
