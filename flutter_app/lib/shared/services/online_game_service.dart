import '../../core/network/api_client.dart';
import '../models/app_user.dart';
import '../../features/game/data/models/match_config.dart';
import '../../features/game/domain/entities/player.dart';
import '../../features/game/domain/entities/player_color.dart';

/// Online game & multiplayer API client.
class OnlineGameService {
  final ApiClient _api;
  OnlineGameService({ApiClient? api}) : _api = api ?? ApiClient();

  /// Creates a new online match (host).
  Future<Map<String, dynamic>> createMatch({
    required GameMode mode,
    required int maxPlayers,
    int entryFee = 0,
  }) async {
    final res = await _api.post('/game/create', body: {
      'mode': mode.apiName,
      'max_players': maxPlayers,
      'entry_fee': entryFee,
    });
    return res['data'] as Map<String, dynamic>;
  }

  /// Joins an existing open match.
  Future<Map<String, dynamic>> joinMatch(int matchId) async {
    final res = await _api.post('/game/join', body: {'match_id': matchId});
    return res['data'] as Map<String, dynamic>;
  }

  /// Finds an open match for the requested mode/size and joins it.
  /// Falls back to creating a new one if none available.
  Future<Map<String, dynamic>> quickMatch({
    required GameMode mode,
    required int maxPlayers,
  }) async {
    final res = await _api.post('/game/quick', body: {
      'mode': mode.apiName,
      'max_players': maxPlayers,
    });
    return res['data'] as Map<String, dynamic>;
  }

  /// Server-authoritative dice roll.
  Future<Map<String, dynamic>> rollDice(int matchId) async {
    final res = await _api.post('/game/roll-dice', body: {'match_id': matchId});
    return res['data'] as Map<String, dynamic>;
  }

  /// Submit a token move.
  Future<Map<String, dynamic>> moveToken(int matchId, int tokenIndex) async {
    final res = await _api.post('/game/move-token', body: {
      'match_id': matchId,
      'token_index': tokenIndex,
    });
    return res['data'] as Map<String, dynamic>;
  }

  /// Fetch full match state.
  Future<Map<String, dynamic>> state(int matchId) async {
    final res = await _api.get('/game/state', query: {'match_id': matchId});
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> pause(int matchId) async {
    final res = await _api.post('/game/pause', body: {'match_id': matchId});
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> resume(int matchId) async {
    final res = await _api.post('/game/resume', body: {'match_id': matchId});
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> finish(int matchId) async {
    final res = await _api.post('/game/finish', body: {'match_id': matchId});
    return res['data'] as Map<String, dynamic>;
  }

  // -------- Private rooms --------
  Future<Map<String, dynamic>> createRoom({
    required GameMode mode,
    required int maxPlayers,
  }) async {
    final res = await _api.post('/multiplayer/create-room', body: {
      'mode': mode.apiName,
      'max_players': maxPlayers,
    });
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> joinRoom(String code) async {
    final res = await _api.post('/multiplayer/join-room', body: {
      'room_code': code,
    });
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> roomStatus(String code) async {
    final res = await _api.get('/multiplayer/room-status', query: {'room_code': code});
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> leaveRoom(String code) async {
    final res = await _api.post('/multiplayer/leave-room', body: {
      'room_code': code,
    });
    return res['data'] as Map<String, dynamic>;
  }

  /// Builds a [Player] list from the API `match_players` payload.
  List<Player> playersFromMatchPayload(Map<String, dynamic> matchPayload) {
    final players = (matchPayload['players'] as List)
        .map((p) => Player.fromJson(p as Map<String, dynamic>))
        .toList();
    return players;
  }
}
