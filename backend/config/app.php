<?php
/**
 * Ludo Royale - Backend configuration
 * Copy this file to .env and adjust values.
 * NEVER commit the real .env file.
 */

return [
    'app' => [
        'name'        => 'Ludo Royale API',
        'env'         => getenv('APP_ENV') ?: 'development',
        'debug'       => (getenv('APP_DEBUG') ?: 'true') === 'true',
        'timezone'    => 'UTC',
        'url'         => getenv('APP_URL') ?: 'http://localhost:8000',
    ],

    'database' => [
        'host'    => getenv('DB_HOST') ?: '127.0.0.1',
        'port'    => (int)(getenv('DB_PORT') ?: 3306),
        'name'    => getenv('DB_NAME') ?: 'ludo_royale',
        'user'    => getenv('DB_USER') ?: 'root',
        'pass'    => getenv('DB_PASS') ?: '',
        'charset' => 'utf8mb4',
    ],

    'jwt' => [
        'secret'        => getenv('JWT_SECRET') ?: 'change-this-secret-key-in-production',
        'token_ttl_min' => (int)(getenv('JWT_TTL') ?: 1440), // 24h
    ],

    'cors' => [
        'allowed_origins' => ['*'],
        'allowed_methods'  => ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
        'allowed_headers'  => ['Content-Type', 'Authorization', 'X-Requested-With'],
        'max_age'          => 86400,
    ],

    'rate_limit' => [
        'enabled'    => true,
        'window_sec' => 60,
        'max_calls'  => 120,
    ],

    'storage' => [
        'avatars' => __DIR__ . '/../storage/avatars',
        'logs'    => __DIR__ . '/../storage/logs',
    ],
];
