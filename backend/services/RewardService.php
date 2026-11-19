<?php
/**
 * RewardService - daily reward ladder (7-day cycle).
 */
final class RewardService
{
    public static function status(int $userId): array
    {
        $pdo = Database::connection();
        $today = date('Y-m-d');
        $yesterday = date('Y-m-d', strtotime('-1 day'));

        $stmt = $pdo->prepare(
            'SELECT * FROM reward_claims WHERE user_id = :u ORDER BY claim_date DESC LIMIT 2'
        );
        $stmt->execute([':u' => $userId]);
        $rows = $stmt->fetchAll();

        $claimedToday = false;
        $streak = 0;
        $nextStreak = 1;

        if (!empty($rows)) {
            $latest = $rows[0];
            if ($latest['claim_date'] === $today) {
                $claimedToday = true;
                $streak = (int)$latest['streak_day'];
                $nextStreak = ($streak % 7) + 1;
            } elseif ($latest['claim_date'] === $yesterday) {
                $streak = (int)$latest['streak_day'];
                $nextStreak = ($streak % 7) + 1;
            } else {
                $streak = 0;
                $nextStreak = 1;
            }
        }

        // Load the upcoming reward record
        $stmt = $pdo->prepare('SELECT * FROM daily_rewards WHERE day = :d AND is_active = 1');
        $stmt->execute([':d' => $nextStreak]);
        $reward = $stmt->fetch();

        return [
            'claimed_today' => $claimedToday,
            'current_streak'=> $streak,
            'next_streak'   => $nextStreak,
            'next_reward'   => $reward ?: null,
            'can_claim'     => !$claimedToday,
        ];
    }

    public static function claim(int $userId): array
    {
        $status = self::status($userId);
        if ($status['claimed_today']) {
            error('Reward already claimed today.', 409);
        }
        $pdo = Database::connection();
        $today = date('Y-m-d');

        $streakDay = $status['next_streak'];
        $stmt = $pdo->prepare('SELECT * FROM daily_rewards WHERE day = :d AND is_active = 1');
        $stmt->execute([':d' => $streakDay]);
        $reward = $stmt->fetch();
        if (!$reward) error('No reward configured for this streak day.', 500);

        $pdo->beginTransaction();
        try {
            $pdo->prepare(
                'INSERT INTO reward_claims (user_id, claim_date, streak_day, reward_type, amount)
                 VALUES (:u, :d, :s, :t, :a)'
            )->execute([
                ':u' => $userId,
                ':d' => $today,
                ':s' => $streakDay,
                ':t' => $reward['reward_type'],
                ':a' => $reward['amount'],
            ]);

            // Credit wallet (delegates its own tx)
            $pdo->commit();
        } catch (Throwable $e) {
            $pdo->rollBack();
            error('Failed to record reward claim: ' . $e->getMessage(), 500);
        }

        // Credit the wallet
        $currency = $reward['reward_type'];
        $newBalance = WalletService::adjust(
            $userId,
            'credit',
            $currency,
            (int)$reward['amount'],
            'daily_reward',
            'reward_day_' . $streakDay
        );

        return [
            'claimed'  => true,
            'streak'   => $streakDay,
            'reward'   => $reward,
            'balance'  => $newBalance,
        ];
    }

    public static function history(int $userId, int $limit = 30): array
    {
        $pdo = Database::connection();
        $stmt = $pdo->prepare(
            'SELECT * FROM reward_claims WHERE user_id = :u ORDER BY claim_date DESC LIMIT :l'
        );
        $stmt->bindValue(':u', $userId, PDO::PARAM_INT);
        $stmt->bindValue(':l', $limit, PDO::PARAM_INT);
        $stmt->execute();
        return $stmt->fetchAll();
    }
}
