<?php
/**
 * GameService - orchestrates match lifecycle, dice rolls, moves, server-authoritative state.
 *
 * Important: dice values are generated SERVER-SIDE and saved into game_states.
 * Clients submit moves that the server validates against the current state.
 */
final class GameService
{
    public static function createMatch(int $hostId, string $mode, int $maxPlayers, int $entryFee = 0): array
    {
        $pdo = Database::connection();
        $code = gen_room_code(8);

        $pdo->beginTransaction();
        try {
            $stmt = $pdo->prepare(
                'INSERT INTO matches (code, mode, max_players, status, host_id, entry_fee, prize_pool)
                 VALUES (:c, :m, :mp, :s, :h, :ef, :pp)'
            );
            $stmt->execute([
                ':c'  => $code,
                ':m'  => $mode,
                ':mp' => $maxPlayers,
                ':s'  => $maxPlayers === 1 ? 'active' : 'waiting',
                ':h'  => $hostId,
                ':ef' => $entryFee,
                ':pp' => $entryFee * $maxPlayers,
            ]);
            $matchId = (int)$pdo->lastInsertId();

            // Host joins as seat 0 (red)
            $color = GameEngine::COLORS[0];
            $stmt = $pdo->prepare(
                'INSERT INTO match_players (match_id, user_id, player_color, seat, is_ready)
                 VALUES (:m, :u, :c, 0, 1)'
            );
            $stmt->execute([':m' => $matchId, ':u' => $hostId, ':c' => $color]);

            // Initial state
            $tokens = GameEngine::initialState();
            $stmt = $pdo->prepare(
                'INSERT INTO game_states (match_id, tokens_json) VALUES (:m, :t)'
            );
            $stmt->execute([
                ':m' => $matchId,
                ':t' => json_encode($tokens),
            ]);

            $pdo->commit();
        } catch (Throwable $e) {
            $pdo->rollBack();
            error('Failed to create match: ' . $e->getMessage(), 500);
        }

        return self::loadMatch($matchId);
    }

    public static function joinMatch(int $userId, int $matchId): array
    {
        $pdo = Database::connection();
        $pdo->beginTransaction();
        try {
            $stmt = $pdo->prepare('SELECT * FROM matches WHERE id = :m FOR UPDATE');
            $stmt->execute([':m' => $matchId]);
            $match = $stmt->fetch();
            if (!$match) {
                $pdo->rollBack();
                error('Match not found.', 404);
            }
            if (in_array($match['status'], ['finished', 'abandoned'], true)) {
                $pdo->rollBack();
                error('Match no longer joinable.', 400);
            }

            $stmt = $pdo->prepare('SELECT COUNT(*) AS c FROM match_players WHERE match_id = :m');
            $stmt->execute([':m' => $matchId]);
            $count = (int)$stmt->fetch()['c'];
            if ($count >= (int)$match['max_players']) {
                $pdo->rollBack();
                error('Match is full.', 400);
            }

            $stmt = $pdo->prepare('SELECT * FROM match_players WHERE match_id = :m AND user_id = :u');
            $stmt->execute([':m' => $matchId, ':u' => $userId]);
            if ($stmt->fetch()) {
                $pdo->rollBack();
                error('Already joined.', 409);
            }

            $seat = $count;
            $color = GameEngine::COLORS[$seat];
            $pdo->prepare(
                'INSERT INTO match_players (match_id, user_id, player_color, seat, is_ready)
                 VALUES (:m, :u, :c, :s, 1)'
            )->execute([':m' => $matchId, ':u' => $userId, ':c' => $color, ':s' => $seat]);

            // Refresh counts; if full, mark active
            $stmt = $pdo->prepare('SELECT COUNT(*) AS c FROM match_players WHERE match_id = :m');
            $stmt->execute([':m' => $matchId]);
            $count = (int)$stmt->fetch()['c'];
            if ($count >= (int)$match['max_players']) {
                $pdo->prepare("UPDATE matches SET status = 'active', started_at = NOW(), current_player = 0, phase='rolling' WHERE id = :m")
                    ->execute([':m' => $matchId]);
                $pdo->prepare("UPDATE game_states SET phase = 'rolling' WHERE match_id = :m")
                    ->execute([':m' => $matchId]);
            }
            $pdo->commit();
        } catch (Throwable $e) {
            $pdo->rollBack();
            error('Failed to join match: ' . $e->getMessage(), 500);
        }
        return self::loadMatch($matchId);
    }

