import '../../core/network/api_client.dart';
import '../../core/storage/app_config.dart';
import '../models/app_user.dart';

/// Authentication service - talks to PHP backend.
class AuthService {
  final ApiClient _api;
  AuthService({ApiClient? api}) : _api = api ?? ApiClient();

  Future<AppUser> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final res = await _api.post('/auth/register', body: {
      'full_name': fullName,
      'username': username,
      'email': email,
      'password': password,
      'confirm_password': confirmPassword,
    });
    final data = res['data'] as Map<String, dynamic>;
    AppConfig.authToken = data['token'] as String?;
    final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    AppConfig.userId = user.id;
    AppConfig.username = user.username;
    return user;
  }

  Future<AppUser> login({
    required String login,
    required String password,
  }) async {
    final res = await _api.post('/auth/login', body: {
      'login': login,
      'password': password,
    });
    final data = res['data'] as Map<String, dynamic>;
    AppConfig.authToken = data['token'] as String?;
    final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    AppConfig.userId = user.id;
    AppConfig.username = user.username;
    return user;
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {
      // even if API fails, clear locally
    }
    await AppConfig.clearAuth();
  }

  Future<void> forgotPassword(String email) async {
    await _api.post('/auth/forgot-password', body: {'email': email});
  }

  Future<void> resetPassword(String token, String newPassword) async {
    await _api.post('/auth/reset-password', body: {
      'token': token,
      'password': newPassword,
    });
  }
}
