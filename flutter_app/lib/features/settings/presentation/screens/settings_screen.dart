import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/auth_service.dart';

final _authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Settings screen — toggles, language picker, API URL, logout, about.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late bool _sound;
  late bool _music;
  late bool _vibration;
  late bool _darkMode;
  late String _language;
  late TextEditingController _apiController;
  bool _loggingOut = false;
  bool _savingApi = false;
  bool _showApiSaved = false;

  static const _languages = <String, String>{
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'ar': 'Arabic',
    'ur': 'Urdu',
  };

  @override
  void initState() {
    super.initState();
    _sound = AppConfig.soundEnabled;
    _music = AppConfig.musicEnabled;
    _vibration = AppConfig.vibrationEnabled;
    _darkMode = AppConfig.darkMode;
    _language = AppConfig.language;
    _apiController = TextEditingController(text: AppConfig.apiBaseUrl);
  }

  @override
  void dispose() {
    _apiController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text('Log Out?'),
        content: const Text('You will be returned to the login screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _loggingOut = true);
    try {
      await ref.read(_authServiceProvider).logout();
    } finally {
      if (!mounted) return;
      setState(() => _loggingOut = false);
      context.go('/login');
    }
  }

  Future<void> _saveApi() async {
    setState(() {
      _savingApi = true;
      _showApiSaved = false;
    });
    final v = _apiController.text.trim();
    if (v.isNotEmpty) {
      AppConfig.apiBaseUrl = v;
    }
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    setState(() {
      _savingApi = false;
      _showApiSaved = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showApiSaved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _SectionHeader(label: 'Preferences'),
          const SizedBox(height: 8),
          _Card(
            children: [
              _ToggleRow(
                icon: Icons.volume_up,
                label: 'Sound Effects',
                subtitle: 'Dice, taps, captures',
                value: _sound,
                onChanged: (v) => setState(() {
                  _sound = v;
                  AppConfig.soundEnabled = v;
                }),
              ),
              const _Divider(),
              _ToggleRow(
                icon: Icons.music_note,
                label: 'Background Music',
                subtitle: 'Royale theme loop',
                value: _music,
                onChanged: (v) => setState(() {
                  _music = v;
                  AppConfig.musicEnabled = v;
                }),
              ),
              const _Divider(),
              _ToggleRow(
                icon: Icons.vibration,
                label: 'Vibration',
                subtitle: 'Haptic feedback on dice rolls',
                value: _vibration,
                onChanged: (v) => setState(() {
                  _vibration = v;
                  AppConfig.vibrationEnabled = v;
                }),
              ),
              const _Divider(),
              _ToggleRow(
                icon: Icons.dark_mode,
                label: 'Dark Mode',
                subtitle: 'Always-on royal dark theme',
                value: _darkMode,
                onChanged: (v) => setState(() {
                  _darkMode = v;
                  AppConfig.darkMode = v;
                }),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SectionHeader(label: 'Language'),
          const SizedBox(height: 8),
          _Card(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.language,
                        color: AppTheme.textSecondary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _language,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        dropdownColor: AppTheme.cardBackground,
                        items: _languages.entries
                            .map((e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _language = v);
                          AppConfig.language = v;
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SectionHeader(label: 'Developer'),
          const SizedBox(height: 8),
          _Card(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Row(
                  children: [
                    const Icon(Icons.dns_outlined,
                        color: AppTheme.textSecondary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'API Base URL',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _apiController,
                            keyboardType: TextInputType.url,
                            style: const TextStyle(
                                color: AppTheme.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'http://10.0.2.2:8000',
                              isDense: true,
                              suffixIcon: _savingApi
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: Padding(
                                        padding: EdgeInsets.all(8),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.accent,
                                        ),
                                      ),
                                    )
                                  : _showApiSaved
                                      ? const Icon(Icons.check,
                                          color: AppTheme.success, size: 18)
                                      : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _savingApi ? null : _saveApi,
                      icon: const Icon(Icons.save, size: 16),
                      label: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SectionHeader(label: 'Account'),
          const SizedBox(height: 8),
          _Card(
            children: [
              ListTile(
                leading: const Icon(Icons.logout, color: AppTheme.danger),
                title: const Text(
                  'Log Out',
                  style: TextStyle(color: AppTheme.danger),
                ),
                subtitle: const Text('Return to the login screen'),
                trailing: _loggingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.danger,
                        ),
                      )
                    : const Icon(Icons.chevron_right,
                        color: AppTheme.danger),
                onTap: _loggingOut ? null : _logout,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _AboutCard(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(children: children),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.accent,
      activeTrackColor: AppTheme.accent.withOpacity(0.35),
      inactiveThumbColor: AppTheme.textSecondary,
      inactiveTrackColor: Colors.white.withOpacity(0.10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.accent.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.accent, size: 18),
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Divider(color: Colors.white12, height: 1),
    );
  }
}

class _AboutCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppTheme.goldGradient(),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.casino, color: Colors.black, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppConstants.appName,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Version ${AppConstants.appVersion} • ${AppConstants.appTagline}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
