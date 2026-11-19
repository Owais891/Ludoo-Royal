<?php
/**
 * Authentication middleware.
 * Reads Authorization: Bearer <token> header and loads the user.
 * On failure sends 401 and exits.
 */
final class AuthMiddleware
{
    public static function user(): ?array
    {
        $token = self::bearerToken();
        if (!$token) {
            return null;
        }

        $pdo = Database::connection();
        $stmt = $pdo->prepare(
            'SELECT u.id, u.full_name, u.username, u.email, u.avatar_url, u.auth_token,
                    u.token_expires, u.is_banned
               FROM users u
              WHERE u.auth_token = :t
                AND u.token_expires > NOW()
                AND u.is_banned = 0
              LIMIT 1'
        );
        $stmt->execute([':t' => $token]);
        $user = $stmt->fetch();
        if (!$user) {
            return null;
        }
        return $user;
    }

    public static function requireUser(): array
    {
        $user = self::user();
        if (!$user) {
            error('Unauthorized. Invalid or expired token.', 401);
        }
        // bump last_seen
        $pdo = Database::connection();
        $pdo->prepare('UPDATE users SET last_seen_at = NOW(), is_online = 1 WHERE id = :id')
            ->execute([':id' => $user['id']]);
        return $user;
    }

    private static function bearerToken(): ?string
    {
        $headers = self::headers();
        $auth = $headers['Authorization'] ?? $headers['authorization'] ?? '';
        if (preg_match('/Bearer\s+(\S+)/i', $auth, $m)) {
            return $m[1];
        }
        return $_GET['token'] ?? null;
    }

    private static function headers(): array
    {
        if (function_exists('getallheaders')) {
            return getallheaders() ?: [];
        }
        // Fallback for non-Apache servers
        $out = [];
        foreach ($_SERVER as $k => $v) {
            if (strpos($k, 'HTTP_') === 0) {
                $name = str_replace(' ', '-', ucwords(strtolower(str_replace('_', ' ', substr($k, 5)))));
                $out[$name] = $v;
            }
        }
        return $out;
    }
}
