<?php
/**
 * CORS configuration handler
 */
final class Cors
{
    public static function handle(): void
    {
        $cfg = require __DIR__ . '/app.php';
        $cors = $cfg['cors'];

        $origin = $_SERVER['HTTP_ORIGIN'] ?? '*';
        $allowed = in_array('*', $cors['allowed_origins'], true)
            ? true
            : in_array($origin, $cors['allowed_origins'], true);

        if ($allowed) {
            header('Access-Control-Allow-Origin: ' . $origin);
        }
        header('Access-Control-Allow-Methods: ' . implode(', ', $cors['allowed_methods']));
        header('Access-Control-Allow-Headers: ' . implode(', ', $cors['allowed_headers']));
        header('Access-Control-Max-Age: ' . $cors['max_age']);
        header('Access-Control-Allow-Credentials: true');

        if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') {
            http_response_code(204);
            exit;
        }
    }
}
