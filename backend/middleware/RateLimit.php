<?php
/**
 * Simple in-memory rate limiter backed by a file cache.
 * For production use Redis or APCu.
 */
final class RateLimit
{
    public static function check(string $key, int $max, int $windowSec): bool
    {
        $dir = __DIR__ . '/../storage/logs';
        if (!is_dir($dir)) @mkdir($dir, 0775, true);
        $file = $dir . '/ratelimit_' . md5($key) . '.json';

        $now = time();
        $data = ['count' => 0, 'window_start' => $now];
        if (is_file($file)) {
            $raw = @file_get_contents($file);
            $decoded = json_decode($raw, true);
            if (is_array($decoded) && ($now - $decoded['window_start']) < $windowSec) {
                $data = $decoded;
            }
        }

        if ($data['count'] >= $max) {
            return false;
        }
        $data['count']++;
        @file_put_contents($file, json_encode($data));
        return true;
    }
}
