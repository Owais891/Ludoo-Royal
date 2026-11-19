import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/storage/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/services/profile_service.dart';

final profileServiceProvider = Provider<ProfileService>((ref) => ProfileService());

/// Home dashboard - profile header, 5 game-mode cards (responsive grid),
/// and a horizontally scrolling section of shortcuts.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  AppUser? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(profileServiceProvider);
      final u = await svc.fetchProfile();
      if (!mounted) return;
      setState(() {
        _user = u;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user ??
        AppUser(
          id: AppConfig.userId ?? 0,
          fullName: AppConfig.username ?? 'Guest',
          username: AppConfig.username ?? 'guest',
          email: '',
        );
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF4A148C).withOpacity(0.85),
              const Color(0xFF0A0E27),
            ],
            stops: const [0.0, 0.55],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            color: AppTheme.accent,
            backgroundColor: AppTheme.cardBackground,
            onRefresh: _loadProfile,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _AppBar(),
                const SizedBox(height: 12),
                _ProfileHeaderCard(
                  user: user,
                  loading: _loading,
                  isGuest: _error != null && _user == null,
                ),
                const SizedBox(height: 18),
                Text(
                  'Play Now',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _GameModeGrid(),
                const SizedBox(height: 22),
                Text(
                  'Quick Access',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const _QuickAccessRow(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- AppBar -------------------------------------------------------

class _AppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppTheme.goldGradient(),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFC107).withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.casino, color: Colors.black, size: 22),
              ),
              const SizedBox(width: 10),
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppTheme.goldGradient().createShader(bounds),
                child: const Text(
                  'Ludo Royale',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded,
              color: AppTheme.textPrimary),
          onPressed: () => context.go('/rewards'),
          tooltip: 'Notifications',
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined,
              color: AppTheme.textPrimary),
          onPressed: () => context.go('/settings'),
          tooltip: 'Settings',
        ),
      ],
    );
  }
}

// ---------- Profile header card -----------------------------------------

class _ProfileHeaderCard extends StatelessWidget {
  final AppUser user;
  final bool loading;
  final bool isGuest;

  const _ProfileHeaderCard({
    required this.user,
    required this.loading,
    required this.isGuest,
  });

