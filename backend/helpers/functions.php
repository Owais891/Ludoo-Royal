<?php
/**
 * Global helper functions for Ludo Royale backend.
 */

if (!function_exists('json_response')) {
    function json_response($data, int $status = 200): void
    {
        http_response_code($status);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        exit;
    }
}

if (!function_exists('success')) {
    function success($data = null, string $message = 'OK', int $status = 200): void
    {
        json_response([
            'success' => true,
            'message' => $message,
            'data'    => $data,
        ], $status);
    }
}

if (!function_exists('error')) {
    function error(string $message, int $status = 400, $errors = null): void
    {
        $payload = [
            'success' => false,
            'message' => $message,
        ];
        if ($errors !== null) {
            $payload['errors'] = $errors;
        }
        json_response($payload, $status);
    }
}

if (!function_exists('input_json')) {
    function input_json(): array
    {
        $raw = file_get_contents('php://input');
        if (empty($raw)) {
            return $_POST ?? [];
        }
        $decoded = json_decode($raw, true);
        return is_array($decoded) ? $decoded : $_POST ?? [];
    }
}

if (!function_exists('input_get')) {
    function input_get(string $key, $default = null)
    {
        $body = input_json();
        if (array_key_exists($key, $body)) return $body[$key];
        if (array_key_exists($key, $_GET)) return $_GET[$key];
        return $default;
    }
}

if (!function_exists('gen_uuid')) {
    function gen_uuid(): string
    {
        return sprintf(
            '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
            mt_rand(0, 0xffff), mt_rand(0, 0xffff),
            mt_rand(0, 0xffff),
            mt_rand(0, 0x0fff) | 0x4000,
            mt_rand(0, 0x3fff) | 0x8000,
            mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
        );
    }
}

if (!function_exists('gen_token')) {
    function gen_token(int $len = 64): string
    {
        return bin2hex(random_bytes((int)ceil($len / 2)));
    }
}

if (!function_exists('gen_room_code')) {
    function gen_room_code(int $len = 6): string
    {
        $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        $out = '';
        for ($i = 0; $i < $len; $i++) {
            $out .= $chars[random_int(0, strlen($chars) - 1)];
        }
        return $out;
    }
}

if (!function_exists('validate_email')) {
    function validate_email(string $email): bool
    {
        return (bool)filter_var($email, FILTER_VALIDATE_EMAIL);
    }
}

if (!function_exists('log_event')) {
    function log_event(string $channel, string $message, array $context = []): void
    {
        $dir = __DIR__ . '/../storage/logs';
        if (!is_dir($dir)) @mkdir($dir, 0775, true);
        $line = sprintf("[%s] %s.%s: %s %s\n",
            date('Y-m-d H:i:s'),
            'ludo',
            $channel,
            $message,
            $context ? json_encode($context, JSON_UNESCAPED_UNICODE) : ''
        );
        @file_put_contents($dir . '/app-' . date('Y-m-d') . '.log', $line, FILE_APPEND);
    }
}
