import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/leaderboard_entry.dart';
import '../../../../shared/services/leaderboard_service.dart';

final _leaderboardServiceProvider =
    Provider<LeaderboardService>((ref) => LeaderboardService());

/// Leaderboard screen — top-3 podium followed by a ranked list.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  List<LeaderboardEntry> _entries = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref.read(_leaderboardServiceProvider).top();
      if (!mounted) return;
      setState(() {
        _entries = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: RefreshIndicator(
        color: AppTheme.accent,
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildSkeleton();
    if (_error != null) {
      return _StateMessage(
        icon: Icons.cloud_off,
        title: 'Failed to load',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    if (_entries.isEmpty) {
      return _StateMessage(
        icon: Icons.emoji_events_outlined,
        title: 'No rankings yet',
        message: 'Play a few matches to populate the leaderboard.',
      );
    }
    final podium = _entries.take(3).toList();
    final rest = _entries.skip(3).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _Podium(entries: podium),
        const SizedBox(height: 18),
        const _SectionHeader(label: 'All Players'),
        const SizedBox(height: 8),
        ...rest.asMap().entries.map((entry) {
          final rank = entry.key + 4;
          return _RankTile(entry: entry.value, rank: rank);
        }),
      ],
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _SkeletonPodium(height: 110),
            _SkeletonPodium(height: 150),
            _SkeletonPodium(height: 95),
          ],
        ),
        const SizedBox(height: 18),
        ...List.generate(
          8,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SkeletonPodium extends StatelessWidget {
  final double height;
  const _SkeletonPodium({required this.height});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 60,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  const _Podium({required this.entries});

  @override
  Widget build(BuildContext context) {
    // Re-arrange so 2nd, 1st, 3rd are visually side-by-side.
    final e1 = entries.length >= 1 ? entries[0] : null;
    final e2 = entries.length >= 2 ? entries[1] : null;
    final e3 = entries.length >= 3 ? entries[2] : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient(),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _PodiumSlot(entry: e2, rank: 2, height: 110)),
          Expanded(
            child: _PodiumSlot(
                entry: e1, rank: 1, height: 150, isKing: true),
          ),
          Expanded(child: _PodiumSlot(entry: e3, rank: 3, height: 95)),
        ],
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  final LeaderboardEntry? entry;
  final int rank;
  final double height;
  final bool isKing;

  const _PodiumSlot({
    required this.entry,
    required this.rank,
    required this.height,
    this.isKing = false,
  });

  Color get _accent {
    switch (rank) {
      case 1:
        return const Color(0xFFFFC107);
      case 2:
        return const Color(0xFFB0BEC5);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = entry?.username ?? '—';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isKing)
          const Icon(Icons.emoji_events, color: Color(0xFFFFC107), size: 22),
        const SizedBox(height: 2),
        _Avatar(
          url: entry?.avatarUrl,
          size: isKing ? 64 : 52,
          ring: _accent,
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: isKing ? 13 : 12,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_accent.withOpacity(0.85), _accent.withOpacity(0.20)],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '#$rank',
            style: TextStyle(
              color: Colors.black.withOpacity(0.8),
              fontSize: isKing ? 22 : 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final double size;
  final Color ring;

  const _Avatar({required this.url, required this.size, required this.ring});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.primaryGradient(),
        border: Border.all(color: ring, width: 3),
      ),
      child: ClipOval(
        child: (url ?? '').isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Icon(Icons.person, size: size * 0.45),
                errorWidget: (_, __, ___) =>
                    Icon(Icons.person, size: size * 0.45),
              )
            : Icon(Icons.person, size: size * 0.45, color: Colors.white),
      ),
    );
  }
}

class _RankTile extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;

  const _RankTile({required this.entry, required this.rank});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient(),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '#$rank',
              style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          _Avatar(url: entry.avatarUrl, size: 40, ring: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.username,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _MiniStat(
                        icon: Icons.emoji_events,
                        value: '${entry.totalWins} W'),
                    const SizedBox(width: 8),
                    _MiniStat(
                        icon: Icons.sports_esports,
                        value: '${entry.totalMatches} M'),
                    const SizedBox(width: 8),
                    _MiniStat(
                        icon: Icons.gps_fixed,
                        value: '${entry.totalCaptures} C'),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: AppTheme.goldGradient(),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Lv ${entry.playerLevel}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${entry.winRate.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: AppTheme.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  const _MiniStat({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppTheme.textSecondary),
        const SizedBox(width: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Icon(icon, size: 56, color: AppTheme.textSecondary),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 18),
          Center(
            child: OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(actionLabel!),
            ),
          ),
        ],
      ],
    );
  }
}
