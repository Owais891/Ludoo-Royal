<?php
/**
 * WalletService - all wallet operations go through here and are atomic.
 */
final class WalletService
{
    public static function getBalance(int $userId): array
    {
        $pdo = Database::connection();
        $stmt = $pdo->prepare('SELECT coins, gems FROM wallets WHERE user_id = :u');
        $stmt->execute([':u' => $userId]);
        $row = $stmt->fetch();
        if (!$row) {
            return ['coins' => 0, 'gems' => 0];
        }
        return ['coins' => (int)$row['coins'], 'gems' => (int)$row['gems']];
    }

    public static function transactions(int $userId, int $limit = 50): array
    {
        $pdo = Database::connection();
        $stmt = $pdo->prepare(
            'SELECT * FROM wallet_transactions WHERE user_id = :u ORDER BY id DESC LIMIT :l'
        );
        $stmt->bindValue(':u', $userId, PDO::PARAM_INT);
        $stmt->bindValue(':l', $limit, PDO::PARAM_INT);
        $stmt->execute();
        return $stmt->fetchAll();
    }

    /**
     * Atomic credit/debit operation.
     *
     * @param int    $userId
     * @param string $type     'credit' or 'debit'
     * @param string $currency 'coin' or 'gem'
     * @param int    $amount   Positive integer
     * @param string $reason   e.g. 'match_win', 'daily_reward', 'entry_fee'
     * @param string|null $ref Optional reference id (match id etc.)
     */
    public static function adjust(int $userId, string $type, string $currency, int $amount, string $reason, ?string $ref = null): array
    {
        if ($amount <= 0) error('Amount must be positive.', 422);
        if (!in_array($type, ['credit', 'debit'], true)) error('Invalid type.', 422);
        if (!in_array($currency, ['coin', 'gem'], true)) error('Invalid currency.', 422);
        if ($type === 'debit') {
            // ensure sufficient funds
            $bal = self::getBalance($userId);
            if ($bal[$currency . 's'] < $amount) {
                error("Insufficient {$currency}s.", 422);
            }
        }

        $pdo = Database::connection();
        $pdo->beginTransaction();
        try {
            // Lock wallet row
            $stmt = $pdo->prepare("SELECT coins, gems FROM wallets WHERE user_id = :u FOR UPDATE");
            $stmt->execute([':u' => $userId]);
            $row = $stmt->fetch();
            if (!$row) {
                $pdo->rollBack();
                error('Wallet not found.', 404);
            }
            $coins = (int)$row['coins'];
            $gems  = (int)$row['gems'];

            if ($currency === 'coin') {
                $coins = $type === 'credit' ? $coins + $amount : $coins - $amount;
                if ($coins < 0) {
                    $pdo->rollBack();
                    error('Insufficient coins.', 422);
                }
                $sql = 'UPDATE wallets SET coins = :c WHERE user_id = :u';
                $params = [':c' => $coins, ':u' => $userId];
            } else {
                $gems = $type === 'credit' ? $gems + $amount : $gems - $amount;
                if ($gems < 0) {
                    $pdo->rollBack();
                    error('Insufficient gems.', 422);
                }
                $sql = 'UPDATE wallets SET gems = :g WHERE user_id = :u';
                $params = [':g' => $gems, ':u' => $userId];
            }
            $pdo->prepare($sql)->execute($params);

            $balanceAfter = $currency === 'coin' ? $coins : $gems;
            $pdo->prepare(
                'INSERT INTO wallet_transactions (user_id, type, currency, amount, balance_after, reason, reference_id)
                 VALUES (:u, :t, :c, :a, :b, :r, :ref)'
            )->execute([
                ':u'   => $userId,
                ':t'   => $type,
                ':c'   => $currency,
                ':a'   => $amount,
                ':b'   => $balanceAfter,
                ':r'   => $reason,
                ':ref' => $ref,
            ]);
            $pdo->commit();
        } catch (Throwable $e) {
            $pdo->rollBack();
            error('Wallet transaction failed: ' . $e->getMessage(), 500);
        }
        return self::getBalance($userId);
    }
}
