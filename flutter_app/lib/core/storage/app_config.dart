import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local persisted app configuration.
class AppConfig {
  static const _kApiBaseUrl = 'api_base_url';
  static const _kAuthToken = 'auth_token';
  static const _kUserId = 'user_id';
  static const _kUsername = 'username';
  static const _kSoundEnabled = 'sound_enabled';
  static const _kMusicEnabled = 'music_enabled';
  static const _kVibrationEnabled = 'vibration_enabled';
  static const _kDarkMode = 'dark_mode';
  static const _kLanguage = 'language';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError('AppConfig not initialised. Call AppConfig.init() first.');
    }
    return _prefs!;
  }

  static String get apiBaseUrl => prefs.getString(_kApiBaseUrl) ??
      (kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000');
  static set apiBaseUrl(String v) => prefs.setString(_kApiBaseUrl, v);

  static String? get authToken => prefs.getString(_kAuthToken);
  static set authToken(String? v) {
    if (v == null) {
      prefs.remove(_kAuthToken);
    } else {
      prefs.setString(_kAuthToken, v);
    }
  }

  static int? get userId {
    final v = prefs.getInt(_kUserId);
    return v;
  }
  static set userId(int? v) {
    if (v == null) prefs.remove(_kUserId); else prefs.setInt(_kUserId, v);
  }

  static String? get username => prefs.getString(_kUsername);
  static set username(String? v) {
    if (v == null) prefs.remove(_kUsername); else prefs.setString(_kUsername, v);
  }

  static bool get soundEnabled => prefs.getBool(_kSoundEnabled) ?? true;
  static set soundEnabled(bool v) => prefs.setBool(_kSoundEnabled, v);

  static bool get musicEnabled => prefs.getBool(_kMusicEnabled) ?? true;
  static set musicEnabled(bool v) => prefs.setBool(_kMusicEnabled, v);

  static bool get vibrationEnabled => prefs.getBool(_kVibrationEnabled) ?? true;
  static set vibrationEnabled(bool v) => prefs.setBool(_kVibrationEnabled, v);

  static bool get darkMode => prefs.getBool(_kDarkMode) ?? true;
  static set darkMode(bool v) => prefs.setBool(_kDarkMode, v);

  static String get language => prefs.getString(_kLanguage) ?? 'en';
  static set language(String v) => prefs.setString(_kLanguage, v);

  static Future<void> clearAuth() async {
    await prefs.remove(_kAuthToken);
    await prefs.remove(_kUserId);
    await prefs.remove(_kUsername);
  }

  static bool get isLoggedIn => authToken != null && authToken!.isNotEmpty;

  static void debugDump() {
    if (!kDebugMode) return;
    debugPrint('AppConfig: api=$apiBaseUrl user=$username token=${authToken?.substring(0, authToken!.length > 8 ? 8 : authToken!.length)}...');
  }
}
