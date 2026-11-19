import '../../core/network/api_client.dart';
import '../models/daily_reward.dart';

class RewardService {
  final ApiClient _api;
  RewardService({ApiClient? api}) : _api = api ?? ApiClient();

  Future<DailyRewardStatus> status() async {
    final res = await _api.get('/rewards/daily');
    return DailyRewardStatus.fromJson(
        res['data']['status'] as Map<String, dynamic>);
  }

  Future<DailyRewardStatus> claim() async {
    final res = await _api.post('/rewards/claim');
    return DailyRewardStatus.fromJson(
        res['data'] as Map<String, dynamic>? ?? {});
  }
}
