<?php
/**
 * MultiplayerService - private rooms.
 */
final class MultiplayerService
{
    public static function createRoom(int $hostId, string $mode, int $maxPlayers): array
    {
        $code = gen_room_code(6);
        $pdo = Database::connection();
        $pdo->prepare(
            'INSERT INTO private_rooms (room_code, host_id, mode, max_players, status)
             VALUES (:c, :h, :m, :mp, :s)'
        )->execute([
            ':c'  => $code,
            ':h'  => $hostId,
            ':m'  => $mode,
            ':mp' => $maxPlayers,
            ':s'  => 'open',
        ]);
        $roomId = (int)$pdo->lastInsertId();

        // Create underlying match (status waiting)
        $match = GameService::createMatch($hostId, $mode, $maxPlayers);
        $pdo->prepare('UPDATE private_rooms SET match_id = :m WHERE id = :r')
            ->execute([':m' => $match['id'], ':r' => $roomId]);

        return self::roomStatus($code);
    }

    public static function joinRoom(int $userId, string $code): array
    {
        $pdo = Database::connection();
        $stmt = $pdo->prepare('SELECT * FROM private_rooms WHERE room_code = :c');
        $stmt->execute([':c' => $code]);
        $room = $stmt->fetch();
        if (!$room) error('Room not found.', 404);
        if ($room['status'] !== 'open') error('Room no longer open.', 400);

        GameService::joinMatch($userId, (int)$room['match_id']);

        $stmt = $pdo->prepare('SELECT COUNT(*) c FROM match_players WHERE match_id = :m');
        $stmt->execute([':m' => $room['match_id']]);
        $c = (int)$stmt->fetch()['c'];
        if ($c >= (int)$room['max_players']) {
            $pdo->prepare("UPDATE private_rooms SET status = 'started' WHERE id = :r")
                ->execute([':r' => $room['id']]);
        }
        return self::roomStatus($code);
    }

    public static function roomStatus(string $code): array
    {
        $pdo = Database::connection();
        $stmt = $pdo->prepare(
            'SELECT r.*, m.id AS match_id, m.status AS match_status, m.max_players
               FROM private_rooms r
               LEFT JOIN matches m ON m.id = r.match_id
              WHERE r.room_code = :c'
        );
        $stmt->execute([':c' => $code]);
        $room = $stmt->fetch();
        if (!$room) error('Room not found.', 404);

        $stmt = $pdo->prepare(
            'SELECT mp.seat, mp.player_color, mp.is_ready, u.id AS user_id, u.username, u.avatar_url
               FROM match_players mp
               LEFT JOIN users u ON u.id = mp.user_id
              WHERE mp.match_id = :m ORDER BY mp.seat'
        );
        $stmt->execute([':m' => $room['match_id']]);
        $room['participants'] = $stmt->fetchAll();
        return $room;
    }

    public static function leaveRoom(int $userId, string $code): array
    {
        $pdo = Database::connection();
        $stmt = $pdo->prepare('SELECT * FROM private_rooms WHERE room_code = :c');
        $stmt->execute([':c' => $code]);
        $room = $stmt->fetch();
        if (!$room) error('Room not found.', 404);

        $pdo->prepare('DELETE FROM match_players WHERE match_id = :m AND user_id = :u')
            ->execute([':m' => $room['match_id'], ':u' => $userId]);
        return ['left' => true];
    }
}
