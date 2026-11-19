import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/effects_service.dart';
import '../../../../shared/services/online_game_service.dart';
import '../../data/models/match_config.dart';
import '../../domain/engine/game_engine.dart';
import '../../domain/engine/ludo_ai.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/player_color.dart';
import '../../domain/entities/token.dart';
import '../providers/game_session_controller.dart';
import '../widgets/board_geometry.dart';
import '../widgets/ludo_board_widget.dart';
import '../widgets/ludo_dice.dart';

/// Main game screen - hosts the Ludo board, dice, players panel,
/// and orchestrates the engine via [GameSessionController].
class GameBoardScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> configArg;
  const GameBoardScreen({super.key, required this.configArg});

  @override
  ConsumerState<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends ConsumerState<GameBoardScreen> {
  late final GameSessionController _ctrl;
  late final MatchConfig _config;
  late final List<Player> _players;
  late final bool _isOnline;
  late ConfettiController _confettiCtrl;
  StreamSubscription? _pollSub;
  late final OnlineGameService _online;
  int? _serverMatchId;
  bool _onlineStateReady = false;

  @override
  void initState() {
    super.initState();
    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 3));
    _online = OnlineGameService();
    _buildConfig();
  }

  void _buildConfig() {
    final arg = widget.configArg;
    _isOnline = (arg['isOnline'] as bool?) ?? false;

    // Mode can come in as a GameMode enum (from local setup screens) or as a
    // String (from quick match / online screens).
    final modeArg = arg['mode'];
    GameMode mode;
    if (modeArg is GameMode) {
      mode = modeArg;
    } else {
      final modeName = (modeArg as String?) ?? 'classic';
      mode = modeName == 'offlineAI'
          ? GameMode.offlineAI
          : modeName == 'local'
              ? GameMode.local
              : modeName == 'quick'
                  ? GameMode.quick
                  : modeName == 'private'
                      ? GameMode.private
                      : GameMode.classic;
    }

    final maxPlayers = (arg['maxPlayers'] as int?) ?? 4;
    final aiLevelStr = (arg['aiLevel'] as String?) ?? 'medium';
    final aiLevel = AILevel.values.firstWhere(
      (e) => e.name == aiLevelStr,
      orElse: () => AILevel.medium,
    );

    _config = MatchConfig(
      matchId: (arg['matchId']?.toString()) ?? '',
      mode: mode,
      maxPlayers: maxPlayers,
      aiLevel: mode == GameMode.offlineAI ? aiLevel : null,
    );

    if (arg['players'] is List) {
      _players = (arg['players'] as List)
          .map((p) => _playerFromMap(p as Map<String, dynamic>, _config, maxPlayers))
          .toList();
    } else {
      _players = _defaultPlayers(_config);
    }

    if (_isOnline && (_config.matchId.isNotEmpty)) {
      _serverMatchId = int.tryParse(_config.matchId);
    }
    final engine = GameEngine()..startMatch(config: _config, players: _players);
    final ai = _players.any((player) => player.isAI)
        ? LudoAI(level: _config.aiLevel?.name ?? 'medium')
        : null;
    _ctrl = GameSessionController(
      engine: engine,
      config: _config,
      players: _players,
      isOnline: _isOnline,
      ai: ai,
    );
    _ctrl.addListener(_onControllerChanged);
    if (_isOnline) {
      if (_serverMatchId == null) {
        _ctrl.setMessage('Online match ID is missing.');
      } else {
        _ctrl.setMessage('Connecting to match...');
        _loadOnlineState();
      }
    }
  }

  Player _playerFromMap(Map<String, dynamic> p, MatchConfig cfg, int maxPlayers) {
    final seat = (p['seat'] as int?) ?? 0;
    final color = PlayerColorX.fromSeat(seat);
    final isAI = (p['isAI'] as bool?) ?? false;
    return Player(
      id: (p['id']?.toString()) ?? 'p_$seat',
      username: (p['username'] as String?) ?? 'Player ${seat + 1}',
      color: color,
      isAI: isAI,
      aiLevel: isAI ? (p['aiLevel'] as String?) ?? 'medium' : null,
      avatarUrl: p['avatarUrl'] as String?,
    );
  }

  List<Player> _defaultPlayers(MatchConfig cfg) {
    final count = cfg.maxPlayers;
    final useAI = cfg.mode == GameMode.offlineAI;
    final colors = [PlayerColor.red, PlayerColor.green, PlayerColor.yellow, PlayerColor.blue];
    return List.generate(count, (i) {
      final c = colors[i];
      final isAI = useAI && i > 0; // first seat is human, rest AI
      return Player(
        id: isAI ? 'ai_${c.name}' : 'local_${c.name}',
        username: isAI ? 'CPU ${i + 1}' : 'You',
        color: c,
        isAI: isAI,
        aiLevel: isAI ? (cfg.aiLevel?.name ?? 'medium') : null,
      );
    });
  }

  Future<void> _loadOnlineState() async {
    if (_serverMatchId == null) return;
    try {
      final data = await _online.state(_serverMatchId!);
      if (!mounted) return;
      _applyOnlineState(data);
      setState(() => _onlineStateReady = true);
      _startOnlinePolling();
    } catch (e) {
      if (mounted) {
        _ctrl.setMessage('Failed to load match: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load match: $e')),
        );
      }
    }
  }

  void _startOnlinePolling() {
    _pollSub?.cancel();
    _pollSub = Stream.periodic(
      const Duration(milliseconds: 1500),
      (_) => _online.state(_serverMatchId!),
    ).asyncMap((event) => event).listen((data) {
      if (!mounted) return;
      _applyOnlineState(data);
    }, onError: (Object error) {
      if (mounted) _ctrl.setMessage('Connection lost: $error');
    });
  }

  void _applyOnlineState(
    Map<String, dynamic> data, {
    List<int>? serverValidMoves,
  }) {
    final playersList = (data['players'] as List)
        .map((p) => Player.fromJson(p as Map<String, dynamic>))
        .toList();
    final state = (data['state'] as Map<String, dynamic>?) ?? {};
    final current = int.tryParse((data['current_player'] ?? 0).toString()) ?? 0;
    final rawDice = state['dice_value'];
    final dice = rawDice == null ? null : int.tryParse(rawDice.toString());
    final status = data['status']?.toString();
    final phase = status != null && status != 'active'
        ? 'waiting'
        : (state['phase'] as String?) ?? 'rolling';
    final six = int.tryParse((data['six_counter'] ?? 0).toString()) ?? 0;
    _ctrl.applyServerState(
      serverPlayers: playersList,
      current: PlayerColorX.fromSeat(current.clamp(0, 3)),
      serverDice: dice,
      phase: phase,
      sixCounter: six,
      serverValidMoves: serverValidMoves,
    );
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    if (_ctrl.isFinished) {
      _confettiCtrl.play();
      EffectsService.win();
      _ctrl.saveHistoryIfFinished();
      _pollSub?.cancel();
    }
  }

  @override
  void dispose() {
    _pollSub?.cancel();
    _ctrl.removeListener(_onControllerChanged);
    _confettiCtrl.dispose();
    super.dispose();
  }

  Future<int> _serverRollDice() async {
    final res = await _online.rollDice(_serverMatchId!);
    final v = (res['dice'] as num).toInt();
    final validMoves = (res['valid_moves'] as List)
        .map((e) => int.parse(e.toString()))
        .toList();
    final state = await _online.state(_serverMatchId!);
    if (mounted) {
      _applyOnlineState(
        state,
        serverValidMoves: res['forfeit'] == true ? null : validMoves,
      );
    }
    return v;
  }

  Future<void> _onDiceTap() async {
    EffectsService.diceRollTick();
    try {
      await _ctrl.rollDice(
        serverRoll: _isOnline ? _serverRollDice : null,
      );
    } on ApiException catch (error) {
      _showRollError(error.message);
    } on Exception catch (error) {
      _showRollError('Dice roll failed: $error');
    }
  }

  void _showRollError(String message) {
    if (!mounted) return;
    _ctrl.setMessage(message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _serverMove(int tokenIndex) async {
    await _online.moveToken(_serverMatchId!, tokenIndex);
    final state = await _online.state(_serverMatchId!);
    final playersList = (state['players'] as List)
        .map((p) => Player.fromJson(p as Map<String, dynamic>))
        .toList();
    final cur = int.tryParse((state['current_player'] ?? 0).toString()) ?? 0;
    final state2 = (state['state'] as Map<String, dynamic>?) ?? {};
    _ctrl.applyServerState(
      serverPlayers: playersList,
      current: PlayerColorX.fromSeat(cur.clamp(0, 3)),
      serverDice: null,
      phase: (state2['phase'] as String?) ?? 'rolling',
      sixCounter: (state['six_counter'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ludo Royale'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => _confirmExit(context),
          ),
        ],
      ),
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            if (orientation == Orientation.portrait) {
              return Column(
                children: [
                  _playersPanel(),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: _boardArea(),
                      ),
                    ),
                  ),
                  _bottomControls(),
                ],
              );
            }
            // Landscape: side-by-side
            return Row(
              children: [
                Expanded(flex: 3, child: _boardArea()),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _playersPanel(),
                      const Spacer(),
                      _bottomControls(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _playersPanel() {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient(),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _ctrl.players.map((p) {
          final isCurrent = p.color == _ctrl.currentPlayer;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isCurrent
                  ? AppTheme.playerColor(p.color.name).withAlpha(60)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isCurrent
                  ? Border.all(
                      color: AppTheme.playerColor(p.color.name),
                      width: 2)
                  : null,
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.playerColor(p.color.name),
                  child: p.isAI
                      ? const Icon(Icons.smart_toy,
                          color: Colors.white, size: 16)
                      : const Icon(Icons.person,
                          color: Colors.white, size: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  p.username,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  '${p.tokensHome}/4',
                  style: TextStyle(
                    color: Colors.white.withAlpha(180),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _boardArea() {
    return Stack(
      alignment: Alignment.center,
      children: [
        LudoBoardWidget(
          players: _ctrl.players,
          currentPlayer: _ctrl.currentPlayer,
          movableTokenIndices: _ctrl.movableTokenIndices.toSet(),
          selectedTokenIndex: _ctrl.selectedTokenIndex,
          onTokenTap: (idx) {
            EffectsService.tokenMove();
            _ctrl.moveToken(idx,
                serverMove: _isOnline ? _serverMove : null);
          },
        ),
        if (_ctrl.isFinished)
          ConfettiWidget(
            confettiController: _confettiCtrl,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 30,
            maxBlastForce: 20,
            minBlastForce: 8,
            gravity: 0.3,
            colors: const [
              Color(0xFFFFC107),
              Color(0xFFE53935),
              Color(0xFF43A047),
              Color(0xFF1E88E5),
            ],
          ),
        if (_ctrl.isFinished) _winnerOverlay(),
      ],
    );
  }

  Widget _winnerOverlay() {
    final winner = _ctrl.winner;
    if (winner == null) return const SizedBox.shrink();
    return Positioned(
      top: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(180),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.playerColor(winner.name), width: 3),
        ),
        child: Column(
          children: [
            const Icon(Icons.emoji_events,
                color: Color(0xFFFFC107), size: 40),
            const SizedBox(height: 4),
            Text(
              '${winner.name.toUpperCase()} WINS!',
              style: TextStyle(
                color: AppTheme.playerColor(winner.name),
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                _ctrl.saveHistoryIfFinished();
                context.go('/game/result', extra: {
                  'winner': winner.name,
                  'stats': _ctrl.stats.toJson(),
                  'matchId': _config.matchId,
                });
              },
              child: const Text('View Results'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomControls() {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient(),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LudoDice(
                value: _ctrl.displayDice,
                isRolling: _ctrl.isRolling,
                color: AppTheme.playerColor(_ctrl.currentPlayer.name),
                onTap: _ctrl.canRoll &&
                        (!_isOnline || _onlineStateReady)
                    ? _onDiceTap
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _ctrl.isFinished
                          ? 'Match Finished'
                          : _isOnline && !_onlineStateReady
                              ? 'Connecting to match...'
                              : _isOnline && _ctrl.phase == 'waiting'
                                  ? 'Waiting for players'
                          : '${_ctrl.currentPlayer.name.toUpperCase()}\'s turn',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_ctrl.lastMessage != null)
                      Text(
                        _ctrl.lastMessage!,
                        style: TextStyle(
                          color: Colors.white.withAlpha(180),
                          fontSize: 13,
                        ),
                      ),
                    Text(
                      'Turn ${_ctrl.stats.totalTurns} • Sixes: ${_ctrl.engine.sixCounter}/3',
                      style: TextStyle(
                        color: Colors.white.withAlpha(140),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Leave Match?'),
        content: const Text(
            'Your progress will be saved locally. You can resume from history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      _ctrl.saveHistoryIfFinished();
      context.go('/home');
    }
  }
}
