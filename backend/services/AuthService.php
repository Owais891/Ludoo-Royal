<?php
/**
 * AuthService - secure PHP authentication.
 */

final class AuthService
{
    public static function register(array $data): array
    {
        $v = (new Validator($data))
            ->required('full_name')->max('full_name', 100)
            ->required('username')->min('username', 3)->max('username', 50)
            ->required('email')->email('email')
            ->required('password')->min('password', 6)
            ->sameAs('password', 'confirm_password');

        if ($v->fails()) {
            error('Validation failed', 422, $v->errors());
        }
        $data = $v->validated();

        $pdo = Database::connection();

        // Duplicate email/username check
        $stmt = $pdo->prepare('SELECT id FROM users WHERE username = :u OR email = :e LIMIT 1');
        $stmt->execute([':u' => $data['username'], ':e' => $data['email']]);
        if ($stmt->fetch()) {
            error('Username or email already exists.', 409);
        }

        $hash = password_hash($data['password'], PASSWORD_BCRYPT);
        $token = gen_token(64);
        $expires = date('Y-m-d H:i:s', time() + 86400);

        $pdo->beginTransaction();
        try {
            $stmt = $pdo->prepare(
                'INSERT INTO users (full_name, username, email, password_hash, auth_token, token_expires, last_login_at)
                 VALUES (:fn, :u, :e, :p, :t, :ex, NOW())'
            );
            $stmt->execute([
                ':fn' => $data['full_name'],
                ':u'  => $data['username'],
                ':e'  => $data['email'],
                ':p'  => $hash,
                ':t'  => $token,
                ':ex' => $expires,
            ]);
            $uid = (int)$pdo->lastInsertId();

            $pdo->prepare('INSERT INTO user_profiles (user_id) VALUES (:u)')->execute([':u' => $uid]);
            $pdo->prepare('INSERT INTO player_stats (user_id) VALUES (:u)')->execute([':u' => $uid]);
            $pdo->prepare('INSERT INTO wallets (user_id) VALUES (:u)')->execute([':u' => $uid]);

            $pdo->commit();
        } catch (Throwable $e) {
            $pdo->rollBack();
            error('Registration failed: ' . $e->getMessage(), 500);
        }

        $user = self::loadUser($uid);
        return [
            'user'  => $user,
            'token' => $token,
        ];
    }

    public static function login(string $login, string $password): array
    {
        $pdo = Database::connection();
        $stmt = $pdo->prepare(
            'SELECT * FROM users WHERE username = :l OR email = :l LIMIT 1'
        );
        $stmt->execute([':l' => $login]);
        $user = $stmt->fetch();
        if (!$user || !password_verify($password, $user['password_hash'])) {
            error('Invalid credentials.', 401);
        }
        if ((int)$user['is_banned'] === 1) {
            error('Account is banned.', 403);
        }

        $token = gen_token(64);
        $expires = date('Y-m-d H:i:s', time() + 86400);
        $pdo->prepare('UPDATE users SET auth_token = :t, token_expires = :e, last_login_at = NOW(), is_online = 1 WHERE id = :id')
            ->execute([':t' => $token, ':e' => $expires, ':id' => $user['id']]);

        $profile = self::loadUser((int)$user['id']);
        return [
            'user'  => $profile,
            'token' => $token,
        ];
    }

    public static function logout(int $userId): void
    {
        $pdo = Database::connection();
        $pdo->prepare('UPDATE users SET auth_token = NULL, token_expires = NULL, is_online = 0 WHERE id = :id')
            ->execute([':id' => $userId]);
    }

    public static function forgotPassword(string $email): array
    {
        $pdo = Database::connection();
        $stmt = $pdo->prepare('SELECT id FROM users WHERE email = :e LIMIT 1');
        $stmt->execute([':e' => $email]);
        $row = $stmt->fetch();
        if (!$row) {
            // For privacy, still return success
            return ['status' => 'sent'];
        }
        $token = gen_token(32);
        $expires = date('Y-m-d H:i:s', time() + 3600);
        $pdo->prepare('UPDATE users SET reset_token = :t, reset_expires = :e WHERE id = :id')
            ->execute([':t' => $token, ':e' => $expires, ':id' => $row['id']]);
        // In production: send email with reset link. Here we return the token for testing.
        return ['status' => 'sent', 'reset_token' => $token];
    }

