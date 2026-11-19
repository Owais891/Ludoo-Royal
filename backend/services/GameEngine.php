<?php
/**
 * Server-authoritative Ludo game engine for Ludo Royale.
 *
 * This is the PHP counterpart of the Flutter GameEngine; it is responsible
 * for validating every move submitted by clients in online matches. The
 * client never decides what's legal — the server does.
 *
 * Board layout (52 outer cells + 4 home paths of 5 cells each).
 * Player start positions and home-entry positions are encoded below.
 */

final class GameEngine
{
    public const COLORS = ['red', 'green', 'yellow', 'blue'];

    // Index on the 52-cell outer loop where each color "starts" (entry point).
    public const START_POS = [
        'red'    => 0,
        'green'  => 13,
        'yellow' => 26,
        'blue'   => 39,
    ];

    // Index on the outer loop after which the token turns into its home path.
    public const HOME_ENTRY = [
        'red'    => 50,   // after 50, next step enters red home path
        'green'  => 11,
        'yellow' => 24,
        'blue'   => 37,
    ];

    // Safe cells (star cells + start cells).
    public const SAFE_CELLS = [0, 8, 13, 21, 26, 34, 39, 47];

    public const HOME_PATH_LEN = 6;   // 5 colored cells + final home
    public const TOKENS_PER_PLAYER = 4;
    public const BASE = -1;            // token at base (not on board)
    public const HOME = 56;            // token reached home (final)

    /**
     * Build a fresh token state for a new match.
     * Returns assoc array: color => [pos, pos, pos, pos] (all -1 = at base)
     */
    public static function initialState(): array
    {
        $state = [];
        foreach (self::COLORS as $c) {
            $state[$c] = array_fill(0, self::TOKENS_PER_PLAYER, self::BASE);
        }
        return $state;
    }

    /**
     * Validate a single move. Returns ['ok' => bool, 'reason' => string]
     */
    public static function isMoveLegal(array $tokens, string $color, int $tokenIndex, int $dice): array
    {
        if (!in_array($color, self::COLORS, true)) {
            return ['ok' => false, 'reason' => 'Invalid color'];
        }
        if ($dice < 1 || $dice > 6) {
            return ['ok' => false, 'reason' => 'Invalid dice value'];
        }
        if ($tokenIndex < 0 || $tokenIndex >= self::TOKENS_PER_PLAYER) {
            return ['ok' => false, 'reason' => 'Invalid token index'];
        }
        $pos = $tokens[$color][$tokenIndex];
        if ($pos === self::HOME) {
            return ['ok' => false, 'reason' => 'Token already home'];
        }
        if ($pos === self::BASE && $dice !== 6) {
            return ['ok' => false, 'reason' => 'Need a 6 to leave base'];
        }
        $newPos = self::destinationOf($color, $pos, $dice);
        if ($newPos === null) {
            return ['ok' => false, 'reason' => 'Move overshoots home'];
        }
        return ['ok' => true, 'reason' => '', 'new_pos' => $newPos];
    }

    /**
     * Returns the list of token indices that can legally move with the dice.
     */
    public static function getValidMoves(array $tokens, string $color, int $dice): array
    {
        $moves = [];
        for ($i = 0; $i < self::TOKENS_PER_PLAYER; $i++) {
            $check = self::isMoveLegal($tokens, $color, $i, $dice);
            if ($check['ok']) {
                $moves[] = $i;
            }
        }
        return $moves;
    }

    /**
     * Compute destination position for a token.
     * Returns null if move overshoots home (illegal).
     */
    public static function destinationOf(string $color, int $pos, int $dice): ?int
    {
        // From base -> start
        if ($pos === self::BASE) {
            if ($dice === 6) {
                return self::START_POS[$color];
            }
            return null;
        }

        // Token already on outer path (0..51). Determine if it crosses home entry.
        if ($pos < 52) {
            $entry = self::HOME_ENTRY[$color];
            $travelBeforeHome = (($entry - $pos + 52) % 52);  // cells to travel before turning into home path
            if ($dice <= $travelBeforeHome) {
                // stays on outer path
                return ($pos + $dice) % 52;
            }
            // enters home path
            $homeStep = $dice - $travelBeforeHome - 1; // 0..5
            if ($homeStep >= self::HOME_PATH_LEN) {
                return null; // overshoot
            }
            return 52 + $homeStep; // 52..57 are home path positions
        }

        // pos >= 52 -> already on home path
        if ($pos >= 52 && $pos <= 57) {
            $homeStep = $pos - 52;
            $newStep = $homeStep + $dice;
            if ($newStep >= self::HOME_PATH_LEN) {
                return null; // overshoot
            }
            return 52 + $newStep;
        }
        return null;
    }

    /**
     * Returns the color captured by moving $color token to $newPos, or null if none.
     * Tokens on safe cells or tokens of same color cannot be captured.
     */
    public static function checkCapture(array $tokens, string $color, int $newPos): ?string
    {
        if ($newPos < 0 || $newPos >= 52) return null; // home path / base: no capture
        if (in_array($newPos, self::SAFE_CELLS, true)) return null;
        foreach (self::COLORS as $other) {
            if ($other === $color) continue;
            $count = 0;
            foreach ($tokens[$other] as $p) {
                if ($p === $newPos) $count++;
            }
            // Single opponent token captured; pair on same cell is a "block" (not captured)
            if ($count === 1) {
                return $other;
            }
        }
        return null;
    }

    /**
     * Apply the move. Returns:
     * [
     *   'tokens'      => new tokens state,
     *   'captured'   => captured color or null,
     *   'captured_tokens' => [color => [idx, idx], ...] (token indices reset to base)
     *   'extra_turn' => bool (true if dice=6 or capture)
     * ]
     */
    public static function applyMove(array $tokens, string $color, int $tokenIndex, int $dice): array
    {
        $check = self::isMoveLegal($tokens, $color, $tokenIndex, $dice);
        if (!$check['ok']) {
            throw new InvalidArgumentException($check['reason']);
        }
        $newPos = $check['new_pos'];

        $capturedColor = self::checkCapture($tokens, $color, $newPos);
        $capturedTokenIndices = [];
        if ($capturedColor !== null) {
            foreach ($tokens[$capturedColor] as $i => $p) {
                if ($p === $newPos) {
                    $tokens[$capturedColor][$i] = self::BASE;
                    $capturedTokenIndices[] = $i;
                }
            }
        }
        $tokens[$color][$tokenIndex] = $newPos;

        return [
            'tokens'             => $tokens,
            'new_pos'            => $newPos,
            'captured'           => $capturedColor,
            'captured_tokens'    => $capturedTokenIndices,
            'extra_turn'         => ($dice === 6) || ($capturedColor !== null),
        ];
    }

    /**
     * Has $color won? (all 4 tokens at HOME position 57)
     */
    public static function checkWin(array $tokens, string $color): bool
    {
        foreach ($tokens[$color] as $p) {
            if ($p !== self::HOME) return false;
        }
        return true;
    }

    /**
     * Determine next seat index, accounting for finished players.
     * $activeSeats = [0,1,2,3] (subset still playing).
     */
    public static function nextSeat(int $current, array $activeSeats): int
    {
        sort($activeSeats);
        $idx = array_search($current, $activeSeats, true);
        if ($idx === false) return $activeSeats[0];
        $next = $idx + 1;
        if ($next >= count($activeSeats)) $next = 0;
        return $activeSeats[$next];
    }
}