    /**
     * Server-authoritative dice roll.
     */
    public static function rollDice(int $matchId, int $userId): array
    {
        $pdo = Database::connection();
        $pdo->beginTransaction();
        try {
            $stmt = $pdo->prepare('SELECT * FROM matches WHERE id = :m FOR UPDATE');
            $stmt->execute([':m' => $matchId]);
            $match = $stmt->fetch();
            if (!$match) { $pdo->rollBack(); error('Match not found.', 404); }
            if ($match['status'] !== 'active') {
                $pdo->rollBack();
                error('Match not active.', 400);
            }
            // Confirm player seat
            $stmt = $pdo->prepare('SELECT * FROM match_players WHERE match_id = :m AND user_id = :u');
            $stmt->execute([':m' => $matchId, ':u' => $userId]);
            $mp = $stmt->fetch();
            if (!$mp) { $pdo->rollBack(); error('Player not in match.', 403); }
            if ((int)$mp['seat'] !== (int)$match['current_player']) {
                $pdo->rollBack();
                error('Not your turn.', 403);
            }

            // Lock game state
            $stmt = $pdo->prepare('SELECT * FROM game_states WHERE match_id = :m FOR UPDATE');
            $stmt->execute([':m' => $matchId]);
            $state = $stmt->fetch();
            if (!$state) { $pdo->rollBack(); error('Game state missing.', 500); }
            if ($state['phase'] !== 'rolling') {
                $pdo->rollBack();
                error('Cannot roll now - move pending.', 400);
            }

            $dice = DiceService::roll();
            $tokens = json_decode($state['tokens_json'], true);

            // Determine if player has any legal moves
            $color = $mp['player_color'];
            $validMoves = GameEngine::getValidMoves($tokens, $color, $dice);
            $sixCounter = (int)$match['six_counter'];

            // Three sixes rule: forfeit turn
            if ($dice === 6) {
                $sixCounter++;
            } else {
                $sixCounter = 0;
            }
            if ($sixCounter >= 3) {
                // Forfeit and advance turn
                self::advanceTurn($pdo, $matchId, $tokens, false, 0);
                $pdo->commit();
                return [
                    'dice'        => $dice,
                    'six_counter' => $sixCounter,
                    'valid_moves' => [],
                    'forfeit'     => true,
                    'reason'      => 'Three consecutive sixes - turn forfeited.',
                ];
            }

            $newPhase = !empty($validMoves) ? 'moving' : 'rolling';
            // If no moves and dice != 6, advance turn
            $advanceTurn = false;
            if (empty($validMoves) && $dice !== 6) {
                $advanceTurn = true;
                $newPhase = 'rolling';
            }
            // If dice === 6 but no moves (e.g. all tokens at home path needing exact), keep same turn but require another roll
            // For simplicity: if no valid moves and dice=6, give another roll (advance state but keep seat)
            if (empty($validMoves) && $dice === 6) {
                $newPhase = 'rolling';
            }

            // Save dice value & phase
            $pdo->prepare(
                'UPDATE matches SET six_counter = :s WHERE id = :m'
            )->execute([':s' => $sixCounter, ':m' => $matchId]);

            if ($advanceTurn) {
                self::advanceTurn($pdo, $matchId, $tokens, false, 0);
            } else {
                $pdo->prepare(
                    'UPDATE game_states SET dice_value = :d, phase = :p, version = version + 1 WHERE match_id = :m'
                )->execute([':d' => $dice, ':p' => $newPhase, ':m' => $matchId]);
            }

            // Record move
            $pdo->prepare(
                'INSERT INTO game_moves (match_id, player_seat, move_type, dice_value)
                 VALUES (:m, :s, :t, :d)'
            )->execute([
                ':m' => $matchId,
                ':s' => $mp['seat'],
                ':t' => 'roll',
                ':d' => $dice,
            ]);

            $pdo->commit();
        } catch (Throwable $e) {
            $pdo->rollBack();
            error('Roll dice failed: ' . $e->getMessage(), 500);
        }
        return [
            'dice'        => $dice,
            'six_counter' => $sixCounter,
            'valid_moves' => $validMoves,
            'forfeit'     => false,
        ];
    }

