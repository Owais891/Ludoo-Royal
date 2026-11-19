/// Daily reward ladder entry.
class DailyReward {
  final int day;
  final String rewardType; // 'coin' | 'gem'
  final int amount;
  final bool isActive;

  const DailyReward({
    required this.day,
    required this.rewardType,
    required this.amount,
    this.isActive = true,
  });

  factory DailyReward.fromJson(Map<String, dynamic> j) => DailyReward(
    day: (j['day'] as num).toInt(),
    rewardType: j['reward_type'] as String? ?? 'coin',
    amount: (j['amount'] as num).toInt(),
    isActive: (j['is_active'] as num?)?.toInt() == 1,
  );
}

class DailyRewardStatus {
  final bool claimedToday;
  final int currentStreak;
  final int nextStreak;
  final DailyReward? nextReward;
  final bool canClaim;

  const DailyRewardStatus({
    required this.claimedToday,
    required this.currentStreak,
    required this.nextStreak,
    required this.nextReward,
    required this.canClaim,
  });

  factory DailyRewardStatus.fromJson(Map<String, dynamic> j) => DailyRewardStatus(
    claimedToday: j['claimed_today'] as bool? ?? false,
    currentStreak: (j['current_streak'] as num?)?.toInt() ?? 0,
    nextStreak: (j['next_streak'] as num?)?.toInt() ?? 1,
    nextReward: j['next_reward'] != null
        ? DailyReward.fromJson(j['next_reward'] as Map<String, dynamic>)
        : null,
    canClaim: j['can_claim'] as bool? ?? false,
  );
}
