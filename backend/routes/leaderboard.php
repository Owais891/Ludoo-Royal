<?php
return [
    'GET /leaderboard' => function () {
        $user = AuthMiddleware::requireUser();
        $limit = (int)($_GET['limit'] ?? 100);
        $limit = max(5, min($limit, 500));
        $pdo = Database::connection();
        $stmt = $pdo->prepare(
            'SELECT u.id, u.username, u.avatar_url,
                    COALESCE(s.total_matches, 0) AS total_matches,
                    COALESCE(s.total_wins, 0) AS total_wins,
                    COALESCE(s.total_losses, 0) AS total_losses,
                    COALESCE(s.total_captures, 0) AS total_captures,
                    COALESCE(p.player_level, 1) AS player_level,
                    (CASE WHEN s.total_matches > 0
                        THEN ROUND((s.total_wins / s.total_matches) * 100, 2)
                        ELSE 0 END) AS win_rate
               FROM users u
               LEFT JOIN player_stats s ON s.user_id = u.id
               LEFT JOIN user_profiles p ON p.user_id = u.id
              WHERE u.is_banned = 0
              ORDER BY total_wins DESC, win_rate DESC, total_captures DESC
              LIMIT :l'
        );
        $stmt->bindValue(':l', $limit, PDO::PARAM_INT);
        $stmt->execute();
        $rows = $stmt->fetchAll();
        foreach ($rows as &$r) {
            $r['id'] = (int)$r['id'];
            $r['total_matches'] = (int)$r['total_matches'];
            $r['total_wins']    = (int)$r['total_wins'];
            $r['total_losses']  = (int)$r['total_losses'];
            $r['total_captures']= (int)$r['total_captures'];
            $r['player_level']  = (int)$r['player_level'];
            $r['win_rate']      = (float)$r['win_rate'];
        }
        success(['players' => $rows]);
    },
];
