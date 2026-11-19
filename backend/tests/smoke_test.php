<?php
/**
 * Simple smoke test for the Ludo Royale backend.
 * Run with: php tests/smoke_test.php
 * Adjusts the include path so we can use the project's autoloading.
 */

require_once __DIR__ . '/../helpers/functions.php';
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/cors.php';
require_once __DIR__ . '/../validators/Validator.php';
require_once __DIR__ . '/../services/GameEngine.php';
require_once __DIR__ . '/../services/DiceService.php';

$failures = 0;
function assert_true(bool $cond, string $msg): void {
    global $failures;
    if (!$cond) {
        echo "FAIL: $msg\n";
        $failures++;
    } else {
        echo "PASS: $msg\n";
    }
}

// 1. Engine: token at base requires 6
$tokens = GameEngine::initialState();
$moves = GameEngine::getValidMoves($tokens, 'red', 5);
assert_true(empty($moves), 'Red token at base cannot move with dice 5');

$moves = GameEngine::getValidMoves($tokens, 'red', 6);
assert_true(!empty($moves), 'Red token at base CAN leave with dice 6');

// 2. DiceService returns 1..6
$dice = DiceService::roll();
assert_true($dice >= 1 && $dice <= 6, 'DiceService::roll returns 1..6');

// 3. destinationOf for red from 0 with dice 5 = 5
$dest = GameEngine::destinationOf('red', 0, 5);
assert_true($dest === 5, 'Red from 0 + dice 5 = position 5');

// 4. Capture detection
$tokens['red'][0] = 4;
$tokens['green'][0] = 5;
$captured = GameEngine::checkCapture($tokens, 'red', 5);
assert_true($captured === 'green', 'Red moving to 5 captures green');

// 5. Safe cell prevents capture
$captured = GameEngine::checkCapture($tokens, 'red', 0);
assert_true($captured === null, 'Safe cell 0 prevents capture');

// 6. Win detection
$tokens['red'] = [57, 57, 57, 57];
assert_true(GameEngine::checkWin($tokens, 'red'), 'Red wins when all tokens at home');

echo "\n";
if ($failures === 0) {
    echo "All smoke tests passed.\n";
    exit(0);
} else {
    echo "$failures test(s) failed.\n";
    exit(1);
}
