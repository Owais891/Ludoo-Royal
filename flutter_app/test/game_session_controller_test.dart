import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_royale/features/game/data/models/match_config.dart';
import 'package:ludo_royale/features/game/domain/engine/game_engine.dart';
import 'package:ludo_royale/features/game/domain/entities/player.dart';
import 'package:ludo_royale/features/game/domain/entities/player_color.dart';
import 'package:ludo_royale/features/game/presentation/providers/game_session_controller.dart';

void main() {
  final config = MatchConfig(
    matchId: 'online-test',
    mode: GameMode.classic,
    maxPlayers: 2,
  );
  final players = [
    Player(id: 'red', username: 'Red', color: PlayerColor.red),
  ];

  test('failed online roll unlocks the dice for retry', () async {
    final engine = GameEngine()..startMatch(config: config, players: players);
    final controller = GameSessionController(
      engine: engine,
      config: config,
      players: players,
      isOnline: true,
    );

    await expectLater(
      controller.rollDice(
        serverRoll: () async => throw Exception('network unavailable'),
      ),
      throwsA(isA<Exception>()),
    );

    expect(controller.isRolling, isFalse);
    expect(controller.canRoll, isTrue);
    controller.dispose();
  });

  test('online state uses server-provided legal moves', () {
    final engine = GameEngine()..startMatch(config: config, players: players);
    final controller = GameSessionController(
      engine: engine,
      config: config,
      players: players,
      isOnline: true,
    );

    controller.applyServerState(
      serverPlayers: players.map((player) => player.copyWith()).toList(),
      current: PlayerColor.red,
      serverDice: 6,
      phase: 'moving',
      serverValidMoves: [2],
    );

    expect(controller.phase, 'moving');
    expect(controller.movableTokenIndices, [2]);
    controller.dispose();
  });
}
