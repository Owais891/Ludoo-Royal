import '../../core/network/api_client.dart';
import '../models/wallet_transaction.dart';

class WalletService {
  final ApiClient _api;
  WalletService({ApiClient? api}) : _api = api ?? ApiClient();

  Future<Map<String, int>> balance() async {
    final res = await _api.get('/wallet');
    final d = res['data'] as Map<String, dynamic>;
    return {'coins': d['coins'] as int, 'gems': d['gems'] as int};
  }

  Future<List<WalletTransaction>> transactions({int limit = 50}) async {
    final res = await _api.get('/wallet/transactions', query: {'limit': limit});
    final list = (res['data']['transactions'] as List)
        .map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }
}
