<?php
return [
    'GET /history' => function () {
        $user = AuthMiddleware::requireUser();
        $limit = (int)($_GET['limit'] ?? 50);
        $limit = max(5, min($limit, 200));
        $pdo = Database::connection();

        // Get matches the user participated in
        $stmt = $pdo->prepare(
            'SELECT h.*, m.code, u.username AS winner_name
               FROM game_history h
               JOIN matches m ON m.id = h.match_id
               JOIN match_players mp ON mp.match_id = h.match_id AND mp.user_id = :u
               LEFT JOIN users u ON u.id = h.winner_id
              ORDER BY h.created_at DESC LIMIT :l'
        );
        $stmt->bindValue(':u', $user['id'], PDO::PARAM_INT);
        $stmt->bindValue(':l', $limit, PDO::PARAM_INT);
        $stmt->execute();
        $rows = $stmt->fetchAll();
        foreach ($rows as &$r) {
            $r['players'] = json_decode($r['players_json'], true);
            unset($r['players_json']);
        }
        success(['history' => $rows]);
    },
];