    /**
     * Apply a player's token move. Server validates legality.
     */
    public static function moveToken(int $matchId, int $userId, int $tokenIndex): array
    {
        $pdo = Database::connection();
        $pdo->beginTransaction();
        try {
            $stmt = $pdo->prepare('SELECT * FROM matches WHERE id = :m FOR UPDATE');
            $stmt->execute([':m' => $matchId]);
            $match = $stmt->fetch();
            if (!$match) { $pdo->rollBack(); error('Match not found.', 404); }

            $stmt = $pdo->prepare('SELECT * FROM match_players WHERE match_id = :m AND user_id = :u');
            $stmt->execute([':m' => $matchId, ':u' => $userId]);
            $mp = $stmt->fetch();
            if (!$mp) { $pdo->rollBack(); error('Player not in match.', 403); }
            if ((int)$mp['seat'] !== (int)$match['current_player']) {
                $pdo->rollBack();
                error('Not your turn.', 403);
            }

            $stmt = $pdo->prepare('SELECT * FROM game_states WHERE match_id = :m FOR UPDATE');
            $stmt->execute([':m' => $matchId]);
            $state = $stmt->fetch();
            if (!$state) { $pdo->rollBack(); error('Game state missing.', 500); }
            if ($state['phase'] !== 'moving') {
                $pdo->rollBack();
                error('No move pending.', 400);
            }

            $dice   = (int)$state['dice_value'];
            $color  = $mp['player_color'];
            $tokens = json_decode($state['tokens_json'], true);

            $result = GameEngine::applyMove($tokens, $color, $tokenIndex, $dice);
            $newTokens = $result['tokens'];

            // Save state
            $pdo->prepare(
                'UPDATE game_states SET tokens_json = :t, phase = :p, dice_value = NULL, version = version + 1 WHERE match_id = :m'
            )->execute([
                ':t' => json_encode($newTokens),
                ':p' => 'rolling',
                ':m' => $matchId,
            ]);

            // Record move
            $pdo->prepare(
                'INSERT INTO game_moves (match_id, player_seat, move_type, dice_value, token_index, from_pos, to_pos, extra_data)
                 VALUES (:m, :s, :t, :d, :ti, :fp, :tp, :ed)'
            )->execute([
                ':m'  => $matchId,
                ':s'  => $mp['seat'],
                ':t'  => $result['captured'] !== null ? 'capture' : 'move',
                ':d'  => $dice,
                ':ti' => $tokenIndex,
                ':fp' => null,
                ':tp' => $result['new_pos'],
                ':ed' => json_encode([
                    'captured'           => $result['captured'],
                    'captured_tokens'    => $result['captured_tokens'],
                    'extra_turn'         => $result['extra_turn'],
                ]),
            ]);

            // Update player captures if a capture happened
            if ($result['captured'] !== null) {
                $pdo->prepare(
                    'UPDATE match_players SET captures = captures + 1 WHERE match_id = :m AND user_id = :u'
                )->execute([':m' => $matchId, ':u' => $userId]);
            }

            // Reset six counter if move not from a 6
            if ($dice !== 6) {
                $pdo->prepare('UPDATE matches SET six_counter = 0 WHERE id = :m')
                    ->execute([':m' => $matchId]);
            }

            // Check win
            if (GameEngine::checkWin($newTokens, $color)) {
                $pdo->prepare(
                    'UPDATE match_players SET final_rank = 1 WHERE match_id = :m AND user_id = :u'
                )->execute([':m' => $matchId, ':u' => $userId]);

                // Check if all human/AI players finished
                $stmt = $pdo->prepare('SELECT COUNT(*) AS c FROM match_players WHERE match_id = :m AND final_rank IS NULL');
                $stmt->execute([':m' => $matchId]);
                $remaining = (int)$stmt->fetch()['c'];

                if ($remaining <= 1) {
                    // Match finished
                    self::finishMatch($pdo, $matchId, $userId);
                } else {
                    // Advance to next seat
                    self::advanceTurn($pdo, $matchId, $newTokens, $result['extra_turn'], $match['current_player']);
                }
            } else {
                // Advance or give extra turn
                self::advanceTurn($pdo, $matchId, $newTokens, $result['extra_turn'], $match['current_player']);
            }

            $pdo->commit();
        } catch (Throwable $e) {
            $pdo->rollBack();
            error('Move failed: ' . $e->getMessage(), 500);
        }
        return self::loadMatch($matchId);
    }