    public static function resetPassword(string $token, string $newPassword): void
    {
        if (strlen($newPassword) < 6) {
            error('Password must be at least 6 characters.', 422);
        }
        $pdo = Database::connection();
        $stmt = $pdo->prepare('SELECT id FROM users WHERE reset_token = :t AND reset_expires > NOW() LIMIT 1');
        $stmt->execute([':t' => $token]);
        $row = $stmt->fetch();
        if (!$row) {
            error('Invalid or expired reset token.', 400);
        }
        $hash = password_hash($newPassword, PASSWORD_BCRYPT);
        $newToken = gen_token(64);
        $expires = date('Y-m-d H:i:s', time() + 86400);
        $pdo->prepare('UPDATE users SET password_hash = :p, reset_token = NULL, reset_expires = NULL,
                          auth_token = :t, token_expires = :e WHERE id = :id')
            ->execute([':p' => $hash, ':t' => $newToken, ':e' => $expires, ':id' => $row['id']]);
    }

    public static function loadUser(int $userId): array
    {
        $pdo = Database::connection();
        $stmt = $pdo->prepare(
            'SELECT u.id, u.full_name, u.username, u.email, u.avatar_url, u.is_online, u.last_login_at,
                    p.player_level, p.experience, p.country_code, p.bio,
                    s.total_matches, s.total_wins, s.total_losses, s.total_captures,
                    w.coins, w.gems
               FROM users u
               LEFT JOIN user_profiles p ON p.user_id = u.id
               LEFT JOIN player_stats  s ON s.user_id = u.id
               LEFT JOIN wallets       w ON w.user_id = u.id
              WHERE u.id = :id'
        );
        $stmt->execute([':id' => $userId]);
        $user = $stmt->fetch();
        if (!$user) error('User not found.', 404);
        $user['id'] = (int)$user['id'];
        $user['player_level'] = (int)($user['player_level'] ?? 1);
        $user['experience']   = (int)($user['experience'] ?? 0);
        $user['total_matches']= (int)($user['total_matches'] ?? 0);
        $user['total_wins']   = (int)($user['total_wins'] ?? 0);
        $user['total_losses'] = (int)($user['total_losses'] ?? 0);
        $user['total_captures']= (int)($user['total_captures'] ?? 0);
        $user['coins']        = (int)($user['coins'] ?? 500);
        $user['gems']         = (int)($user['gems'] ?? 10);
        $user['win_rate']     = $user['total_matches'] > 0
            ? round(($user['total_wins'] / $user['total_matches']) * 100, 2)
            : 0.0;
        return $user;
    }

    public static function updateProfile(int $userId, array $data): array
    {
        $pdo = Database::connection();
        $allowed = ['full_name', 'avatar_url'];
        $updates = [];
        $params = [':id' => $userId];
        foreach ($allowed as $field) {
            if (isset($data[$field])) {
                $updates[] = "$field = :$field";
                $params[":$field"] = $data[$field];
            }
        }
        if (!empty($updates)) {
            $sql = 'UPDATE users SET ' . implode(', ', $updates) . ' WHERE id = :id';
            $pdo->prepare($sql)->execute($params);
        }

        $profileFields = ['avatar_url', 'country_code', 'bio'];
        $pUpdates = [];
        $pParams = [':id' => $userId];
        foreach ($profileFields as $field) {
            if (isset($data[$field])) {
                $pUpdates[] = "$field = :$field";
                $pParams[":$field"] = $data[$field];
            }
        }
        if (!empty($pUpdates)) {
            $sql = 'UPDATE user_profiles SET ' . implode(', ', $pUpdates) . ' WHERE user_id = :id';
            $pdo->prepare($sql)->execute($pParams);
        }
        return self::loadUser($userId);
    }
}
