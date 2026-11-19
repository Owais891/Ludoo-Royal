import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/daily_reward.dart';
import '../../../../shared/services/reward_service.dart';

final _rewardServiceProvider =
    Provider<RewardService>((ref) => RewardService());

/// Daily Rewards screen — a 7-day ladder with a "Claim" CTA for the
/// current day.
class DailyRewardsScreen extends ConsumerStatefulWidget {
  const DailyRewardsScreen({super.key});

  @override
  ConsumerState<DailyRewardsScreen> createState() => _DailyRewardsScreenState();
}

class _DailyRewardsScreenState extends ConsumerState<DailyRewardsScreen> {
  DailyRewardStatus? _status;
  bool _loading = true;
  bool _claiming = false;
  String? _error;
  late ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _load();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await ref.read(_rewardServiceProvider).status();
      if (!mounted) return;
      setState(() {
        _status = s;
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

  Future<void> _claim() async {
    if (_claiming) return;
    setState(() => _claiming = true);
    try {
      final s = await ref.read(_rewardServiceProvider).claim();
      if (!mounted) return;
      _confetti.play();
      setState(() => _status = s);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(_claimMessage(s)),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(12),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Claim failed: ${_humanError(e)}'),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(12),
          ),
        );
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  String _claimMessage(DailyRewardStatus s) {
    final r = s.nextReward;
    if (r == null) return 'Reward claimed!';
    return '+${r.amount} ${r.rewardType == 'gem' ? 'gems' : 'coins'} added to your wallet!';
  }

  String _humanError(Object e) {
    final msg = e.toString();
    final m = RegExp(r"ApiException\(\d+\):\s*(.*)").firstMatch(msg);
    return m != null ? m.group(1)! : msg;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Rewards')),
      body: Stack(
        children: [
          _buildBody(),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 18,
              maxBlastForce: 14,
              minBlastForce: 6,
              gravity: 0.18,
              colors: const [
                Color(0xFFFFC107),
                Color(0xFFFF6F00),
                Color(0xFF1565C0),
                Color(0xFF4A148C),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildSkeleton();
    if (_error != null) {
      return _StateMessage(
        icon: Icons.cloud_off,
        title: 'Failed to load rewards',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    final status = _status;
    if (status == null) {
      return const _StateMessage(
        icon: Icons.card_giftcard,
        title: 'Nothing to claim',
        message: 'Check back tomorrow.',
      );
    }
    return RefreshIndicator(
      color: AppTheme.accent,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _StreakBanner(status: status),
          const SizedBox(height: 18),
          const _SectionHeader(label: '7-Day Reward Ladder'),
          const SizedBox(height: 10),
          _Ladder(status: status),
          const SizedBox(height: 20),
          _ClaimButton(
            status: status,
            claiming: _claiming,
            onClaim: _claim,
          ),
          const SizedBox(height: 12),
          const _FootNote(),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 7,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemBuilder: (_, __) => Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
            ),
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

class _StreakBanner extends StatelessWidget {
  final DailyRewardStatus status;
  const _StreakBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.goldGradient(),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFC107).withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department,
              size: 40, color: Colors.black),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Streak',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${status.currentStreak} day${status.currentStreak == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: status.canClaim
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.card_giftcard, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Ready',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'Claimed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Ladder extends StatelessWidget {
  final DailyRewardStatus status;
  const _Ladder({required this.status});

  /// Synthesize the 7-day ladder: the "nextReward" represents what
  /// the player will receive next. We build the surrounding days from
  /// the streak + nextReward using the common Ludo Royale reward curve.
  List<DailyReward> get _ladder {
    final next = status.nextReward;
    final List<DailyReward> list = [];
    for (var day = 1; day <= 7; day++) {
      final rewardType = (day % 7 == 0)
          ? 'gem'
          : (day == (status.currentStreak + 1) && next != null
              ? next.rewardType
              : 'coin');
      final isToday = day == (status.currentStreak + 1) && !status.claimedToday;
      final amount = _amountForDay(day, next: next, isToday: isToday);
      list.add(DailyReward(
        day: day,
        rewardType: rewardType,
        amount: amount,
        isActive: isToday,
      ));
    }
    return list;
  }

  int _amountForDay(int day, {DailyReward? next, required bool isToday}) {
    if (isToday && next != null) return next.amount;
    // Default Ludo Royale reward curve.
    const curve = [100, 150, 200, 250, 300, 400, 5];
    if (day >= 1 && day <= 7) return curve[day - 1];
    return 100;
  }

  @override
  Widget build(BuildContext context) {
    final ladder = _ladder;
    final todayIndex = status.claimedToday
        ? status.currentStreak
        : status.currentStreak + 1;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: ladder.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, i) {
        final r = ladder[i];
        final day = i + 1;
        final isToday = day == todayIndex;
        final isClaimed = status.claimedToday
            ? day <= status.currentStreak
            : day < todayIndex;
        return _LadderTile(
          reward: r,
          isToday: isToday,
          isClaimed: isClaimed,
        );
      },
    );
  }
}

class _LadderTile extends StatelessWidget {
  final DailyReward reward;
  final bool isToday;
  final bool isClaimed;

  const _LadderTile({
    required this.reward,
    required this.isToday,
    required this.isClaimed,
  });

  @override
  Widget build(BuildContext context) {
    final isGem = reward.rewardType == 'gem';
    final accent = isGem ? Colors.cyanAccent : AppTheme.accent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: isToday
            ? AppTheme.goldGradient()
            : AppTheme.cardGradient(),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isToday ? Colors.transparent : accent.withOpacity(0.35),
          width: 1.2,
        ),
        boxShadow: isToday
            ? [
                BoxShadow(
                  color: const Color(0xFFFFC107).withOpacity(0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Day ${reward.day}',
            style: TextStyle(
              color: isToday ? Colors.black : AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isToday
                  ? Colors.black.withOpacity(0.18)
                  : accent.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGem ? Icons.diamond : Icons.monetization_on,
              color: isToday ? Colors.white : accent,
              size: 18,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isClaimed)
                Icon(Icons.check_circle, color: AppTheme.success, size: 14)
              else
                Text(
                  '+${reward.amount}',
                  style: TextStyle(
                    color: isToday ? Colors.black : AppTheme.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClaimButton extends StatelessWidget {
  final DailyRewardStatus status;
  final bool claiming;
  final VoidCallback onClaim;

  const _ClaimButton({
    required this.status,
    required this.claiming,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final canClaim = status.canClaim && !status.claimedToday;
    final reward = status.nextReward;
    final label = canClaim
        ? (reward != null
            ? 'Claim +${reward.amount} ${reward.rewardType == 'gem' ? 'gems' : 'coins'}'
            : 'Claim Today\'s Reward')
        : 'Already Claimed';
    return SizedBox(
      height: 54,
      child: Opacity(
        opacity: canClaim ? 1.0 : 0.65,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: canClaim && !claiming ? onClaim : null,
            child: Ink(
              decoration: BoxDecoration(
                gradient: canClaim
                    ? AppTheme.goldGradient()
                    : LinearGradient(
                        colors: [
                          AppTheme.cardAlt,
                          AppTheme.cardBackground,
                        ],
                      ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                alignment: Alignment.center,
                child: claiming
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.black,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            canClaim ? Icons.redeem : Icons.check_circle,
                            color: canClaim ? Colors.black : AppTheme.success,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            label,
                            style: TextStyle(
                              color: canClaim
                                  ? Colors.black
                                  : AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FootNote extends StatelessWidget {
  const _FootNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.textSecondary, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Keep playing every day to extend your streak! Day 7 always grants a special gem bonus.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
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