    /**
     * Advance turn (or keep current seat on extra turn).
     */
    private static function advanceTurn(PDO $pdo, int $matchId, array $tokens, bool $extraTurn, int $currentSeat): void
    {
        // Active seats = those without final_rank
        $stmt = $pdo->prepare('SELECT seat FROM match_players WHERE match_id = :m AND final_rank IS NULL ORDER BY seat');
        $stmt->execute([':m' => $matchId]);
        $seats = array_map('intval', array_column($stmt->fetchAll(), 'seat'));
        if (empty($seats)) return;

        $next = $extraTurn
            ? $currentSeat
            : GameEngine::nextSeat($currentSeat, $seats);

        $pdo->prepare(
            'UPDATE matches SET current_player = :p, turn_number = turn_number + 1, six_counter = 0 WHERE id = :m'
        )->execute([':p' => $next, ':m' => $matchId]);

        $pdo->prepare(
            'UPDATE game_states SET phase = :p, dice_value = NULL, version = version + 1 WHERE match_id = :m'
        )->execute([':p' => 'rolling', ':m' => $matchId]);
    }

    private static function finishMatch(PDO $pdo, int $matchId, int $winnerId): void
    {
        $pdo->prepare(
            "UPDATE matches SET status = 'finished', winner_id = :w, finished_at = NOW() WHERE id = :m"
        )->execute([':w' => $winnerId, ':m' => $matchId]);

        $pdo->prepare(
            "UPDATE game_states SET phase = 'finished' WHERE match_id = :m"
        )->execute([':m' => $matchId]);

        // Build history record
        $stmt = $pdo->prepare(
            'SELECT mp.*, u.username FROM match_players mp LEFT JOIN users u ON u.id = mp.user_id WHERE mp.match_id = :m'
        );
        $stmt->execute([':m' => $matchId]);
        $players = $stmt->fetchAll();
        $stmt = $pdo->prepare('SELECT * FROM matches WHERE id = :m');
        $stmt->execute([':m' => $matchId]);
        $match = $stmt->fetch();

        $duration = $match['started_at']
            ? (time() - strtotime($match['started_at']))
            : 0;

        $totalCaptures = 0;
        foreach ($players as $p) $totalCaptures += (int)$p['captures'];

        $pdo->prepare(
            'INSERT INTO game_history (match_id, winner_id, mode, player_count, total_turns, total_captures, duration_sec, players_json)
             VALUES (:m, :w, :mo, :pc, :tt, :tc, :d, :pj)'
        )->execute([
            ':m'  => $matchId,
            ':w'  => $winnerId,
            ':mo' => $match['mode'],
            ':pc' => $match['max_players'],
            ':tt' => $match['turn_number'],
            ':tc' => $totalCaptures,
            ':d'  => $duration,
            ':pj' => json_encode($players),
        ]);

        // Update winner stats + wallet
        $pdo->prepare(
            'UPDATE player_stats SET total_matches = total_matches + 1, total_wins = total_wins + 1,
                                       current_win_streak = current_win_streak + 1,
                                       best_win_streak = GREATEST(best_win_streak, current_win_streak + 1)
             WHERE user_id = :u'
        )->execute([':u' => $winnerId]);

        foreach ($players as $p) {
            if ($p['user_id'] && (int)$p['user_id'] !== $winnerId) {
                $pdo->prepare(
                    'UPDATE player_stats SET total_matches = total_matches + 1, total_losses = total_losses + 1,
                                               current_win_streak = 0,
                                               total_captures = total_captures + :c
                     WHERE user_id = :u'
                )->execute([':c' => (int)$p['captures'], ':u' => $p['user_id']]);
            } elseif ($p['user_id']) {
                $pdo->prepare(
                    'UPDATE player_stats SET total_captures = total_captures + :c WHERE user_id = :u'
                )->execute([':c' => (int)$p['captures'], ':u' => $p['user_id']]);
            }
        }

        // Credit winner prize
        if ((int)$match['prize_pool'] > 0) {
            WalletService::adjust($winnerId, 'credit', 'coin', (int)$match['prize_pool'], 'match_win', 'match_' . $matchId);
        }
    }