  int get _xpForCurrent => user.playerLevel * 1000;
  int get _xpForNext => (user.playerLevel + 1) * 1000;
  double get _xpProgress {
    final span = _xpForNext - _xpForCurrent;
    if (span == 0) return 1;
    return ((user.experience - _xpForCurrent) / span).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient(),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient(),
                      border: Border.all(
                          color: AppTheme.accent.withOpacity(0.8), width: 2),
                    ),
                    child: ClipOval(
                      child: (user.avatarUrl ?? '').isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: user.avatarUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  const Icon(Icons.person, size: 32),
                              errorWidget: (_, __, ___) =>
                                  const Icon(Icons.person, size: 32),
                            )
                          : const Icon(Icons.person,
                              size: 32, color: Colors.white),
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: AppTheme.goldGradient(),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppTheme.cardBackground, width: 2),
                      ),
                      child: Text(
                        'Lv ${user.playerLevel}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (loading)
                      Container(
                        height: 18,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      )
                    else
                      Text(
                        isGuest
                            ? 'Welcome, Guest'
                            : (user.fullName.isNotEmpty
                                ? user.fullName
                                : user.username),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    if (loading)
                      Container(
                        height: 10,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      )
                    else
                      Text(
                        '@${user.username}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                children: [
                  _CoinChip(
                    icon: Icons.monetization_on_rounded,
                    value: user.coins,
                    color: AppTheme.accent,
                  ),
                  const SizedBox(height: 6),
                  _CoinChip(
                    icon: Icons.diamond,
                    value: user.gems,
                    color: Colors.cyanAccent,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                'XP',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      Container(
                        height: 10,
                        color: Colors.white.withOpacity(0.08),
                      ),
                      FractionallySizedBox(
                        widthFactor: loading ? 0 : _xpProgress,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            gradient: AppTheme.goldGradient(),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${user.experience}/${_xpForNext} XP',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoinChip extends StatelessWidget {
  final IconData icon;
  final int value;
  final Color color;

  const _CoinChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Game mode grid ----------------------------------------------

class _GameModeGrid extends StatelessWidget {
  static const _modes = <_GameMode>[
    _GameMode(
      title: 'Play Online',
      subtitle: 'Match with real players',
      icon: Icons.public,
      gradient: [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
      route: '/game/quick-match',
    ),
    _GameMode(
      title: 'Play with Friends',
      subtitle: 'Create a private room',
      icon: Icons.group,
      gradient: [Color(0xFF1565C0), Color(0xFF42A5F5)],
      route: '/rooms/create',
    ),
    _GameMode(
      title: 'Play with Computer',
      subtitle: 'Challenge the AI',
      icon: Icons.smart_toy_outlined,
      gradient: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
      route: '/game/offline-setup?mode=offlineAI',
    ),
    _GameMode(
      title: 'Local Multiplayer',
      subtitle: 'Pass-and-play',
      icon: Icons.people_alt_outlined,
      gradient: [Color(0xFFEF6C00), Color(0xFFFFB74D)],
      route: '/game/offline-setup?mode=local',
    ),
    _GameMode(
      title: 'Quick Match',
      subtitle: 'Browse all modes',
      icon: Icons.bolt,
      gradient: [Color(0xFFC62828), Color(0xFFEF5350)],
      route: '/game/modes',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxis;
        double aspect;
        if (constraints.maxWidth >= 1200) {
          crossAxis = 4;
          aspect = 1.05;
        } else if (constraints.maxWidth >= 720) {
          crossAxis = 3;
          aspect = 1.05;
        } else {
          crossAxis = 2;
          aspect = 1.05;
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _modes.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxis,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: aspect,
          ),
          itemBuilder: (context, i) => _GameModeCard(mode: _modes[i]),
        );
      },
    );
  }
}

class _GameMode {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final String route;

  const _GameMode({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.route,
  });
}

class _GameModeCard extends StatelessWidget {
  final _GameMode mode;

  const _GameModeCard({required this.mode});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.go(mode.route),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: mode.gradient,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: mode.gradient.last.withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(mode.icon, color: Colors.white, size: 22),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mode.subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Quick access row ---------------------------------------------

class _QuickAccessRow extends StatelessWidget {
  const _QuickAccessRow();

  static const _items = <_QuickAccess>[
    _QuickAccess(
      label: 'Daily Rewards',
      icon: Icons.card_giftcard,
      route: '/rewards',
      color: Color(0xFFFFC107),
    ),
    _QuickAccess(
      label: 'Leaderboard',
      icon: Icons.emoji_events,
      route: '/leaderboard',
      color: Color(0xFFFF6F00),
    ),
    _QuickAccess(
      label: 'Game History',
      icon: Icons.history,
      route: '/history',
      color: Color(0xFF42A5F5),
    ),
    _QuickAccess(
      label: 'Wallet',
      icon: Icons.account_balance_wallet,
      route: '/wallet',
      color: Color(0xFF66BB6A),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final it = _items[i];
          return _QuickAccessTile(item: it);
        },
      ),
    );
  }
}

class _QuickAccess {
  final String label;
  final IconData icon;
  final String route;
  final Color color;

  const _QuickAccess({
    required this.label,
    required this.icon,
    required this.route,
    required this.color,
  });
}

class _QuickAccessTile extends StatelessWidget {
  final _QuickAccess item;

  const _QuickAccessTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go(item.route),
        child: Ink(
          width: 110,
          decoration: BoxDecoration(
            gradient: AppTheme.cardGradient(),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: item.color.withOpacity(0.25)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                item.label,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
