import '../../core/network/api_client.dart';
import '../models/match_history_entry.dart';

class HistoryService {
  final ApiClient _api;
  HistoryService({ApiClient? api}) : _api = api ?? ApiClient();

  Future<List<MatchHistoryEntry>> load({int limit = 50}) async {
    final res = await _api.get('/history', query: {'limit': limit});
    final list = (res['data']['history'] as List)
        .map((e) => MatchHistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }
}