    public static function loadMatch(int $matchId): array
    {
        $pdo = Database::connection();
        $stmt = $pdo->prepare('SELECT * FROM matches WHERE id = :m');
        $stmt->execute([':m' => $matchId]);
        $match = $stmt->fetch();
        if (!$match) error('Match not found.', 404);

        $stmt = $pdo->prepare(
            'SELECT mp.*, u.username, u.avatar_url FROM match_players mp
              LEFT JOIN users u ON u.id = mp.user_id
             WHERE mp.match_id = :m ORDER BY mp.seat'
        );
        $stmt->execute([':m' => $matchId]);
        $match['players'] = $stmt->fetchAll();

        $stmt = $pdo->prepare('SELECT * FROM game_states WHERE match_id = :m');
        $stmt->execute([':m' => $matchId]);
        $state = $stmt->fetch();
        $match['state'] = $state;
        return $match;
    }

    public static function pauseMatch(int $matchId, int $userId): array
    {
        $pdo = Database::connection();
        $pdo->prepare("UPDATE matches SET status = 'paused' WHERE id = :m AND host_id = :u")
            ->execute([':m' => $matchId, ':u' => $userId]);
        return self::loadMatch($matchId);
    }

    public static function resumeMatch(int $matchId, int $userId): array
    {
        $pdo = Database::connection();
        $pdo->prepare("UPDATE matches SET status = 'active' WHERE id = :m AND host_id = :u")
            ->execute([':m' => $matchId, ':u' => $userId]);
        return self::loadMatch($matchId);
    }

    public static function finish(int $matchId, int $userId): array
    {
        $pdo = Database::connection();
        $pdo->beginTransaction();
        try {
            self::finishMatch($pdo, $matchId, $userId);
            $pdo->commit();
        } catch (Throwable $e) {
            $pdo->rollBack();
            error('Finish failed: ' . $e->getMessage(), 500);
        }
        return self::loadMatch($matchId);
    }

    public static function findOpenMatch(int $userId, string $mode, int $maxPlayers): ?int
    {
        $pdo = Database::connection();
        $stmt = $pdo->prepare(
            "SELECT m.id FROM matches m
              WHERE m.mode = :mo AND m.max_players = :mp AND m.status = 'waiting'
                AND m.id NOT IN (SELECT match_id FROM match_players WHERE user_id = :u)
              ORDER BY m.created_at ASC LIMIT 1"
        );
        $stmt->execute([':mo' => $mode, ':mp' => $maxPlayers, ':u' => $userId]);
        $row = $stmt->fetch();
        return $row ? (int)$row['id'] : null;
    }
}
