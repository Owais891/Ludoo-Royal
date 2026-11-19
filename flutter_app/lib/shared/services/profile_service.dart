import '../../core/network/api_client.dart';
import '../models/app_user.dart';

class ProfileService {
  final ApiClient _api;
  ProfileService({ApiClient? api}) : _api = api ?? ApiClient();

  Future<AppUser> fetchProfile() async {
    final res = await _api.get('/profile');
    return AppUser.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<AppUser> updateProfile({
    String? fullName,
    String? avatarUrl,
    String? countryCode,
    String? bio,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null)   body['full_name']    = fullName;
    if (avatarUrl != null)  body['avatar_url']   = avatarUrl;
    if (countryCode != null)body['country_code'] = countryCode;
    if (bio != null)        body['bio']          = bio;
    final res = await _api.put('/profile/update', body: body);
    return AppUser.fromJson(res['data'] as Map<String, dynamic>);
  }
}
