<?php
require_once __DIR__ . '/../helpers/functions.php';
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/cors.php';
require_once __DIR__ . '/../validators/Validator.php';
require_once __DIR__ . '/../middleware/AuthMiddleware.php';
require_once __DIR__ . '/../middleware/RateLimit.php';
require_once __DIR__ . '/../services/GameEngine.php';
require_once __DIR__ . '/../services/DiceService.php';
require_once __DIR__ . '/../services/AuthService.php';
require_once __DIR__ . '/../services/WalletService.php';
require_once __DIR__ . '/../services/RewardService.php';
require_once __DIR__ . '/../services/GameService.php';
require_once __DIR__ . '/../services/MultiplayerService.php';

// Bootstrap
Cors::handle();
date_default_timezone_set('UTC');

// Resolve route
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$uri    = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
$uri    = trim($uri, '/');
$parts  = explode('/', $uri);

// Strip leading "api" if present (handled by .htaccess rewrites)
if (!empty($parts) && $parts[0] === 'api') {
    array_shift($parts);
}

$path = '/' . implode('/', $parts);

// Load route files
$routeFiles = ['auth', 'profile', 'game', 'multiplayer', 'leaderboard', 'rewards', 'history', 'wallet'];
$matched = false;
foreach ($routeFiles as $rfile) {
    $file = __DIR__ . "/../routes/{$rfile}.php";
    if (is_file($file)) {
        $routes = require $file;
        foreach ($routes as $route => $handler) {
            // route pattern like "POST /auth/login"
            if (preg_match('#^([A-Z]+)\s+(.+)$#', $route, $m)) {
                $rMethod = $m[1];
                $rPath   = $m[2];
                if ($method === $rMethod && self_route_match($rPath, $path)) {
                    $handler();
                    $matched = true;
                    break 2;
                }
            }
        }
    }
}

if (!$matched) {
    error('Not Found: ' . $method . ' ' . $path, 404);
}

/**
 * Simple route matcher with {param} placeholders.
 * Captured params are exposed via $GLOBALS['route_params'].
 */
function self_route_match(string $pattern, string $path): bool
{
    $patternRegex = preg_replace_callback('#\{([a-zA-Z_]+)\}#', function ($m) {
        return '(?P<' . $m[1] . '>[^/]+)';
    }, $pattern);
    $patternRegex = '#^' . $patternRegex . '$#';
    if (preg_match($patternRegex, $path, $matches)) {
        $params = [];
        foreach ($matches as $k => $v) {
            if (is_string($k)) $params[$k] = $v;
        }
        $GLOBALS['route_params'] = $params;
        return true;
    }
    return false;
}
