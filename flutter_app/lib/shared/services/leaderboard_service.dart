import '../../core/network/api_client.dart';
import '../models/leaderboard_entry.dart';

class LeaderboardService {
  final ApiClient _api;
  LeaderboardService({ApiClient? api}) : _api = api ?? ApiClient();

  Future<List<LeaderboardEntry>> top({int limit = 100}) async {
    final res = await _api.get('/leaderboard', query: {'limit': limit});
    final list = (res['data']['players'] as List)
        .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }
}
