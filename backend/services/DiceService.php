<?php
/**
 * Server-side dice roller (cryptographically secure).
 * The server NEVER trusts a client-provided dice value in online matches.
 */
final class DiceService
{
    /**
     * Roll a deterministic-random dice value 1..6.
     */
    public static function roll(): int
    {
        return random_int(1, 6);
    }

    /**
     * Roll N dice and return the array of values.
     */
    public static function rollMany(int $n): array
    {
        $out = [];
        for ($i = 0; $n > 0 && $i < $n; $i++) {
            $out[] = self::roll();
        }
        return $out;
    }
}
